import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/finance_models.dart';
import '../../../../domain/finance_calculator.dart';
import '../../../transactions/controllers/finance_controller.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({required this.controller, this.initialMonth, super.key});

  final FinanceController controller;
  final DateTime? initialMonth;

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  late DateTime _month;
  List<FinanceBudget> _budgets = [];
  bool _loading = true;
  String? _error;

  static const _categories = [
    'Food',
    'Transport',
    'Bills',
    'Shopping',
    'Health',
    'Entertainment',
    'Education',
    'Travel',
    'Other Expense',
  ];

  @override
  void initState() {
    super.initState();
    final seed = widget.initialMonth ?? DateTime.now();
    _month = DateTime(seed.year, seed.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _budgets = await widget.controller.budgetsForMonth(_month);
    } catch (error) {
      _error = 'Could not load budgets: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await _load();
  }

  Future<void> _editBudget([FinanceBudget? existing]) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final amountController = TextEditingController(
      text: existing == null
          ? ''
          : '${existing.limitPaise ~/ 100}.${(existing.limitPaise % 100).toString().padLeft(2, '0')}',
    );
    String? category = existing?.category;
    bool saving = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add budget' : 'Edit budget'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Budget name'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter a budget name.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Budget scope',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Overall spending'),
                      ),
                      ..._categories.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item,
                          child: Text(item),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => category = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monthly limit (₹)',
                    ),
                    validator: (value) {
                      try {
                        MoneyParser.rupeesToPaise(value ?? '');
                        return null;
                      } catch (error) {
                        return error.toString();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      final start = DateTime.utc(_month.year, _month.month);
                      final end = DateTime.utc(_month.year, _month.month + 1);
                      final budget = FinanceBudget(
                        id:
                            existing?.id ??
                            'budget-${DateTime.now().microsecondsSinceEpoch}',
                        name: nameController.text.trim(),
                        category: category,
                        limitPaise: MoneyParser.rupeesToPaise(
                          amountController.text,
                        ),
                        periodId:
                            '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                        startDate: start,
                        endDate: end,
                      );
                      try {
                        if (existing == null) {
                          await widget.controller.createBudget(budget);
                        } else {
                          await widget.controller.updateBudget(budget);
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Could not save budget: $error'),
                            ),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save budget'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    amountController.dispose();
    if (saved == true) await _load();
  }

  Future<void> _deleteBudget(FinanceBudget budget) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text('Delete “${budget.name}” for ${_monthLabel(_month)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await widget.controller.deleteBudget(budget.id);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete budget: $error')),
        );
      }
    }
  }

  int _spent(FinanceBudget budget) {
    final range = widget.controller.transactions.where(
      (transaction) =>
          transaction.type == TransactionType.expense &&
          !transaction.transactionDate.isBefore(budget.startDate) &&
          transaction.transactionDate.isBefore(budget.endDate) &&
          (budget.category == null || transaction.category == budget.category),
    );
    return range.fold<int>(
      0,
      (sum, transaction) => sum + transaction.amountPaise,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Budgets'),
      actions: [
        IconButton(
          tooltip: 'Add budget',
          onPressed: () => _editBudget(),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    _monthLabel(_month),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const AppCard(
                child: Text(
                  'Loading budgets…',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else if (_error != null)
              AppCard(
                child: Column(
                  children: [
                    Text(_error!),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_budgets.isEmpty)
              AppCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.savings_outlined,
                      color: AppColors.muted,
                      size: 36,
                    ),
                    const SizedBox(height: 10),
                    const Text('No budgets for this month'),
                    const SizedBox(height: 8),
                    const Text(
                      'Create an overall spending limit or a category budget. Spending will be calculated from expense transactions only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _editBudget(),
                      icon: const Icon(Icons.add),
                      label: const Text('Create budget'),
                    ),
                  ],
                ),
              )
            else ...[
              ..._budgets.map(
                (budget) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _budgetCard(budget),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _editBudget(),
                icon: const Icon(Icons.add),
                label: const Text('Add another budget'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _budgetCard(FinanceBudget budget) {
    final spent = _spent(budget);
    final usage = FinanceCalculator.budgetUsage(
      expensePaise: spent,
      limitPaise: budget.limitPaise,
    );
    final exceeded = spent >= budget.limitPaise;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budget.category ?? 'Overall spending',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit ${budget.name}',
                onPressed: () => _editBudget(budget),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete ${budget.name}',
                onPressed: () => _deleteBudget(budget),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_money(spent)} spent'),
              Text('of ${_money(budget.limitPaise)}'),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (usage.utilizationPercent / 100).clamp(0, 1),
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            color: exceeded ? AppColors.coral : AppColors.mint,
            backgroundColor: AppColors.elevated,
          ),
          const SizedBox(height: 8),
          Text(
            exceeded
                ? 'Limit reached or exceeded · ${_money(usage.remainingPaise.abs())} over'
                : '${_money(usage.remainingPaise)} remaining · ${usage.utilizationPercent.toStringAsFixed(0)}% used',
            style: TextStyle(
              color: exceeded ? AppColors.coral : AppColors.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

String _money(int paise) =>
    '₹${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
String _monthLabel(DateTime month) =>
    '${_months[month.month - 1]} ${month.year}';
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
