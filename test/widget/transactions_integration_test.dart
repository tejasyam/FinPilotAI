import 'package:finpilot_ai/app/app.dart';
import 'package:finpilot_ai/core/utils/money_parser.dart';
import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/features/transactions/controllers/finance_controller.dart';
import 'package:finpilot_ai/features/transactions/presentation/screens/transaction_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  testWidgets('transaction form saves, updates summaries, edits, and deletes', (
    tester,
  ) async {
    final controller = _TestFinanceController();
    await tester.pumpWidget(FinPilotApp(financeController: controller));
    await tester.tap(find.text('Open local data'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (₹)'),
      '125.50',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description or merchant'),
      'Lunch',
    );
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(controller.transactions, hasLength(1));
    expect(controller.transactions.single.amountPaise, 12550);
    expect(
      find.text('₹0.00'),
      findsWidgets,
    ); // no account means no opening balance
    await tester.dragUntilVisible(
      find.text('Lunch'),
      find.byType(Scrollable).first,
      const Offset(0, -400),
    );
    expect(find.text('Lunch'), findsOneWidget);

    final saved = controller.transactions.single;
    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (₹)'),
      '200.00',
    );
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(controller.transactions, hasLength(1));
    expect(controller.transactions.single.id, saved.id);
    expect(controller.transactions.single.amountPaise, 20000);

    await tester.dragUntilVisible(
      find.text('Lunch'),
      find.byType(Scrollable).first,
      const Offset(0, -400),
    );
    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(controller.transactions, isEmpty);
  });

  testWidgets('Money show all opens history and back returns to Money', (
    tester,
  ) async {
    final controller = _TestFinanceController()
      ..accounts = [
        FinanceAccount(
          id: 'cash',
          name: 'Cash wallet',
          type: AccountType.cash,
          openingBalancePaise: 250000,
        ),
      ]
      ..transactions = [
        FinanceTransaction(
          id: 'one',
          amountPaise: 5000,
          type: TransactionType.income,
          category: 'Salary',
          description: 'Pay',
          transactionDate: DateTime.now(),
        ),
      ];
    await tester.pumpWidget(FinPilotApp(financeController: controller));
    await tester.tap(find.text('Open local data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money').last);
    await tester.pumpAndSettle();
    expect(find.text('₹2550.00'), findsOneWidget);
    await tester.tap(find.text('Show all').last);
    await tester.pumpAndSettle();
    expect(find.byType(TransactionHistoryScreen), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Current balance · all accounts'), findsOneWidget);
  });

  test('controller displays database-empty state and refreshes from repository changes', () async {
    final database = createTestDatabase();
    final controller = FinanceController(database: database);
    await controller.load();
    expect(controller.transactions, isEmpty);
    expect(controller.currentMonthTotals.expensesPaise, 0);
    await controller.createTransaction(
      FinanceTransaction(
        id: 'expense',
        amountPaise: MoneyParser.rupeesToPaise('10.25'),
        type: TransactionType.expense,
        category: 'Food',
        description: 'Snack',
        transactionDate: DateTime.now(),
      ),
    );
    expect(controller.transactions, hasLength(1));
    expect(controller.currentMonthTotals.expensesPaise, 1025);
    expect(controller.currentMonthCategoryTotals, {'Food': 1025});
    await database.close();
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
  Future<void> createTransaction(FinanceTransaction value) async {
    transactions = [value, ...transactions];
    notifyListeners();
  }

  @override
  Future<void> updateTransaction(FinanceTransaction value) async {
    transactions = transactions
        .map((item) => item.id == value.id ? value : item)
        .toList(growable: false);
    notifyListeners();
  }

  @override
  Future<void> deleteTransaction(String id) async {
    transactions = transactions.where((item) => item.id != id).toList();
    notifyListeners();
  }
}
