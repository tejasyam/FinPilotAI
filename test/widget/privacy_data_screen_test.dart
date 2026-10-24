import 'package:finpilot_ai/features/advisor/domain/advisor_conversation_store.dart';
import 'package:finpilot_ai/features/settings/presentation/screens/privacy_data_screen.dart';
import 'package:finpilot_ai/features/transactions/controllers/finance_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('deletion confirmation can be canceled and chat can be cleared', (
    tester,
  ) async {
    final controller = _FakeFinanceController();
    final conversation = AdvisorConversationStore()
      ..add(const AdvisorMessage(isUser: true, text: 'Private question'));
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyDataScreen(
          controller: controller,
          conversationStore: conversation,
        ),
      ),
    );

    await tester.tap(find.text('Clear Advisor conversation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear conversation'));
    await tester.pumpAndSettle();
    expect(conversation.messages, isEmpty);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all local data'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);
    await tester.tap(find.text('Keep my data'));
    await tester.pumpAndSettle();
    expect(controller.deleteCalls, 0);

    conversation.dispose();
    controller.dispose();
  });
}

class _FakeFinanceController extends FinanceController {
  int deleteCalls = 0;

  @override
  Future<void> deleteAllLocalData() async {
    deleteCalls++;
  }

  @override
  Future<Map<String, Object?>> buildFinancialExport() async => {};
}
