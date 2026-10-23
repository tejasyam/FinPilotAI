import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/app_card.dart';
import '../../controllers/finance_controller.dart';

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({
    required this.controller,
    required this.transactionId,
    super.key,
  });
  final FinanceController controller;
  final String transactionId;

  @override
  Widget build(BuildContext context) {
    final transaction = controller.transactionById(transactionId);
    if (transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: const Center(
          child: Text('This transaction is no longer available.'),
        ),
      );
    }
    final account = controller.accounts
        .where((item) => item.id == transaction.accountId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () async {
              await Navigator.pushNamed(
                context,
                AppRoutes.editTransaction,
                arguments: transaction.id,
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.type.name.toUpperCase(),
                  style: TextStyle(
                    color: transaction.type.name == 'income'
                        ? AppColors.mint
                        : AppColors.purple,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${transaction.type.name == 'income' ? '+' : '−'}₹${(transaction.amountPaise ~/ 100)}.${(transaction.amountPaise % 100).toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 22),
                _detail('Description', transaction.description),
                _detail('Category', transaction.category),
                _detail(
                  'Date',
                  transaction.transactionDate
                      .toLocal()
                      .toString()
                      .split('.')
                      .first,
                ),
                _detail('Account', account?.name ?? 'Unassigned'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This record will be removed from this device.'),
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
      await controller.deleteTransaction(transactionId);
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete transaction: $error')),
        );
      }
    }
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    ),
  );
}
