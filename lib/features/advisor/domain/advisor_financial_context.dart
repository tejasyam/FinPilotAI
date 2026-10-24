import '../../../../data/models/finance_models.dart';
import '../../../../domain/finance_calculator.dart';

/// A compact, typed summary. Raw transaction history never enters this object.
class AdvisorFinancialContext {
  const AdvisorFinancialContext({
    required this.periodLabel,
    required this.hasAccountData,
    required this.hasTransactionData,
    required this.hasCurrentMonthTransactionData,
    required this.currentBalancePaise,
    required this.incomePaise,
    required this.expensesPaise,
    required this.netCashFlowPaise,
    required this.previousMonthExpensesPaise,
    required this.hasPreviousMonthExpenseData,
    required this.categoryExpensesPaise,
    required this.budgets,
    required this.upcomingBills,
    required this.overdueBills,
    required this.upcomingBillCount,
    required this.overdueBillCount,
  });

  final String periodLabel;
  final bool hasAccountData;
  final bool hasTransactionData;
  final bool hasCurrentMonthTransactionData;
  final int currentBalancePaise;
  final int incomePaise;
  final int expensesPaise;
  final int netCashFlowPaise;
  final int previousMonthExpensesPaise;
  final bool hasPreviousMonthExpenseData;
  final Map<String, int> categoryExpensesPaise;
  final List<AdvisorBudgetSummary> budgets;
  final List<AdvisorBillSummary> upcomingBills;
  final List<AdvisorBillSummary> overdueBills;
  final int upcomingBillCount;
  final int overdueBillCount;

  bool get hasFinancialData => hasAccountData || hasTransactionData;

  MonthComparison get monthComparison => FinanceCalculator.compareMonths(
    currentExpensePaise: expensesPaise,
    previousExpensePaise: previousMonthExpensesPaise,
  );
}

class AdvisorBudgetSummary {
  const AdvisorBudgetSummary({
    required this.name,
    required this.category,
    required this.limitPaise,
    required this.spentPaise,
    required this.remainingPaise,
  });

  final String name;
  final String? category;
  final int limitPaise;
  final int spentPaise;
  final int remainingPaise;

  bool get isOverLimit => remainingPaise < 0;
}

class AdvisorBillSummary {
  const AdvisorBillSummary({
    required this.title,
    required this.amountPaise,
    required this.dueDate,
  });

  final String title;
  final int amountPaise;
  final DateTime dueDate;
}

abstract final class AdvisorFinancialContextBuilder {
  static AdvisorFinancialContext build({
    required DateTime now,
    required List<FinanceAccount> accounts,
    required List<FinanceTransaction> transactions,
    required List<FinanceBudget> budgets,
    required List<BillReminder> upcomingBills,
    required List<BillReminder> overdueBills,
  }) {
    final localNow = now.toLocal();
    final start = FinanceCalculator.monthStartUtc(
      localNow.year,
      localNow.month,
    );
    final end = FinanceCalculator.nextMonthStartUtc(
      localNow.year,
      localNow.month,
    );
    final previousStart = FinanceCalculator.monthStartUtc(
      localNow.year,
      localNow.month - 1,
    );
    final current = FinanceCalculator.totalsForPeriod(
      transactions,
      start: start,
      end: end,
    );
    final hasCurrentMonthTransactions = transactions.any(
      (transaction) =>
          !transaction.transactionDate.isBefore(start) &&
          transaction.transactionDate.isBefore(end),
    );
    final previous = FinanceCalculator.totalsForPeriod(
      transactions,
      start: previousStart,
      end: start,
    );
    final previousHasExpense = transactions.any(
      (transaction) =>
          transaction.type == TransactionType.expense &&
          !transaction.transactionDate.isBefore(previousStart) &&
          transaction.transactionDate.isBefore(start),
    );
    final categories = FinanceCalculator.expensesByCategory(
      transactions,
      start: start,
      end: end,
    );
    final budgetSummaries = budgets
        .map((budget) {
          final spent = budget.category == null
              ? current.expensesPaise
              : categories[budget.category] ?? 0;
          final usage = FinanceCalculator.budgetUsage(
            expensePaise: spent,
            limitPaise: budget.limitPaise,
          );
          return AdvisorBudgetSummary(
            name: budget.name,
            category: budget.category,
            limitPaise: usage.limitPaise,
            spentPaise: usage.spentPaise,
            remainingPaise: usage.remainingPaise,
          );
        })
        .toList(growable: false);
    final monthName = _monthNames[localNow.month - 1];

    return AdvisorFinancialContext(
      periodLabel: '$monthName ${localNow.year}',
      hasAccountData: accounts.isNotEmpty,
      hasTransactionData: transactions.isNotEmpty,
      hasCurrentMonthTransactionData: hasCurrentMonthTransactions,
      currentBalancePaise: FinanceCalculator.currentBalancePaise(
        accounts: accounts,
        transactions: transactions,
      ),
      incomePaise: current.incomePaise,
      expensesPaise: current.expensesPaise,
      netCashFlowPaise: current.netCashFlowPaise,
      previousMonthExpensesPaise: previous.expensesPaise,
      hasPreviousMonthExpenseData: previousHasExpense,
      categoryExpensesPaise: categories,
      budgets: List.unmodifiable(budgetSummaries),
      upcomingBills: upcomingBills
          .take(5)
          .map(_billSummary)
          .toList(growable: false),
      overdueBills: overdueBills
          .take(5)
          .map(_billSummary)
          .toList(growable: false),
      upcomingBillCount: upcomingBills.length,
      overdueBillCount: overdueBills.length,
    );
  }

  static AdvisorBillSummary _billSummary(BillReminder bill) =>
      AdvisorBillSummary(
        title: bill.title,
        amountPaise: bill.amountPaise,
        dueDate: bill.dueDate,
      );

  static const _monthNames = [
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
}
