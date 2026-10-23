import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../data/models/finance_models.dart';
import '../../controllers/finance_controller.dart';

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    required this.controller,
    this.transactionId,
    super.key,
  });

  final FinanceController controller;
  final String? transactionId;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String? _category;
  String? _accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _expenseCategories = [
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
  static const _incomeCategories = ['Salary', 'Other Income'];

  FinanceTransaction? get _existing => widget.transactionId == null
      ? null
      : widget.controller.transactionById(widget.transactionId!);
  List<String> get _categories =>
      _type == TransactionType.expense ? _expenseCategories : _incomeCategories;

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    if (existing != null) {
      _type = existing.type;
      _amount.text =
          '${existing.amountPaise ~/ 100}.${(existing.amountPaise % 100).toString().padLeft(2, '0')}';
      _description.text = existing.description;
      _category = existing.category;
      _accountId = existing.accountId;
      _date = existing.transactionDate.toLocal();
    }
    _category ??= _categories.first;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.controller.accounts.isNotEmpty && _accountId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choose an account.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = _existing;
      final transaction = FinanceTransaction(
        id: existing?.id ?? 'tx-${DateTime.now().microsecondsSinceEpoch}',
        amountPaise: MoneyParser.rupeesToPaise(_amount.text),
        type: _type,
        category: _category!,
        description: _description.text.trim(),
        transactionDate: DateTime(_date.year, _date.month, _date.day),
        accountId: _accountId,
        createdAt: existing?.createdAt,
        updatedAt: DateTime.now(),
      );
      if (existing == null) {
        await widget.controller.createTransaction(transaction);
      } else {
        await widget.controller.updateTransaction(transaction);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save transaction: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_existing == null ? 'Add transaction' : 'Edit transaction'),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() {
                _type = selection.first;
                _category = _categories.first;
              }),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
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
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description or merchant',
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Enter a description.'
                  : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(
                '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: _selectDate,
            ),
            if (widget.controller.accounts.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: widget.controller.accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _accountId = value),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'No accounts yet. You can save this transaction without an account, or add an account from Money.',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save transaction'),
            ),
          ],
        ),
      ),
    ),
  );
}
