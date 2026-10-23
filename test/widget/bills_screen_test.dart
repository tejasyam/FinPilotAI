import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/features/bills/presentation/screens/bills_screen.dart';
import 'package:finpilot_ai/features/transactions/controllers/finance_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bill list refreshes from controller and filters its states', (
    tester,
  ) async {
    final controller = FinanceController()..isLoading = false;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day, 12);
    controller.bills = [
      _bill('current', 'Current due', day),
      _bill('past', 'Past due', day.subtract(const Duration(days: 2))),
      _bill('settled', 'Settled bill', day, isPaid: true),
    ];

    await tester.pumpWidget(
      MaterialApp(home: BillsScreen(controller: controller)),
    );
    await tester.pump();
    expect(find.text('Current due'), findsOneWidget);
    expect(find.text('Past due'), findsNothing);

    await tester.tap(find.text('Overdue'));
    await tester.pump();
    expect(find.text('Past due'), findsOneWidget);
    expect(find.text('Current due'), findsNothing);

    controller.bills = [
      ...controller.bills,
      _bill('new', 'New overdue', day.subtract(const Duration(days: 1))),
    ];
    controller.notifyListeners();
    await tester.pump();
    expect(find.text('New overdue'), findsOneWidget);

    await tester.tap(find.text('Paid'));
    await tester.pump();
    expect(find.text('Settled bill'), findsOneWidget);
    expect(find.text('Past due'), findsNothing);
  });
}

BillReminder _bill(
  String id,
  String title,
  DateTime due, {
  bool isPaid = false,
}) => BillReminder(
  id: id,
  title: title,
  amountPaise: 1000,
  dueDate: due,
  isPaid: isPaid,
);
