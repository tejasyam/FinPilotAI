import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/domain/bill_recurrence.dart';
import 'package:finpilot_ai/features/bills/services/bill_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly recurrence keeps the original day across short months', () {
    final anchor = DateTime(2025, 1, 31, 12);
    final february = BillRecurrenceCalculator.nextDueDate(
      dueDate: anchor,
      anchorDate: anchor,
      recurrence: BillRecurrence.monthly,
    )!;
    final march = BillRecurrenceCalculator.nextDueDate(
      dueDate: february,
      anchorDate: anchor,
      recurrence: BillRecurrence.monthly,
    )!;
    expect(february, DateTime(2025, 2, 28, 12));
    expect(march, DateTime(2025, 3, 31, 12));
  });

  test('yearly recurrence clamps leap day and restores it in leap years', () {
    final anchor = DateTime(2024, 2, 29, 9);
    final nextYear = BillRecurrenceCalculator.nextDueDate(
      dueDate: anchor,
      anchorDate: anchor,
      recurrence: BillRecurrence.yearly,
    )!;
    final leapYear = BillRecurrenceCalculator.nextDueDate(
      dueDate: DateTime(2027, 2, 28, 9),
      anchorDate: anchor,
      recurrence: BillRecurrence.yearly,
    )!;
    expect(nextYear, DateTime(2025, 2, 28, 9));
    expect(leapYear, DateTime(2028, 2, 29, 9));
  });

  test('weekly and one-time schedules are handled explicitly', () {
    final due = DateTime(2026, 12, 28, 8);
    expect(
      BillRecurrenceCalculator.nextDueDate(
        dueDate: due,
        anchorDate: due,
        recurrence: BillRecurrence.weekly,
      ),
      DateTime(2027, 1, 4, 8),
    );
    expect(
      BillRecurrenceCalculator.nextDueDate(
        dueDate: due,
        anchorDate: due,
        recurrence: BillRecurrence.none,
      ),
      isNull,
    );
  });

  test('notification IDs are stable, non-negative, and bill-specific', () {
    final first = PlatformBillNotificationService.notificationIdFor('bill-a');
    expect(first, inInclusiveRange(0, 0x7fffffff));
    expect(PlatformBillNotificationService.notificationIdFor('bill-a'), first);
    expect(
      PlatformBillNotificationService.notificationIdFor('bill-b'),
      isNot(first),
    );
  });
}
