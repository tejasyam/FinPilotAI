import 'package:finpilot_ai/app/app.dart';
import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/features/transactions/controllers/finance_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'local data entry opens the preview without password collection',
    (tester) async {
      final controller = _TestFinanceController();
      await tester.pumpWidget(FinPilotApp(financeController: controller));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.textContaining('does not verify an account'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      await tester.tap(find.text('Open local data'));
      await tester.pumpAndSettle();

      expect(find.text('Total balance'), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
    },
  );

  testWidgets('all five main destinations show distinct screens', (
    tester,
  ) async {
    final controller = _TestFinanceController();
    await tester.pumpWidget(FinPilotApp(financeController: controller));
    await tester.tap(find.text('Open local data'));
    await tester.pumpAndSettle();

    for (final destination in [
      'Money',
      'Analysis',
      'Advisor',
      'Settings',
      'Home',
    ]) {
      await tester.tap(find.text(destination).last);
      await tester.pumpAndSettle();
      if (destination == 'Analysis') {
        expect(find.text('Spending Analysis'), findsWidgets);
      } else {
        expect(find.text(destination), findsWidgets);
      }
    }
  });

  testWidgets('restored local session starts at Home', (tester) async {
    final controller = _TestFinanceController()..localSessionActive = true;
    await tester.pumpWidget(FinPilotApp(financeController: controller));
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('registration requires local-profile acknowledgement', (
    tester,
  ) async {
    final controller = _TestFinanceController();
    await tester.pumpWidget(FinPilotApp(financeController: controller));
    await tester.ensureVisible(find.text('Create local profile'));
    await tester.tap(find.text('Create local profile'));
    await tester.pumpAndSettle();
    expect(find.text('Create a local profile'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Pilot',
    );
    await tester.tap(find.text('Continue with local profile'));
    await tester.pumpAndSettle();
    expect(
      find.text('Please confirm the local-profile explanation.'),
      findsOneWidget,
    );
  });
}

class _TestFinanceController extends FinanceController {
  _TestFinanceController() {
    isLoading = false;
  }

  @override
  Future<List<FinanceBudget>> budgetsForMonth(DateTime month) async => [];

  @override
  Future<void> activateLocalSession() async {
    localSessionActive = true;
  }

  @override
  Future<void> saveLocalProfile({required String name, String? email}) async {
    localProfileName = name.trim();
    localProfileEmail = email;
    localSessionActive = true;
  }
}
