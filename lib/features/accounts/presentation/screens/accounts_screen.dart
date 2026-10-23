import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/finance_models.dart';
import '../../../transactions/controllers/finance_controller.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({required this.controller, super.key});
  final FinanceController controller;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  Future<void> _createAccount() async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final opening = TextEditingController(text: '0');
    var type = AccountType.bank;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add account'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Account name'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter an account name.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: AccountType.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item.name[0].toUpperCase() + item.name.substring(1),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? AccountType.bank),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: opening,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Opening balance (₹)',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim() == '0') return null;
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created == true) {
      try {
        final value = opening.text.trim() == '0'
            ? 0
            : MoneyParser.rupeesToPaise(opening.text);
        await widget.controller.createAccount(
          FinanceAccount(
            id: 'account-${DateTime.now().microsecondsSinceEpoch}',
            name: name.text.trim(),
            type: type,
            openingBalancePaise: value,
          ),
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create account: $error')),
          );
        }
      }
    }
    name.dispose();
    opening.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Accounts'),
      actions: [
        IconButton(
          tooltip: 'Add account',
          onPressed: _createAccount,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: widget.controller.isLoading
        ? const Center(child: CircularProgressIndicator())
        : widget.controller.accounts.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_outlined,
                    color: AppColors.muted,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  const Text('No accounts yet'),
                  const SizedBox(height: 8),
                  const Text(
                    'Add an account to record opening balances and assign transactions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _createAccount,
                    icon: const Icon(Icons.add),
                    label: const Text('Add account'),
                  ),
                ],
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total balance',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _money(widget.controller.currentBalancePaise),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Column(
                  children: widget.controller.accounts
                      .map(
                        (account) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.account_balance_wallet_outlined),
                          ),
                          title: Text(account.name),
                          subtitle: Text(
                            '${account.type.name} · opening ${_money(account.openingBalancePaise)}',
                          ),
                          trailing: Text(
                            _money(
                              account.openingBalancePaise +
                                  widget.controller.transactions
                                      .where((tx) => tx.accountId == account.id)
                                      .fold<int>(
                                        0,
                                        (sum, tx) =>
                                            sum +
                                            (tx.type == TransactionType.income
                                                ? tx.amountPaise
                                                : -tx.amountPaise),
                                      ),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
    floatingActionButton: FloatingActionButton(
      onPressed: _createAccount,
      tooltip: 'Add account',
      child: const Icon(Icons.add),
    ),
  );
}

String _money(int paise) =>
    '₹${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
