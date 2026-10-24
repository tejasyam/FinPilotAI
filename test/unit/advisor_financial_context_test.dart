import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/features/advisor/domain/advisor_financial_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'context calculates monthly flows, balance, categories, budgets and bills',
    () {
      final now = DateTime.utc(2025, 6, 15);
      final accounts = [
        FinanceAccount(
          id: 'cash',
          name: 'Cash',
          type: AccountType.cash,
          openingBalancePaise: 250000,
        ),
      ];
      final transactions = [
        _transaction(
          'previous',
          4000,
          TransactionType.expense,
          'Food',
          DateTime.utc(2025, 5, 10),
        ),
        _transaction(
          'salary',
          20000,
          TransactionType.income,
          'Salary',
          DateTime.utc(2025, 6, 2),
        ),
        _transaction(
          'food',
          5000,
          TransactionType.expense,
          'Food',
          DateTime.utc(2025, 6, 3),
        ),
        _transaction(
          'rent',
          3000,
          TransactionType.expense,
          'Rent',
          DateTime.utc(2025, 6, 4),
        ),
      ];
      final budgets = [
        FinanceBudget(
          id: 'overall',
          name: 'Monthly',
          limitPaise: 7000,
          periodId: '2025-06',
          startDate: DateTime.utc(2025, 6, 1),
          endDate: DateTime.utc(2025, 7, 1),
        ),
        FinanceBudget(
          id: 'food',
          name: 'Food cap',
          category: 'Food',
          limitPaise: 4000,
          periodId: '2025-06',
          startDate: DateTime.utc(2025, 6, 1),
          endDate: DateTime.utc(2025, 7, 1),
        ),
      ];
      final context = AdvisorFinancialContextBuilder.build(
        now: now,
        accounts: accounts,
        transactions: transactions,
        budgets: budgets,
        upcomingBills: [
          _bill('electric', 'Electricity', 12000, DateTime.utc(2025, 6, 20)),
        ],
        overdueBills: [
          _bill('water', 'Water', 2500, DateTime.utc(2025, 6, 12)),
        ],
      );

      expect(context.periodLabel, 'June 2025');
      expect(context.hasCurrentMonthTransactionData, isTrue);
      expect(context.currentBalancePaise, 258000);
      expect(context.incomePaise, 20000);
      expect(context.expensesPaise, 8000);
      expect(context.netCashFlowPaise, 12000);
      expect(context.previousMonthExpensesPaise, 4000);
      expect(context.hasPreviousMonthExpenseData, isTrue);
      expect(context.monthComparison.percentageChange, 100);
      expect(context.categoryExpensesPaise, {'Food': 5000, 'Rent': 3000});
      expect(context.budgets.first.remainingPaise, -1000);
      expect(context.budgets.last.remainingPaise, -1000);
      expect(context.upcomingBills.single.title, 'Electricity');
      expect(context.overdueBills.single.amountPaise, 2500);
      expect(context.toString(), isNot(contains('salary')));
    },
  );

  test(
    'empty and incomplete snapshots are safe and preserve missing-data signals',
    () {
      final context = AdvisorFinancialContextBuilder.build(
        now: DateTime.utc(2025, 1, 2),
        accounts: [],
        transactions: [],
        budgets: [],
        upcomingBills: [],
        overdueBills: [],
      );
      expect(context.hasFinancialData, isFalse);
      expect(context.hasTransactionData, isFalse);
      expect(context.hasCurrentMonthTransactionData, isFalse);
      expect(context.currentBalancePaise, 0);
      expect(context.incomePaise, 0);
      expect(context.expensesPaise, 0);
      expect(context.hasPreviousMonthExpenseData, isFalse);
      expect(context.budgets, isEmpty);
      expect(context.upcomingBills, isEmpty);
      expect(context.overdueBills, isEmpty);

      final accountsOnly = AdvisorFinancialContextBuilder.build(
        now: DateTime.utc(2025, 1, 2),
        accounts: [
          FinanceAccount(
            id: 'bank',
            name: 'Bank',
            type: AccountType.bank,
            openingBalancePaise: 7500,
          ),
        ],
        transactions: [],
        budgets: [],
        upcomingBills: [],
        overdueBills: [],
      );
      expect(accountsOnly.hasFinancialData, isTrue);
      expect(accountsOnly.hasTransactionData, isFalse);
      expect(accountsOnly.currentBalancePaise, 7500);

      final historicalOnly = AdvisorFinancialContextBuilder.build(
        now: DateTime.utc(2025, 1, 2),
        accounts: [],
        transactions: [
          _transaction(
            'old-expense',
            1250,
            TransactionType.expense,
            'Food',
            DateTime.utc(2024, 12, 20),
          ),
        ],
        budgets: [],
        upcomingBills: [],
        overdueBills: [],
      );
      expect(historicalOnly.hasTransactionData, isTrue);
      expect(historicalOnly.hasCurrentMonthTransactionData, isFalse);
    },
  );
}

FinanceTransaction _transaction(
  String id,
  int paise,
  TransactionType type,
  String category,
  DateTime date,
) => FinanceTransaction(
  id: id,
  amountPaise: paise,
  type: type,
  category: category,
  description: 'Private transaction description $id',
  transactionDate: date,
);

BillReminder _bill(String id, String title, int paise, DateTime due) =>
    BillReminder(id: id, title: title, amountPaise: paise, dueDate: due);
