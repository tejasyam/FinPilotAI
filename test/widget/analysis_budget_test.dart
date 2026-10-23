import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/domain/finance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'monthly analysis uses expenses, categories, and prior month totals',
    () {
      final currentMonth = DateTime.utc(2026, 10, 1);
      final transactions = [
        FinanceTransaction(
          id: 'salary',
          amountPaise: 10000,
          type: TransactionType.income,
          category: 'Salary',
          description: 'Pay',
          transactionDate: DateTime.utc(2026, 10, 2),
        ),
        FinanceTransaction(
          id: 'food',
          amountPaise: 4000,
          type: TransactionType.expense,
          category: 'Food',
          description: 'Groceries',
          transactionDate: DateTime.utc(2026, 10, 3),
        ),
        FinanceTransaction(
          id: 'travel',
          amountPaise: 2000,
          type: TransactionType.expense,
          category: 'Travel',
          description: 'Train',
          transactionDate: DateTime.utc(2026, 10, 4),
        ),
        FinanceTransaction(
          id: 'old',
          amountPaise: 1000,
          type: TransactionType.expense,
          category: 'Bills',
          description: 'Old bill',
          transactionDate: DateTime.utc(2026, 9, 5),
        ),
      ];

      final current = FinanceCalculator.totalsForPeriod(
        transactions,
        start: currentMonth,
        end: DateTime.utc(2026, 11, 1),
      );
      final previous = FinanceCalculator.totalsForPeriod(
        transactions,
        start: DateTime.utc(2026, 9, 1),
        end: currentMonth,
      );
      expect(current.incomePaise, 10000);
      expect(current.expensesPaise, 6000);
      expect(current.netCashFlowPaise, 4000);
      expect(previous.expensesPaise, 1000);
      expect(
        FinanceCalculator.expensesByCategory(
          transactions,
          start: currentMonth,
          end: DateTime.utc(2026, 11, 1),
        ),
        {'Food': 4000, 'Travel': 2000},
      );
      expect(
        FinanceCalculator.compareMonths(
          currentExpensePaise: current.expensesPaise,
          previousExpensePaise: previous.expensesPaise,
        ).percentageChange,
        500,
      );
    },
  );

  test('budgets scope monthly expense usage and signal over-limit amounts', () {
    final start = DateTime.utc(2026, 10, 1);
    final end = DateTime.utc(2026, 11, 1);
    final budget = FinanceBudget(
      id: 'food-budget',
      name: 'Food only',
      category: 'Food',
      limitPaise: 5000,
      periodId: '2026-10',
      startDate: start,
      endDate: end,
    );
    final transactions = [
      FinanceTransaction(
        id: 'food',
        amountPaise: 2500,
        type: TransactionType.expense,
        category: 'Food',
        description: 'Meal',
        transactionDate: DateTime.utc(2026, 10, 2),
      ),
      FinanceTransaction(
        id: 'travel',
        amountPaise: 9000,
        type: TransactionType.expense,
        category: 'Travel',
        description: 'Ticket',
        transactionDate: DateTime.utc(2026, 10, 3),
      ),
      FinanceTransaction(
        id: 'salary',
        amountPaise: 80000,
        type: TransactionType.income,
        category: 'Food',
        description: 'Refund',
        transactionDate: DateTime.utc(2026, 10, 4),
      ),
      FinanceTransaction(
        id: 'old-food',
        amountPaise: 7000,
        type: TransactionType.expense,
        category: 'Food',
        description: 'Prior month meal',
        transactionDate: DateTime.utc(2026, 9, 28),
      ),
    ];
    final matchingExpense = transactions
        .where(
          (item) =>
              item.type == TransactionType.expense &&
              !item.transactionDate.isBefore(budget.startDate) &&
              item.transactionDate.isBefore(budget.endDate) &&
              item.category == budget.category,
        )
        .fold<int>(0, (sum, item) => sum + item.amountPaise);
    final usage = FinanceCalculator.budgetUsage(
      expensePaise: matchingExpense,
      limitPaise: budget.limitPaise,
    );
    expect(matchingExpense, 2500);
    expect(usage.utilizationPercent, 50);
    expect(usage.remainingPaise, 2500);
    final overLimit = FinanceCalculator.budgetUsage(
      expensePaise: 6000,
      limitPaise: 5000,
    );
    expect(overLimit.remainingPaise, -1000);
    expect(overLimit.utilizationPercent, 120);
  });
}
