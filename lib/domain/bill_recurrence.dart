import '../data/models/finance_models.dart';

abstract final class BillRecurrenceCalculator {
  /// Computes one occurrence from the current due date, retaining the original
  /// day-of-month anchor for monthly/yearly schedules (for example Jan 31 ->
  /// Feb 28 -> Mar 31). Uses calendar arithmetic rather than fixed durations.
  static DateTime? nextDueDate({
    required DateTime dueDate,
    required DateTime anchorDate,
    required BillRecurrence recurrence,
  }) {
    final due = dueDate.toLocal();
    final anchor = anchorDate.toLocal();
    switch (recurrence) {
      case BillRecurrence.none:
        return null;
      case BillRecurrence.weekly:
        return DateTime(
          due.year,
          due.month,
          due.day + 7,
          due.hour,
          due.minute,
          due.second,
          due.millisecond,
          due.microsecond,
        );
      case BillRecurrence.monthly:
        return _calendarDate(due.year, due.month + 1, anchor.day, due);
      case BillRecurrence.yearly:
        return _calendarDate(due.year + 1, due.month, anchor.day, due);
    }
  }

  static DateTime _calendarDate(int year, int month, int day, DateTime source) {
    final firstOfMonth = DateTime(year, month, 1);
    final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
    return DateTime(
      firstOfMonth.year,
      firstOfMonth.month,
      day.clamp(1, lastDay),
      source.hour,
      source.minute,
      source.second,
      source.millisecond,
      source.microsecond,
    );
  }
}
