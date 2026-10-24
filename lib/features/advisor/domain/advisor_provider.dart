import 'advisor_financial_context.dart';

abstract interface class AdvisorProvider {
  String get name;
  bool get modelAvailable;
  bool get modelEnabled;

  Future<String> answer(String question, AdvisorFinancialContext context);
}

/// Selects model inference only when a real installed runtime says it is ready.
/// Milestone 7 ships no model runtime, so the fallback is the selected provider.
class AdvisorProviderSelector {
  const AdvisorProviderSelector({required this.fallback, this.localModel});

  final AdvisorProvider fallback;
  final AdvisorProvider? localModel;

  AdvisorProvider get active {
    final candidate = localModel;
    if (candidate != null &&
        candidate.modelAvailable &&
        candidate.modelEnabled) {
      return candidate;
    }
    return fallback;
  }
}

class DeterministicAdvisorProvider implements AdvisorProvider {
  const DeterministicAdvisorProvider();

  @override
  String get name => 'Deterministic local fallback';

  @override
  bool get modelAvailable => false;

  @override
  bool get modelEnabled => false;

  @override
  Future<String> answer(
    String question,
    AdvisorFinancialContext context,
  ) async {
    final normalized = question.toLowerCase();
    if (_containsAny(normalized, [
      'stock',
      'share price',
      'crypto',
      'invest',
      'loan',
      'debt',
      'credit score',
      'interest rate',
      'tax filing',
      'market price',
    ])) {
      return 'I can’t provide investment, loan, tax, credit-score, or live market advice from this app. This advisor only uses your saved local finance summaries. You can review your recorded budget and cash flow; that is general budgeting guidance, not professional financial advice.';
    }
    final asksPreviousPeriod =
        normalized.contains('last month') ||
        normalized.contains('previous month');
    final asksExpenseComparison = _containsAny(normalized, [
      'expense',
      'spend',
      'spending',
    ]);
    final asksComparison = _containsAny(normalized, [
      'compare',
      'month over month',
      'increased',
      'decreased',
      'change',
    ]);
    if ((asksPreviousPeriod || asksComparison) && !asksExpenseComparison) {
      return 'The available historical comparison is for expenses only. I can’t report a previous-period balance, income, or bill status from this summary.';
    }
    if (asksPreviousPeriod || asksComparison) {
      return _comparisonAnswer(context);
    }
    if (_containsAny(normalized, ['bill', 'due', 'overdue'])) {
      return _billAnswer(context);
    }
    if (_containsAny(normalized, [
      'budget',
      'limit',
      'overspend',
      'over budget',
    ])) {
      return _budgetAnswer(context);
    }
    if (_containsAny(normalized, [
      'category',
      'categories',
      'where did',
      'spend most',
    ])) {
      return _categoryAnswer(context);
    }
    if (_containsAny(normalized, [
      'last year',
      'this year',
      'yearly',
      'annual',
      'last week',
      'all time',
    ])) {
      return 'This advisor currently summarizes the current month and compares current-month expenses with the previous month. It does not calculate yearly, weekly, or all-time reports yet.';
    }
    if (_containsAny(normalized, ['balance'])) return _balanceAnswer(context);
    if (_containsAny(normalized, [
      'income',
      'expense',
      'cash flow',
      'cashflow',
      'spending',
      'spend',
    ])) {
      return _cashFlowAnswer(context);
    }
    return _overviewAnswer(context);
  }

  static String _balanceAnswer(AdvisorFinancialContext context) {
    if (!context.hasFinancialData) {
      return 'I can’t calculate a current balance yet because no accounts or transactions are saved. Add an account or record transactions to see a calculated balance.';
    }
    return 'Your calculated current balance is ${_money(context.currentBalancePaise)} across saved accounts and transactions. This is based only on data currently stored in FinPilotAI.';
  }

  static String _cashFlowAnswer(AdvisorFinancialContext context) {
    if (!context.hasCurrentMonthTransactionData) {
      return 'There are no saved transactions for ${context.periodLabel}, so I can’t report recorded income, expenses, or cash flow for this month.';
    }
    return 'For ${context.periodLabel}, recorded income is ${_money(context.incomePaise)}, expenses are ${_money(context.expensesPaise)}, and net cash flow is ${_signedMoney(context.netCashFlowPaise)}.';
  }

  static String _categoryAnswer(AdvisorFinancialContext context) {
    if (context.categoryExpensesPaise.isEmpty) {
      return 'No expense transactions are recorded for ${context.periodLabel}, so there is no category breakdown to show.';
    }
    final categories = context.categoryExpensesPaise.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final listed = categories
        .take(4)
        .map((entry) => '${entry.key}: ${_money(entry.value)}')
        .join('; ');
    return 'Recorded expenses by category for ${context.periodLabel}: $listed. These totals come from saved expense transactions.';
  }

