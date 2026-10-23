import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/finance_models.dart';
import '../../controllers/finance_controller.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({required this.controller, super.key});
  final FinanceController controller;

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  TransactionType? _type;
  String? _category;
  DateTime _month = DateTime.now();

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final start = DateTime.utc(_month.year, _month.month);
    final end = DateTime.utc(_month.year, _month.month + 1);
    final all = widget.controller.transactions.where(
      (transaction) =>
          !transaction.transactionDate.isBefore(start) &&
          transaction.transactionDate.isBefore(end),
    );
    final filtered = all
        .where(
          (transaction) =>
              (_type == null || transaction.type == _type) &&
              (_category == null || transaction.category == _category),
        )
        .toList(growable: false);
    final expenseTotal = all
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold<int>(0, (sum, transaction) => sum + transaction.amountPaise);
    final categories =
        widget.controller.transactions
            .map((transaction) => transaction.category)
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: 'Add transaction',
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.newTransaction);
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: widget.controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.controller.error != null
          ? _error(context, widget.controller)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            tooltip: 'Previous month',
                            onPressed: () => _changeMonth(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            _monthYear(_month),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            tooltip: 'Next month',
                            onPressed: () => _changeMonth(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      const Text(
                        'Monthly expenses',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _money(expenseTotal),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All types'),
                      selected: _type == null,
                      onSelected: (_) => setState(() => _type = null),
                    ),
                    ChoiceChip(
                      label: const Text('Expense'),
                      selected: _type == TransactionType.expense,
                      onSelected: (_) =>
                          setState(() => _type = TransactionType.expense),
                    ),
                    ChoiceChip(
                      label: const Text('Income'),
                      selected: _type == TransactionType.income,
                      onSelected: (_) =>
                          setState(() => _type = TransactionType.income),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category filter',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All categories'),
                    ),
                    ...categories.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  AppCard(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.muted,
                          size: 34,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.controller.transactions.isEmpty
                              ? 'No transactions yet'
                              : 'No transactions match these filters',
                        ),
                        const SizedBox(height: 8),
                        if (widget.controller.transactions.isEmpty)
                          FilledButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.newTransaction,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add first transaction'),
                          )
                        else
                          TextButton(
                            onPressed: () => setState(() {
                              _type = null;
                              _category = null;
                            }),
                            child: const Text('Reset filters'),
                          ),
                      ],
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      children: filtered
                          .map((transaction) => _row(context, transaction))
                          .toList(),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.newTransaction),
        tooltip: 'Add transaction',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _row(BuildContext context, FinanceTransaction transaction) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor:
          (transaction.type == TransactionType.income
                  ? AppColors.mint
                  : AppColors.purple)
              .withValues(alpha: 0.15),
      child: Icon(
        transaction.type == TransactionType.income
            ? Icons.south_west
            : Icons.north_east,
        color: transaction.type == TransactionType.income
            ? AppColors.mint
            : AppColors.purple,
        size: 18,
      ),
    ),
    title: Text(
      transaction.description,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      '${transaction.category} · ${_dateLabel(transaction.transactionDate)}',
    ),
    trailing: Text(
      '${transaction.type == TransactionType.income ? '+' : '−'}${_money(transaction.amountPaise)}',
      style: TextStyle(
        color: transaction.type == TransactionType.income
            ? AppColors.mint
            : Colors.white,
        fontWeight: FontWeight.w700,
      ),
    ),
    onTap: () => Navigator.pushNamed(
      context,
      AppRoutes.transactionDetails,
      arguments: transaction.id,
    ),
  );

  Widget _error(BuildContext context, FinanceController controller) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(controller.error!),
          const SizedBox(height: 12),
          FilledButton(onPressed: controller.load, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String _money(int paise) =>
    '₹${(paise ~/ 100).toString()}.${(paise % 100).toString().padLeft(2, '0')}';
String _dateLabel(DateTime date) =>
    '${date.toLocal().day.toString().padLeft(2, '0')}/${date.toLocal().month.toString().padLeft(2, '0')}/${date.toLocal().year}';
String _monthYear(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.year}';
const _monthNames = [
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
