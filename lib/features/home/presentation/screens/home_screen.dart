import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/finance_models.dart';
import '../../../transactions/controllers/finance_controller.dart';
import '../../../transactions/presentation/screens/transaction_history_screen.dart';
import '../../../shell/presentation/main_shell.dart';
import '../../../receipts/presentation/screens/receipt_scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.controller, super.key});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting(),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const Text(
            'Your finances, at a glance',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: () => _selectTab(context, 4),
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error != null) {
          return _error(context);
        }
        final totals = controller.currentMonthTotals;
        final categories =
            controller.currentMonthCategoryTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _balanceCard(context),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _summary(
                      'Income · this month',
                      _money(totals.incomePaise),
                      AppColors.mint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summary(
                      'Expenses · this month',
                      _money(totals.expensesPaise),
                      AppColors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spending overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => _selectTab(context, 2),
                    child: const Text('Analysis'),
                  ),
                ],
              ),
              if (categories.isEmpty)
                const AppCard(
                  child: Text(
                    'No expenses recorded this month yet.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                AppCard(
                  child: Column(
                    children: categories
                        .take(5)
                        .map(
                          (entry) => _categoryRow(
                            context,
                            entry.key,
                            entry.value,
                            categories.first.value,
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent transactions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TransactionHistoryScreen(controller: controller),
                      ),
                    ),
                    child: const Text('Show all'),
                  ),
                ],
              ),
              if (controller.recentTransactions.isEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No transactions yet',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Start tracking your income and expenses.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.newTransaction,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add first transaction'),
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
                    children: controller.recentTransactions
                        .map(
                          (transaction) =>
                              _transactionRow(context, transaction),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bills', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.bills),
                    child: const Text('Manage'),
                  ),
                ],
              ),
              if (controller.overdueBills.isEmpty &&
                  controller.upcomingBills.isEmpty)
                AppCard(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'No unpaid bills. Add due dates to keep reminders in one place.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add bill',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.bills),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  child: Column(
                    children: [
                      ...controller.overdueBills
                          .take(3)
                          .map(
                            (bill) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.coral,
                              ),
                              title: Text(bill.title),
                              subtitle: Text(
                                'Overdue · ${_date(bill.dueDate)}',
                              ),
                              trailing: Text(_money(bill.amountPaise)),
                              onTap: () =>
                                  Navigator.pushNamed(context, AppRoutes.bills),
                            ),
                          ),
                      ...controller.upcomingBills
                          .take(3)
                          .map(
                            (bill) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.receipt_long,
                                color: AppColors.mint,
                              ),
                              title: Text(bill.title),
                              subtitle: Text('Due ${_date(bill.dueDate)}'),
                              trailing: Text(_money(bill.amountPaise)),
                              onTap: () =>
                                  Navigator.pushNamed(context, AppRoutes.bills),
                            ),
                          ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ReceiptScanScreen(controller: controller),
                  ),
                ),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scan receipt'),
              ),
            ],
          ),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'home_add_transaction',
      onPressed: () => Navigator.pushNamed(context, AppRoutes.newTransaction),
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    ),
  );

  Widget _balanceCard(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: () => _selectTab(context, 1),
    child: Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total balance', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(
            _money(controller.currentBalancePaise),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            controller.accounts.isEmpty
                ? 'Add an account to track opening balances.'
                : '${controller.accounts.length} local account${controller.accounts.length == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _summary(String label, String amount, Color color) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Text(
          amount,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _categoryRow(
    BuildContext context,
    String category,
    int amount,
    int max,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.circle, color: AppColors.mint, size: 9),
            const SizedBox(width: 10),
            Expanded(child: Text(category)),
            Text(
              _money(amount),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: max == 0 ? 0 : amount / max,
          minHeight: 5,
          borderRadius: BorderRadius.circular(6),
          backgroundColor: AppColors.elevated,
          color: AppColors.mint,
        ),
      ],
    ),
  );

  Widget _transactionRow(
    BuildContext context,
    FinanceTransaction transaction,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor:
          (transaction.type == TransactionType.income
                  ? AppColors.mint
                  : AppColors.purple)
              .withValues(alpha: .15),
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
    title: Text(transaction.description),
    subtitle: Text(
      '${transaction.category} · ${_date(transaction.transactionDate)}',
    ),
    trailing: Text(
      '${transaction.type == TransactionType.income ? '+' : '−'}${_money(transaction.amountPaise)}',
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    onTap: () => Navigator.pushNamed(
      context,
      AppRoutes.transactionDetails,
      arguments: transaction.id,
    ),
  );

  Widget _error(BuildContext context) => Center(
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

  static String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
  }

  static String _money(int paise) =>
      '₹${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
  static String _date(DateTime date) =>
      '${date.toLocal().day.toString().padLeft(2, '0')}/${date.toLocal().month.toString().padLeft(2, '0')}/${date.toLocal().year}';
  static void _selectTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<MainShellState>()?.setTab(index);
}
