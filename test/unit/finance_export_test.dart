import 'dart:convert';

import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/features/settings/domain/finance_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'JSON export includes finance records with exact paise and no secrets',
    () {
      final encoded = FinanceExport.encode(
        FinanceExport.build(
          accounts: [
            FinanceAccount(
              id: 'a',
              name: 'Main',
              type: AccountType.bank,
              openingBalancePaise: 123456,
            ),
          ],
          transactions: [
            FinanceTransaction(
              id: 't',
              amountPaise: 12345,
              type: TransactionType.expense,
              category: 'Food',
              description: 'Meal',
              transactionDate: DateTime.utc(2026, 10, 1),
            ),
          ],
          budgets: [
            FinanceBudget(
              id: 'b',
              name: 'Food',
              limitPaise: 100000,
              periodId: '2026-10',
              startDate: DateTime.utc(2026, 10, 1),
              endDate: DateTime.utc(2026, 11, 1),
            ),
          ],
          bills: [
            BillReminder(
              id: 'bill',
              title: 'Phone',
              amountPaise: 25050,
              dueDate: DateTime.utc(2026, 10, 7),
              recurrence: BillRecurrence.monthly,
            ),
          ],
        ),
      );
      final export = jsonDecode(encoded) as Map<String, dynamic>;
      expect(export['format'], 'finpilotai-finance-export');
      expect(export['accounts'][0]['opening_balance_paise'], 123456);
      expect(export['transactions'][0]['amount_paise'], 12345);
      expect(export['budgets'][0]['limit_paise'], 100000);
      expect(export['bills'][0]['amount_paise'], 25050);
      expect(encoded, isNot(contains('email')));
      expect(encoded, isNot(contains('password')));
      expect(
        export.keys,
        containsAll(['accounts', 'transactions', 'budgets', 'bills']),
      );
    },
  );
}
