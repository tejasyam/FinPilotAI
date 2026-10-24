import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../data/models/finance_models.dart';
import '../../../transactions/controllers/finance_controller.dart';
import '../../domain/receipt_text_parser.dart';

class ReceiptReviewScreen extends StatefulWidget {
  const ReceiptReviewScreen({
    required this.controller,
    required this.result,
    super.key,
  });

  final FinanceController controller;
  final ReceiptTextResult result;

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
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
  final _formKey = GlobalKey<FormState>();
  late final _merchant = TextEditingController(
    text: widget.result.merchant ?? '',
  );
  late final _amount = TextEditingController(
    text: widget.result.amountRupees ?? '',
  );
  late DateTime _date = widget.result.date ?? DateTime.now();
  String _category = 'Other Expense';
  String? _accountId;
  TransactionType _type = TransactionType.expense;
  bool _saving = false;
  bool _showRawText = false;

  List<String> get _categories =>
      _type == TransactionType.expense ? _expenseCategories : _incomeCategories;

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final transaction = FinanceTransaction(
        id: 'tx-${DateTime.now().microsecondsSinceEpoch}',
        amountPaise: MoneyParser.rupeesToPaise(_amount.text),
        type: _type,
        category: _category,
        description: _merchant.text.trim(),
        transactionDate: DateTime(_date.year, _date.month, _date.day),
        accountId: _accountId,
      );
      await widget.controller.createTransaction(transaction);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save receipt transaction: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review receipt')),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Confirm and save transaction'),
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Check every suggestion. Nothing is saved until you confirm.',
            style: TextStyle(color: AppColors.muted),
          ),
          if (!widget.result.hasAnySuggestedField) ...[
            const SizedBox(height: 12),
            const Text(
              'No receipt fields were detected. This may not be a receipt; review every value before saving.',
              style: TextStyle(color: AppColors.coral),
            ),
          ],
          const SizedBox(height: 16),
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Expense'),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Income'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) => setState(() {
              _type = selection.first;
              _category = _categories.first;
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _merchant,
            decoration: InputDecoration(
              labelText: 'Merchant or description',
              helperText: widget.result.merchant == null
                  ? 'Not detected — enter a description.'
                  : null,
            ),
            validator: (value) => value?.trim().isNotEmpty == true
                ? null
                : 'Enter a description.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
              helperText: widget.result.amountRupees == null
                  ? 'Not detected — enter the receipt total.'
                  : null,
            ),
            validator: (value) {
              try {
                MoneyParser.rupeesToPaise(value ?? '');
                return null;
              } catch (_) {
                return 'Enter a valid amount greater than zero.';
              }
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categories
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Transaction date'),
            subtitle: Text(
              widget.result.date == null
                  ? 'Not detected — choose a date.'
                  : _formatDate(_date),
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: _pickDate,
          ),
          DropdownButtonFormField<String?>(
            initialValue: _accountId,
            decoration: const InputDecoration(labelText: 'Account'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No account'),
              ),
              ...widget.controller.accounts.map(
                (account) => DropdownMenuItem<String?>(
                  value: account.id,
                  child: Text(account.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _accountId = value),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() => _showRawText = !_showRawText),
            icon: Icon(
              _showRawText ? Icons.expand_less : Icons.text_snippet_outlined,
            ),
            label: Text(
              _showRawText ? 'Hide recognized text' : 'Show recognized text',
            ),
          ),
          if (_showRawText)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                widget.result.rawText.isEmpty
                    ? 'No text recognized.'
                    : widget.result.rawText,
              ),
            ),
          const SizedBox(height: 18),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
