import 'package:finpilot_ai/features/advisor/domain/advisor_financial_context.dart';
import 'package:finpilot_ai/features/advisor/domain/advisor_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final empty = AdvisorFinancialContextBuilder.build(
    now: DateTime.utc(2025, 2, 1),
    accounts: [],
    transactions: [],
    budgets: [],
    upcomingBills: [],
    overdueBills: [],
  );

  test(
    'deterministic provider states missing data instead of inventing facts',
    () async {
      const provider = DeterministicAdvisorProvider();
      final answer = await provider.answer('What is my balance?', empty);
      expect(answer, contains('no accounts or transactions are saved'));
      expect(answer, isNot(contains('₹0.00')));
      expect(provider.modelAvailable, isFalse);
      expect(provider.modelEnabled, isFalse);
    },
  );

  test(
    'provider uses summarized budget and bill values and labels suggestions',
    () async {
      const provider = DeterministicAdvisorProvider();
      final budget = AdvisorFinancialContext(
        periodLabel: 'February 2025',
        hasAccountData: false,
        hasTransactionData: true,
        hasCurrentMonthTransactionData: true,
        currentBalancePaise: 0,
        incomePaise: 100000,
        expensesPaise: 60000,
        netCashFlowPaise: 40000,
        previousMonthExpensesPaise: 50000,
        hasPreviousMonthExpenseData: true,
        categoryExpensesPaise: const {'Food': 40000, 'Travel': 20000},
        budgets: const [
          AdvisorBudgetSummary(
            name: 'Monthly',
            category: null,
            limitPaise: 50000,
            spentPaise: 60000,
            remainingPaise: -10000,
          ),
        ],
        upcomingBills: [
          AdvisorBillSummary(
            title: 'Power',
            amountPaise: 2500,
            dueDate: DateTime.utc(2025, 2, 10),
          ),
        ],
        overdueBills: const [],
        upcomingBillCount: 1,
        overdueBillCount: 0,
      );
      final budgetAnswer = await provider.answer('Am I over budget?', budget);
      expect(budgetAnswer, contains('₹600.00 of ₹500.00'));
      expect(budgetAnswer, contains('general budgeting guidance'));

      final billAnswer = await provider.answer('What bills are due?', budget);
      expect(billAnswer, contains('Power ₹25.00'));
      expect(billAnswer, contains('does not confirm whether a bill was paid'));
    },
  );

  test(
    'does not report zero monthly totals when records are historical only',
    () async {
      const provider = DeterministicAdvisorProvider();
      final context = AdvisorFinancialContext(
        periodLabel: 'February 2025',
        hasAccountData: false,
        hasTransactionData: true,
        hasCurrentMonthTransactionData: false,
        currentBalancePaise: -1000,
        incomePaise: 0,
        expensesPaise: 0,
        netCashFlowPaise: 0,
        previousMonthExpensesPaise: 1000,
        hasPreviousMonthExpenseData: true,
        categoryExpensesPaise: const {},
        budgets: const [],
        upcomingBills: const [],
        overdueBills: const [],
        upcomingBillCount: 0,
        overdueBillCount: 0,
      );
      final answer = await provider.answer('How much did I spend?', context);
      expect(answer, contains('no saved transactions for February 2025'));
      expect(answer, isNot(contains('expenses are ₹0.00')));
    },
  );

  test(
    'unsupported investment requests are declined without market claims',
    () async {
      const provider = DeterministicAdvisorProvider();
      final answer = await provider.answer('Should I buy a stock?', empty);
      expect(answer, contains('can’t provide investment, loan'));
      expect(answer, isNot(contains('will return')));
    },
  );

  test(
    'selector uses fallback unless local inference is installed and enabled',
    () {
      const fallback = DeterministicAdvisorProvider();
      const unavailable = _TestProvider(available: false, enabled: false);
      const disabled = _TestProvider(available: true, enabled: false);
      const ready = _TestProvider(available: true, enabled: true);
      expect(
        const AdvisorProviderSelector(
          fallback: fallback,
          localModel: unavailable,
        ).active,
        same(fallback),
      );
      expect(
        const AdvisorProviderSelector(
          fallback: fallback,
          localModel: disabled,
        ).active,
        same(fallback),
      );
      expect(
        const AdvisorProviderSelector(
          fallback: fallback,
          localModel: ready,
        ).active,
        same(ready),
      );
    },
  );
}

class _TestProvider implements AdvisorProvider {
  const _TestProvider({required this.available, required this.enabled});

  final bool available;
  final bool enabled;

  @override
  String get name => 'Test model';
  @override
  bool get modelAvailable => available;
  @override
  bool get modelEnabled => enabled;
  @override
  Future<String> answer(
    String question,
    AdvisorFinancialContext context,
  ) async => 'test';
}
