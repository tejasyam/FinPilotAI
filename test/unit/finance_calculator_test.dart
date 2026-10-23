import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/domain/finance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction tx(
  String id,
  int amount,
  TransactionType type,
  String category,
  DateTime date, {
  String? accountId,
}) => FinanceTransaction(
  id: id,
  amountPaise: amount,
  type: type,
  category: category,
  description: id,
  transactionDate: date,
  accountId: accountId,
);

void main() {
  final octStart = DateTime.utc(2026, 10, 1);
  final novStart = DateTime.utc(2026, 11, 1);

  test(
    'totals separate income and expense and use [start, end) boundaries',
    () {
      final records = [
        tx('at-start', 10000, TransactionType.income, 'Salary', octStart),
        tx(
          'expense',
          2500,
          TransactionType.expense,
          'Food',
          DateTime.utc(2026, 10, 31, 23, 59, 59),
        ),
        tx('at-end', 9000, TransactionType.expense, 'Bills', novStart),
      ];
      final totals = FinanceCalculator.totalsForPeriod(
        records,
        start: octStart,
        end: novStart,
      );
      expect(totals.incomePaise, 10000);
      expect(totals.expensesPaise, 2500);
      expect(totals.netCashFlowPaise, 7500);
    },
  );

  test('current balance includes openings and all transaction history', () {
    final balance = FinanceCalculator.currentBalancePaise(
      accounts: [
        FinanceAccount(
          id: 'a',
          name: 'Cash',
          type: AccountType.cash,
          openingBalancePaise: 50000,
        ),
        FinanceAccount(
          id: 'b',
          name: 'Bank',
          type: AccountType.bank,
          openingBalancePaise: 100000,
        ),
      ],
      transactions: [
        tx('in', 30000, TransactionType.income, 'Salary', octStart),
        tx('out', 7500, TransactionType.expense, 'Food', octStart),
      ],
    );
    expect(balance, 172500);
  });

  test('category totals exclude income and group expense paise', () {
    final result = FinanceCalculator.expensesByCategory(
      [
        tx('1', 3000, TransactionType.expense, 'Food', octStart),
        tx(
          '2',
          1500,
          TransactionType.expense,
          'Food',
          novStart.subtract(const Duration(seconds: 1)),
        ),
        tx('3', 20000, TransactionType.income, 'Food', octStart),
      ],
      start: octStart,
      end: novStart,
    );
    expect(result, {'Food': 4500});
  });

  test('budget usage preserves overspend and handles zero limit', () {
    final usage = FinanceCalculator.budgetUsage(
      expensePaise: 1200,
      limitPaise: 1000,
    );
    expect(usage.remainingPaise, -200);
    expect(usage.utilizationPercent, 120);
    expect(
      FinanceCalculator.budgetUsage(
        expensePaise: 100,
        limitPaise: 0,
      ).utilizationPercent,
      0,
    );
  });

  test(
    'month comparisons handle no previous spending without a fake percent',
    () {
      expect(
        FinanceCalculator.compareMonths(
          currentExpensePaise: 100,
          previousExpensePaise: 0,
        ).percentageChange,
        isNull,
      );
      expect(
        FinanceCalculator.compareMonths(
          currentExpensePaise: 150,
          previousExpensePaise: 100,
        ).percentageChange,
        50,
      );
    },
  );

  test('month helpers correctly cross year and leap month boundaries', () {
    expect(FinanceCalculator.monthStartUtc(2024, 2), DateTime.utc(2024, 2, 1));
    expect(
      FinanceCalculator.nextMonthStartUtc(2024, 2),
      DateTime.utc(2024, 3, 1),
    );
    expect(
      FinanceCalculator.nextMonthStartUtc(2026, 12),
      DateTime.utc(2027, 1, 1),
    );
  });

  test('upcoming bill total ignores paid and out of range records', () {
    final bills = [
      BillReminder(
        id: '1',
        title: 'Rent',
        amountPaise: 10000,
        dueDate: octStart,
      ),
      BillReminder(
        id: '2',
        title: 'Paid',
        amountPaise: 5000,
        dueDate: octStart,
        isPaid: true,
      ),
      BillReminder(
        id: '3',
        title: 'Next month',
        amountPaise: 7000,
        dueDate: novStart,
      ),
    ];
    expect(
      FinanceCalculator.upcomingBillsTotal(
        bills,
        from: octStart,
        through: novStart,
      ),
      10000,
    );
  });
}
