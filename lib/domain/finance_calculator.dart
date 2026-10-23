import '../core/errors/app_exception.dart';
import '../data/models/finance_models.dart';

class PeriodTotals {
  const PeriodTotals({required this.incomePaise, required this.expensesPaise})
    : netCashFlowPaise = incomePaise - expensesPaise;

  final int incomePaise;
  final int expensesPaise;
  final int netCashFlowPaise;
}

class BudgetUsage {
  const BudgetUsage({required this.spentPaise, required this.limitPaise})
    : remainingPaise = limitPaise - spentPaise;

  final int spentPaise;
  final int limitPaise;
  final int remainingPaise;

  double get utilizationPercent =>
      limitPaise == 0 ? 0 : spentPaise * 100 / limitPaise;
}

class MonthComparison {
  const MonthComparison({
    required this.currentPaise,
    required this.previousPaise,
  });

  final int currentPaise;
  final int previousPaise;

  double? get percentageChange {
    if (previousPaise == 0) return null;
    return (currentPaise - previousPaise) * 100 / previousPaise;
  }
}

abstract final class FinanceCalculator {
  /// Calendar periods are half-open UTC intervals: [start, end).
  static PeriodTotals totalsForPeriod(
    Iterable<FinanceTransaction> transactions, {
    required DateTime start,
    required DateTime end,
  }) {
    _validateRange(start, end);
    var income = 0;
    var expenses = 0;
    for (final transaction in transactions) {
      if (!_inRange(transaction.transactionDate, start, end)) continue;
      if (transaction.type == TransactionType.income) {
        income += transaction.amountPaise;
      } else {
        expenses += transaction.amountPaise;
      }
    }
    return PeriodTotals(incomePaise: income, expensesPaise: expenses);
  }

  /// Current balance = sum(opening balances) + all income - all expenses.
  /// Net cash flow only includes transactions inside the selected period.
  static int currentBalancePaise({
    required Iterable<FinanceAccount> accounts,
    required Iterable<FinanceTransaction> transactions,
  }) {
    var balance = accounts.fold<int>(
      0,
      (sum, account) => sum + account.openingBalancePaise,
    );
    for (final transaction in transactions) {
      balance += transaction.type == TransactionType.income
          ? transaction.amountPaise
          : -transaction.amountPaise;
    }
    return balance;
  }

  static Map<String, int> expensesByCategory(
    Iterable<FinanceTransaction> transactions, {
    required DateTime start,
    required DateTime end,
  }) {
    _validateRange(start, end);
    final totals = <String, int>{};
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense &&
          _inRange(transaction.transactionDate, start, end)) {
        totals.update(
          transaction.category,
          (value) => value + transaction.amountPaise,
          ifAbsent: () => transaction.amountPaise,
        );
      }
    }
    return Map.unmodifiable(totals);
  }

  static BudgetUsage budgetUsage({
    required int expensePaise,
    required int limitPaise,
  }) {
    if (expensePaise < 0 || limitPaise < 0) {
      throw const AppException('Budget values cannot be negative.');
    }
    return BudgetUsage(spentPaise: expensePaise, limitPaise: limitPaise);
  }

  static MonthComparison compareMonths({
    required int currentExpensePaise,
    required int previousExpensePaise,
  }) {
    if (currentExpensePaise < 0 || previousExpensePaise < 0) {
      throw const AppException('Expense totals cannot be negative.');
    }
    return MonthComparison(
      currentPaise: currentExpensePaise,
      previousPaise: previousExpensePaise,
    );
  }

  static int upcomingBillsTotal(
    Iterable<BillReminder> bills, {
    required DateTime from,
    required DateTime through,
  }) {
    _validateRange(from, through);
    return bills
        .where((bill) => !bill.isPaid && _inRange(bill.dueDate, from, through))
        .fold<int>(0, (sum, bill) => sum + bill.amountPaise);
  }

  static DateTime monthStartUtc(int year, int month) =>
      DateTime.utc(year, month);
  static DateTime nextMonthStartUtc(int year, int month) =>
      DateTime.utc(year, month + 1);

  static void _validateRange(DateTime start, DateTime end) {
    if (!end.toUtc().isAfter(start.toUtc())) {
      throw const AppException('End date must be after start date.');
    }
  }

  static bool _inRange(DateTime value, DateTime start, DateTime end) {
    final date = value.toUtc();
    return !date.isBefore(start.toUtc()) && date.isBefore(end.toUtc());
  }
}
