import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/features/advisor/presentation/screens/advisor_screen.dart';
import 'package:finpilot_ai/features/advisor/domain/advisor_conversation_store.dart';
import 'package:finpilot_ai/features/transactions/controllers/finance_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows fallback disclosure and clears session conversation', (
    tester,
  ) async {
    final controller = _FakeFinanceController();
    await tester.pumpWidget(
      MaterialApp(
        home: AdvisorScreen(
          controller: controller,
          conversationStore: AdvisorConversationStore(),
        ),
      ),
    );

    expect(find.text('Deterministic local fallback'), findsOneWidget);
    expect(find.textContaining('No language model installed'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'What is my balance?');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();

    expect(find.text('What is my balance?'), findsOneWidget);
    expect(
      find.textContaining('no accounts or transactions are saved'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Clear conversation'));
    await tester.pumpAndSettle();

    expect(find.text('What is my balance?'), findsNothing);
    expect(find.text('How much did I spend this month?'), findsOneWidget);
  });
}

class _FakeFinanceController extends FinanceController {
  _FakeFinanceController() {
    isLoading = false;
  }

  @override
  Future<List<FinanceBudget>> budgetsForMonth(DateTime month) async => [];
}
