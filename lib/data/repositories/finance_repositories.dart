import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../database/app_database.dart';
import '../models/finance_models.dart';
import '../../domain/bill_recurrence.dart';

abstract class _Repository {
  const _Repository(this.database);

  final AppDatabase database;

  Future<Database> get db => database.database;

  Future<void> _insert(String table, Map<String, Object?> values) async {
    try {
      await (await db).insert(
        table,
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException {
      throw const AppException(
        'Could not create record because local storage failed.',
      );
    }
  }

  Future<void> _update(
    String table,
    String id,
    Map<String, Object?> values,
  ) async {
    try {
      final count = await (await db).update(
        table,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) throw const AppException('Record not found.');
    } on DatabaseException {
      throw const AppException(
        'Could not update record because local storage failed.',
      );
    }
  }

  Future<void> _delete(String table, String id) async {
    try {
      final count = await (await db).delete(
        table,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) throw const AppException('Record not found.');
    } on DatabaseException {
      throw const AppException(
        'Could not delete record because local storage failed.',
      );
    }
  }

  Future<Map<String, Object?>?> _byId(String table, String id) async {
    final rows = await (await db).query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}

class TransactionRepository extends _Repository {
  const TransactionRepository(super.database);

  Future<void> create(FinanceTransaction value) =>
      _insert('transactions', value.toMap());
  Future<void> update(FinanceTransaction value) =>
      _update('transactions', value.id, value.toMap());
  Future<void> delete(String id) => _delete('transactions', id);

  Future<FinanceTransaction?> getById(String id) async {
    final row = await _byId('transactions', id);
    return row == null ? null : FinanceTransaction.fromMap(row);
  }

  Future<List<FinanceTransaction>> getAll({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    TransactionType? type,
    String? accountId,
  }) async {
    if (startDate != null && endDate != null && !endDate.isAfter(startDate)) {
      throw const AppException('End date must be after start date.');
    }
    final clauses = <String>[];
    final args = <Object?>[];
    if (startDate != null) {
      clauses.add('transaction_date >= ?');
      args.add(startDate.toUtc().toIso8601String());
    }
    if (endDate != null) {
      clauses.add('transaction_date < ?');
      args.add(endDate.toUtc().toIso8601String());
    }
    if (category != null) {
      clauses.add('category = ?');
      args.add(category);
    }
    if (type != null) {
      clauses.add('type = ?');
      args.add(type.name);
    }
    if (accountId != null) {
      clauses.add('account_id = ?');
      args.add(accountId);
    }
    final rows = await (await db).query(
      'transactions',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'transaction_date DESC, id ASC',
    );
    return rows.map(FinanceTransaction.fromMap).toList(growable: false);
  }
}

class AccountRepository extends _Repository {
  const AccountRepository(super.database);

  Future<void> create(FinanceAccount value) =>
      _insert('accounts', value.toMap());
  Future<void> update(FinanceAccount value) =>
      _update('accounts', value.id, value.toMap());
  Future<void> delete(String id) => _delete('accounts', id);

  Future<FinanceAccount?> getById(String id) async {
    final row = await _byId('accounts', id);
    return row == null ? null : FinanceAccount.fromMap(row);
  }

  Future<List<FinanceAccount>> getAll() async => (await (await db).query(
    'accounts',
    orderBy: 'name COLLATE NOCASE',
  )).map(FinanceAccount.fromMap).toList(growable: false);
}

class BudgetRepository extends _Repository {
  const BudgetRepository(super.database);

  Future<void> create(FinanceBudget value) async {
    await _ensureUniqueScope(value);
    await _insert('budgets', value.toMap());
  }

  Future<void> update(FinanceBudget value) async {
    await _ensureUniqueScope(value, excludingId: value.id);
    await _update('budgets', value.id, value.toMap());
  }

  Future<void> _ensureUniqueScope(
    FinanceBudget value, {
    String? excludingId,
  }) async {
    final rows = await (await db).query(
      'budgets',
      where: value.category == null
          ? 'period_id = ? AND category IS NULL'
          : 'period_id = ? AND category = ?',
      whereArgs: [value.periodId, if (value.category != null) value.category],
    );
    if (rows.any((row) => row['id'] != excludingId)) {
      throw const AppException(
        'A budget already exists for this month and category.',
      );
    }
  }

  Future<void> delete(String id) => _delete('budgets', id);

  Future<FinanceBudget?> getById(String id) async {
    final row = await _byId('budgets', id);
    return row == null ? null : FinanceBudget.fromMap(row);
  }

  Future<List<FinanceBudget>> getForMonth(String periodId) async =>
      (await (await db).query(
        'budgets',
        where: 'period_id = ?',
        whereArgs: [periodId],
        orderBy: 'category',
      )).map(FinanceBudget.fromMap).toList(growable: false);

  Future<List<FinanceBudget>> getAll() async => (await (await db).query(
    'budgets',
    orderBy: 'period_id DESC, category COLLATE NOCASE',
  )).map(FinanceBudget.fromMap).toList(growable: false);
}

class BillRepository extends _Repository {
  const BillRepository(super.database);

  Future<void> create(BillReminder value) => _insert('bills', value.toMap());
  Future<void> update(BillReminder value) =>
      _update('bills', value.id, value.toMap());
  Future<void> delete(String id) => _delete('bills', id);

  /// Marks one occurrence paid and creates its next occurrence atomically.
  /// A stable series/date key plus the database unique index makes retries
  /// idempotent and prevents duplicate scheduled bills.
  Future<BillReminder?> markPaidAndAdvance(String id) async {
    final database = await db;
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'bills',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw const AppException('Record not found.');
      final bill = BillReminder.fromMap(rows.first);
      if (bill.isPaid) return null;
      await transaction.update(
        'bills',
        {...bill.toMap(), 'is_paid': 1},
        where: 'id = ?',
        whereArgs: [bill.id],
      );
      final nextDue = BillRecurrenceCalculator.nextDueDate(
        dueDate: bill.dueDate,
        anchorDate: bill.recurrenceAnchorDate,
        recurrence: bill.recurrence,
      );
      if (nextDue == null) return null;
      final seriesId = bill.recurrenceSeriesId ?? bill.id;
      final next = BillReminder(
        id: _recurringBillId(seriesId, nextDue),
        title: bill.title,
        amountPaise: bill.amountPaise,
        dueDate: nextDue,
        recurrence: bill.recurrence,
        category: bill.category,
        notes: bill.notes,
        recurrenceAnchorDate: bill.recurrenceAnchorDate,
        recurrenceSeriesId: seriesId,
      );
      await transaction.insert(
        'bills',
        next.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final nextRows = await transaction.query(
        'bills',
        where: 'recurrence_series_id = ? AND due_date = ?',
        whereArgs: [seriesId, next.dueDate.toIso8601String()],
        limit: 1,
      );
      return nextRows.isEmpty ? next : BillReminder.fromMap(nextRows.first);
    });
  }

  static String _recurringBillId(String seriesId, DateTime dueDate) {
    final local = dueDate.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}';
    return 'bill-$seriesId-$date';
  }

  Future<BillReminder?> getById(String id) async {
    final row = await _byId('bills', id);
    return row == null ? null : BillReminder.fromMap(row);
  }

  Future<List<BillReminder>> getAll() async => (await (await db).query(
    'bills',
    orderBy: 'due_date ASC',
  )).map(BillReminder.fromMap).toList(growable: false);

  Future<List<BillReminder>> getUpcomingUnpaid({
    required DateTime from,
    required DateTime through,
  }) async {
    if (!through.isAfter(from)) {
      throw const AppException('End date must be after start date.');
    }
    final rows = await (await db).query(
      'bills',
      where: 'is_paid = 0 AND due_date >= ? AND due_date < ?',
      whereArgs: [
        from.toUtc().toIso8601String(),
        through.toUtc().toIso8601String(),
      ],
      orderBy: 'due_date ASC',
    );
    return rows.map(BillReminder.fromMap).toList(growable: false);
  }
}

class LocalSettingsRepository extends _Repository {
  const LocalSettingsRepository(super.database);

