import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/finance_models.dart';
import '../../../../domain/finance_calculator.dart';
import '../../../transactions/controllers/finance_controller.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({required this.controller, super.key});
  final FinanceController controller;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late DateTime _month;
  List<FinanceBudget> _budgets = [];
  bool _budgetsLoading = true;
  String? _budgetError;

  @override
  void initState() {
    super.initState();
    final current = DateTime.now();
    _month = DateTime(current.year, current.month);
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() {
      _budgetsLoading = true;
      _budgetError = null;
    });
    try {
      _budgets = await widget.controller.budgetsForMonth(_month);
    } catch (error) {
      _budgetError = 'Could not load budget insights: $error';
    } finally {
      if (mounted) setState(() => _budgetsLoading = false);
    }
  }

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await _loadBudgets();
  }

  Future<void> _openBudgets() async {
    await Navigator.pushNamed(context, AppRoutes.budgets, arguments: _month);
    if (mounted) await _loadBudgets();
  }

  Future<void> _refresh() async {
    await widget.controller.load();
    await _loadBudgets();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Spending Analysis'),
      actions: [
        IconButton(
          tooltip: 'Budgets',
          onPressed: _openBudgets,
          icon: const Icon(Icons.savings_outlined),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.controller.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.controller.error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: widget.controller.load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final start = DateTime.utc(_month.year, _month.month);
        final end = DateTime.utc(_month.year, _month.month + 1);
        final previousStart = DateTime.utc(_month.year, _month.month - 1);
        final current = FinanceCalculator.totalsForPeriod(
          widget.controller.transactions,
          start: start,
          end: end,
        );
        final previous = FinanceCalculator.totalsForPeriod(
          widget.controller.transactions,
          start: previousStart,
          end: start,
        );
        final comparison = FinanceCalculator.compareMonths(
          currentExpensePaise: current.expensesPaise,
          previousExpensePaise: previous.expensesPaise,
        );
        final categories = FinanceCalculator.expensesByCategory(
          widget.controller.transactions,
          start: start,
          end: end,
        ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final monthTransactions = widget.controller.transactions
            .where(
              (transaction) =>
                  !transaction.transactionDate.isBefore(start) &&
                  transaction.transactionDate.isBefore(end),
            )
            .toList(growable: false);
        final highest = categories.isEmpty ? null : categories.first;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _totalCard(
                    context,
                    'Income',
                    current.incomePaise,
                    AppColors.mint,
                  ),
                  _totalCard(
                    context,
                    'Expenses',
                    current.expensesPaise,
                    AppColors.purple,
                  ),
                  _totalCard(
                    context,
                    'Net cash flow',
                    current.netCashFlowPaise,
                    current.netCashFlowPaise < 0
                        ? AppColors.coral
                        : Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Spending by category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (categories.isEmpty)
                AppCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.pie_chart_outline,
                        color: AppColors.muted,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      const Text('No expenses for this month'),
                      const SizedBox(height: 8),
                      const Text(
                        'Add an expense to see a category breakdown.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.newTransaction,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add transaction'),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  child: Column(
                    children: categories
                        .map(
                          (entry) => _categoryBar(
                            entry.key,
                            entry.value,
                            categories.first.value,
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 22),
              Text(
                'Monthly comparison',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              AppCard(
                child: _comparisonContent(
                  comparison,
                  current.expensesPaise,
                  previous.expensesPaise,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Insights',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: _openBudgets,
                    child: const Text('Manage budgets'),
                  ),
                ],
              ),
              if (highest != null)
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, color: AppColors.mint),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Highest spending category: ${highest.key} (${_money(highest.value)}).',
                        ),
                      ),
                    ],
                  ),
                ),
              if (highest != null) const SizedBox(height: 10),
              if (_budgetsLoading)
                const AppCard(
                  child: Text(
                    'Loading budget insights…',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else if (_budgetError != null)
                AppCard(
                  child: Text(
                    _budgetError!,
                    style: const TextStyle(color: AppColors.coral),
                  ),
                )
              else if (_budgets.isEmpty)
                AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.savings_outlined,
                      color: AppColors.mint,
                    ),
                    title: const Text('No budget set for this month'),
                    subtitle: const Text(
                      'Create a limit to track your spending pace.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openBudgets,
                  ),
                )
              else
                ..._budgets.map(
                  (budget) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _budgetInsight(budget),
                  ),
                ),
              if (monthTransactions.isEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'No income or expenses recorded in this month.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ],
          ),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'analysis_add_transaction',
      onPressed: () => Navigator.pushNamed(context, AppRoutes.newTransaction),
      icon: const Icon(Icons.add),
      label: const Text('Add transaction'),
    ),
  );

  Widget _totalCard(
    BuildContext context,
    String title,
    int value,
    Color color,
  ) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 52) / 2,
    child: AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            _money(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _categoryBar(String name, int value, int maxValue) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(name)),
            Text(
              _money(value),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: '$name spending ${_money(value)}',
          child: LinearProgressIndicator(
            value: maxValue == 0 ? 0 : value / maxValue,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: AppColors.elevated,
            color: AppColors.mint,
          ),
        ),
      ],
    ),
  );

  Widget _comparisonContent(
    MonthComparison comparison,
    int current,
    int previous,
  ) {
    final change = comparison.percentageChange;
    if (change == null) {
      if (current == 0) {
        return const Text(
          'No expenses in either month yet.',
          style: TextStyle(color: AppColors.muted),
        );
      }
      return Text(
        'Spending is ${_money(current)} this month; there was no previous-month spending to compare.',
        style: const TextStyle(color: AppColors.muted),
      );
    }
    if (change == 0) {
      return Text(
        'No change from the previous month (${_money(previous)}).',
        style: const TextStyle(color: AppColors.muted),
      );
    }
    final increased = change > 0;
    return Row(
      children: [
        Icon(
          increased ? Icons.arrow_upward : Icons.arrow_downward,
          color: increased ? AppColors.coral : AppColors.mint,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Expenses ${increased ? 'increased' : 'decreased'} by ${change.abs().toStringAsFixed(1)}% compared with ${_monthLabel(DateTime(_month.year, _month.month - 1))}.',
          ),
        ),
      ],
    );
  }

  Widget _budgetInsight(FinanceBudget budget) {
    final expenses = widget.controller.transactions
        .where(
          (transaction) =>
              transaction.type == TransactionType.expense &&
              !transaction.transactionDate.isBefore(budget.startDate) &&
              transaction.transactionDate.isBefore(budget.endDate) &&
              (budget.category == null ||
                  transaction.category == budget.category),
        )
        .fold<int>(0, (sum, transaction) => sum + transaction.amountPaise);
    final usage = FinanceCalculator.budgetUsage(
      expensePaise: expenses,
      limitPaise: budget.limitPaise,
    );
    final exceeded = expenses >= budget.limitPaise;
    return AppCard(
      child: Row(
        children: [
          Icon(
            exceeded ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: exceeded ? AppColors.coral : AppColors.mint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exceeded
                  ? '${budget.category ?? 'Overall'} budget exceeded by ${_money(usage.remainingPaise.abs())}.'
                  : '${budget.category ?? 'Overall'} budget: ${usage.utilizationPercent.toStringAsFixed(0)}% used; ${_money(usage.remainingPaise)} remains.',
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
