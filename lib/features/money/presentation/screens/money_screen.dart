import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/finance_models.dart';
import '../../../transactions/controllers/finance_controller.dart';
import '../../../transactions/presentation/screens/transaction_history_screen.dart';
import '../../../receipts/presentation/screens/receipt_scan_screen.dart';

class MoneyScreen extends StatelessWidget {
  const MoneyScreen({required this.controller, super.key});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Money'),
      actions: [
        IconButton(
          tooltip: 'Accounts',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.accounts),
          icon: const Icon(Icons.account_balance_wallet_outlined),
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(controller.error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: controller.load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final budget = controller.monthlyBudgetPaise;
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.pushNamed(context, AppRoutes.accounts),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current balance · all accounts',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _money(controller.currentBalancePaise),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.accounts.isEmpty
                            ? 'No accounts yet. Add one to record an opening balance.'
                            : '${controller.accounts.length} accounts · tap to manage',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.accounts.isEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.accounts),
                  icon: const Icon(Icons.add),
                  label: const Text('Create account'),
                ),
              ],
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly expense limit',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    if (budget == 0) ...[
                      const Text(
                        'No monthly limit set',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Manage monthly and category limits in Settings.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ] else ...[
                      Text(
                        '${_money(controller.currentMonthTotals.expensesPaise)} of ${_money(budget)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value:
                            (controller.currentMonthTotals.expensesPaise /
                                    budget)
                                .clamp(0, 1),
                        color: AppColors.mint,
                        backgroundColor: AppColors.elevated,
                      ),
                    ],
                  ],
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
                    children: [
                      const Text(
                        'No transactions yet',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add an income or expense to start tracking your money.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Column(
                    children: controller.recentTransactions
                        .map(
                          (tx) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              tx.type == TransactionType.income
                                  ? Icons.south_west
                                  : Icons.north_east,
                              color: tx.type == TransactionType.income
                                  ? AppColors.mint
                                  : AppColors.purple,
                            ),
                            title: Text(tx.description),
                            subtitle: Text(
                              '${tx.category} · ${tx.transactionDate.toLocal().toString().split(' ').first}',
                            ),
                            trailing: Text(
                              '${tx.type == TransactionType.income ? '+' : '−'}${_money(tx.amountPaise)}',
                            ),
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.transactionDetails,
                              arguments: tx.id,
                            ),
                          ),
                        )
                        .toList(),
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TransactionHistoryScreen(controller: controller),
                  ),
                ),
                icon: const Icon(Icons.list_alt),
                label: const Text('Show all transactions'),
              ),
            ],
          ),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'money_add_transaction',
      onPressed: () => Navigator.pushNamed(context, AppRoutes.newTransaction),
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    ),
  );
}

String _money(int paise) =>
    '₹${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