  Future<bool> getBillRemindersEnabled() async {
    final rows = await (await db).query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: ['bill_reminders_enabled'],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['setting_value'] == 'true';
  }

  Future<void> setBillRemindersEnabled(bool enabled) async {
    await (await db).insert('app_settings', {
      'setting_key': 'bill_reminders_enabled',
      'setting_value': enabled.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> getNotificationPermissionDenied() async =>
      _getBool('notification_permission_denied');

  Future<void> setNotificationPermissionDenied(bool denied) =>
      _setBool('notification_permission_denied', denied);

  Future<bool> getLocalSessionActive() => _getBool('local_session_active');

  Future<void> setLocalSessionActive(bool active) =>
      _setBool('local_session_active', active);

  Future<Map<String, String?>> getLocalProfile() async {
    final rows = await (await db).query(
      'app_settings',
      columns: ['setting_key', 'setting_value'],
      where: 'setting_key IN (?, ?)',
      whereArgs: ['local_profile_name', 'local_profile_email'],
    );
    return {
      for (final row in rows)
        (row['setting_key']! as String).replaceFirst('local_profile_', ''):
            row['setting_value'] as String,
    };
  }

  Future<void> saveLocalProfile({required String name, String? email}) async {
    final database = await db;
    await database.transaction((transaction) async {
      await transaction.insert('app_settings', {
        'setting_key': 'local_profile_name',
        'setting_value': name.trim(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (email == null || email.trim().isEmpty) {
        await transaction.delete(
          'app_settings',
          where: 'setting_key = ?',
          whereArgs: ['local_profile_email'],
        );
      } else {
        await transaction.insert('app_settings', {
          'setting_key': 'local_profile_email',
          'setting_value': email.trim(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<bool> _getBool(String key) async {
    final rows = await (await db).query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['setting_value'] == 'true';
  }

  Future<void> _setBool(String key, bool value) async {
    await (await db).insert('app_settings', {
      'setting_key': key,
      'setting_value': value.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