  static String _budgetAnswer(AdvisorFinancialContext context) {
    if (context.budgets.isEmpty) {
      return 'No budgets are saved for ${context.periodLabel}. You can set a monthly or category budget in Money → Budgets. A useful starting point is to compare recurring essentials with recorded monthly income before choosing a limit.';
    }
    final summaries = context.budgets
        .map((budget) {
          final scope = budget.category ?? 'Overall';
          final remaining = budget.isOverLimit
              ? '${_money(-budget.remainingPaise)} over the limit'
              : '${_money(budget.remainingPaise)} remaining';
          return '$scope: ${_money(budget.spentPaise)} of ${_money(budget.limitPaise)} ($remaining)';
        })
        .join('; ');
    final firstOver = context.budgets
        .where((item) => item.isOverLimit)
        .firstOrNull;
    final suggestion = firstOver == null
        ? 'Consider checking progress before discretionary purchases.'
        : 'The ${firstOver.category ?? 'overall'} budget is over its limit; reviewing upcoming optional spending may help.';
    return 'Budget progress for ${context.periodLabel}: $summaries. Suggestion: $suggestion This is general budgeting guidance, not professional financial advice.';
  }

  static String _billAnswer(AdvisorFinancialContext context) {
    if (context.upcomingBillCount == 0 && context.overdueBillCount == 0) {
      return 'There are no unpaid upcoming or overdue bills in the locally saved bill list.';
    }
    final parts = <String>[];
    if (context.overdueBills.isNotEmpty) {
      parts.add('Overdue: ${_billList(context.overdueBills)}');
    }
    if (context.upcomingBills.isNotEmpty) {
      parts.add('Upcoming: ${_billList(context.upcomingBills)}');
    }
    final extraUpcoming =
        context.upcomingBillCount - context.upcomingBills.length;
    final extraOverdue = context.overdueBillCount - context.overdueBills.length;
    final more = <String>[
      if (extraOverdue > 0) '$extraOverdue more overdue bills',
      if (extraUpcoming > 0) '$extraUpcoming more upcoming bills',
    ];
    return '${parts.join('. ')}${more.isEmpty ? '' : '. Also: ${more.join(' and ')}'}. These are saved bill reminders; this does not confirm whether a bill was paid outside the app.';
  }

  static String _comparisonAnswer(AdvisorFinancialContext context) {
    if (!context.hasPreviousMonthExpenseData) {
      return 'There are no recorded expense transactions for the previous month, so a month-over-month percentage would be misleading. Current ${context.periodLabel} expenses are ${_money(context.expensesPaise)}.';
    }
    final comparison = context.monthComparison;
    final change = comparison.currentPaise - comparison.previousPaise;
    final phrase = change > 0
        ? 'increased'
        : change < 0
        ? 'decreased'
        : 'were unchanged';
    final percent = comparison.percentageChange;
    final percentText = percent == null
        ? ''
        : ' (${percent.abs().toStringAsFixed(1)}%)';
    return 'Recorded expenses $phrase by ${_money(change.abs())}$percentText: ${_money(comparison.previousPaise)} last month and ${_money(comparison.currentPaise)} in ${context.periodLabel}.';
  }

  static String _overviewAnswer(AdvisorFinancialContext context) {
    if (!context.hasFinancialData &&
        context.budgets.isEmpty &&
        context.upcomingBills.isEmpty &&
        context.overdueBills.isEmpty) {
      return 'There is not enough saved financial data to make a personalized summary yet. Add an account, transactions, budgets, or bills. Your information stays local; this deterministic advisor does not use a language model.';
    }
    final available = <String>[];
    if (context.hasFinancialData) {
      available.add('balance ${_money(context.currentBalancePaise)}');
    }
    if (context.hasCurrentMonthTransactionData) {
      available.add(
        '${_money(context.incomePaise)} income and ${_money(context.expensesPaise)} expenses this month',
      );
    } else if (context.hasTransactionData) {
      available.add('no transactions recorded in the current month');
    }
    if (context.budgets.isNotEmpty) {
      final over = context.budgets.where((budget) => budget.isOverLimit).length;
      available.add('$over of ${context.budgets.length} budgets over limit');
    }
    if (context.upcomingBillCount > 0 || context.overdueBillCount > 0) {
      available.add(
        '${context.overdueBillCount} overdue and ${context.upcomingBillCount} upcoming unpaid bills',
      );
    }
    final overBudget = context.budgets.any((budget) => budget.isOverLimit);
    final suggestion = overBudget
        ? 'Review upcoming optional spending against the budget that is over its limit.'
        : context.categoryExpensesPaise.isNotEmpty
        ? 'Review your largest expense category when deciding whether to adjust a future budget.'
        : 'Review your saved budgets and upcoming bills before setting a spending target.';
    return 'From your saved data: ${available.join('; ')}. A practical next step is: $suggestion This is general budgeting guidance, not professional financial advice.';
  }

  static String _billList(List<AdvisorBillSummary> bills) => bills
      .map(
        (bill) =>
            '${bill.title} ${_money(bill.amountPaise)} due ${_date(bill.dueDate)}',
      )
      .join(', ');

  static bool _containsAny(String text, List<String> terms) =>
      terms.any(text.contains);

  static String _money(int paise) =>
      '₹${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';

  static String _signedMoney(int paise) =>
      '${paise < 0 ? '−' : '+'}${_money(paise.abs())}';

  static String _date(DateTime date) =>
      '${date.toLocal().day.toString().padLeft(2, '0')}/'
      '${date.toLocal().month.toString().padLeft(2, '0')}/'
      '${date.toLocal().year}';
}
