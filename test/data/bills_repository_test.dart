import 'package:finpilot_ai/data/database/app_database.dart';
import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/data/repositories/finance_repositories.dart';
import 'package:finpilot_ai/features/transactions/controllers/finance_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../helpers/fake_bill_notification_service.dart';
import '../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late FakeBillNotificationService notificationService;
  late FinanceController controller;
  late BillRepository bills;

  setUp(() {
    database = createTestDatabase();
    notificationService = FakeBillNotificationService();
    controller = FinanceController(
      database: database,
      notificationService: notificationService,
    );
    bills = BillRepository(database);
  });

  tearDown(() async => database.close());

  test('bill create, edit, and delete retain full fields', () async {
    await controller.load();
    final bill = _bill(
      id: 'crud-bill',
      due: DateTime.utc(2027, 1, 31, 12),
      recurrence: BillRecurrence.monthly,
    );
    await controller.createBill(bill);
    expect(controller.bills.single.amountPaise, 12550);
    expect(notificationService.scheduled, isEmpty);

    final edited = BillReminder(
      id: bill.id,
      title: 'Electricity edited',
      amountPaise: 14000,
      dueDate: bill.dueDate,
      recurrence: bill.recurrence,
      category: 'Utilities',
      notes: 'New note',
      recurrenceAnchorDate: bill.recurrenceAnchorDate,
      recurrenceSeriesId: bill.recurrenceSeriesId,
      createdAt: bill.createdAt,
    );
    await controller.updateBill(edited);
    final persisted = await bills.getById(bill.id);
    expect(persisted?.title, 'Electricity edited');
    expect(persisted?.amountPaise, 14000);
    expect(persisted?.category, 'Utilities');
    expect(persisted?.notes, 'New note');
    expect(persisted?.recurrence, BillRecurrence.monthly);
    expect(persisted?.recurrenceAnchorDate, bill.recurrenceAnchorDate);
    await controller.deleteBill(bill.id);
    expect(await bills.getById(bill.id), isNull);
    expect(controller.bills, isEmpty);
  });

  test('bill survives closing and reopening its local database', () async {
    ffi.sqfliteFfiInit();
    final path = p.join(
      await ffi.databaseFactoryFfi.getDatabasesPath(),
      'finpilot_bill_persist_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final first = createPersistentTestDatabase(path);
    await BillRepository(first).create(
      _bill(
        id: 'persisted-bill',
        due: DateTime.utc(2027, 1, 31, 12),
        recurrence: BillRecurrence.yearly,
      ),
    );
    await first.close();
    final reopened = createPersistentTestDatabase(path);
    final persisted = await BillRepository(reopened).getById('persisted-bill');
    expect(persisted?.amountPaise, 12550);
    expect(persisted?.recurrence, BillRecurrence.yearly);
    expect(persisted?.recurrenceAnchorDate, DateTime.utc(2027, 1, 31, 12));
    await reopened.close();
    await ffi.databaseFactoryFfi.deleteDatabase(path);
  });

  test(
    'unpaid bills filter into upcoming and overdue; paid stays visible',
    () async {
      final now = DateTime.now();
      await bills.create(
        _bill(id: 'old', due: now.subtract(const Duration(days: 3))),
      );
      await bills.create(_bill(id: 'today', due: now));
      await bills.create(
        _bill(id: 'future', due: now.add(const Duration(days: 2))),
      );
      await bills.create(_bill(id: 'paid', due: now, isPaid: true));
      await controller.load();
      expect(controller.overdueBills.map((bill) => bill.id), ['old']);
      expect(controller.upcomingBills.map((bill) => bill.id), [
        'today',
        'future',
      ]);
      expect(controller.paidBills.map((bill) => bill.id), ['paid']);
    },
  );

  test(
    'marking monthly recurring bill paid advances once without duplicates',
    () async {
      final anchor = DateTime.utc(2027, 1, 31, 12);
      await controller.load();
      await controller.createBill(
        _bill(
          id: 'monthly-source',
          due: anchor,
          recurrence: BillRecurrence.monthly,
        ),
      );
      final next = await controller.markBillPaid('monthly-source');
      expect(next?.dueDate, DateTime.utc(2027, 2, 28, 12));
      expect(next?.recurrenceAnchorDate, anchor);
      expect(next?.recurrenceSeriesId, 'monthly-source');
      expect((await bills.getById('monthly-source'))?.isPaid, isTrue);

      expect(await controller.markBillPaid('monthly-source'), isNull);
      expect(await bills.getAll(), hasLength(2));
      expect((await bills.getById(next!.id))?.isPaid, isFalse);
    },
  );

  test(
    'reminder permission, schedule, update, cancellation, and denial',
    () async {
      final due = DateTime.now().add(const Duration(days: 10));
      await controller.initializeDatabase();
      expect(await controller.setBillRemindersEnabled(true), isTrue);
      expect(notificationService.permissionRequests, 1);
      expect(controller.billRemindersEnabled, isTrue);
      final resumedNotifications = FakeBillNotificationService();
      final resumedController = FinanceController(
        database: database,
        notificationService: resumedNotifications,
      );
      await resumedController.initializeDatabase();
      expect(resumedController.billRemindersEnabled, isTrue);
      expect(resumedNotifications.initializationCalled, isTrue);

      final bill = _bill(id: 'reminded', due: due);
      await controller.createBill(bill);
      expect(notificationService.scheduled, ['reminded']);
      final edited = BillReminder(
        id: bill.id,
        title: 'Updated reminder',
        amountPaise: bill.amountPaise,
        dueDate: due.add(const Duration(days: 1)),
        recurrence: bill.recurrence,
        recurrenceAnchorDate: bill.recurrenceAnchorDate,
        recurrenceSeriesId: bill.recurrenceSeriesId,
      );
      await controller.updateBill(edited);
      expect(notificationService.cancelled, ['reminded']);
      expect(notificationService.scheduled, ['reminded', 'reminded']);
      await controller.deleteBill(bill.id);
      expect(notificationService.cancelled, ['reminded', 'reminded']);
      await controller.setBillRemindersEnabled(false);
      expect(notificationService.cancelAllCalls, 1);
      expect(controller.billRemindersEnabled, isFalse);

      final deniedService = FakeBillNotificationService(
        permissionGranted: false,
      );
      final deniedController = FinanceController(
        database: database,
        notificationService: deniedService,
      );
      await deniedController.initializeDatabase();
      expect(await deniedController.setBillRemindersEnabled(true), isFalse);
      expect(deniedController.billRemindersEnabled, isFalse);
      expect(deniedController.notificationError, contains('permission'));
    },
  );

  test(
    'unsupported platform does not pretend to schedule notifications',
    () async {
      notificationService.supported = false;
      await controller.initializeDatabase();
      expect(await controller.setBillRemindersEnabled(true), isFalse);
      expect(controller.notificationError, contains('Android and iOS only'));
      expect(notificationService.permissionRequests, 0);
    },
  );

  test(
    'reports partial reminder scheduling failure without hiding it',
    () async {
      await controller.load();
      await bills.create(
        _bill(
          id: 'schedule-fails',
          due: DateTime.now().add(const Duration(days: 5)),
        ),
      );
      await bills.create(
        _bill(
          id: 'schedule-succeeds',
          due: DateTime.now().add(const Duration(days: 6)),
        ),
      );
      notificationService.scheduleFailureFor = 'schedule-fails';
      await controller.load();

      expect(await controller.setBillRemindersEnabled(true), isFalse);
      expect(controller.billRemindersEnabled, isTrue);
      expect(controller.notificationError, contains('Could not schedule'));
      expect(notificationService.scheduled, ['schedule-succeeds']);
    },
  );

  test('version one bill rows migrate with a recurrence anchor', () async {
    ffi.sqfliteFfiInit();
    final path = p.join(
      await ffi.databaseFactoryFfi.getDatabasesPath(),
      'finpilot_bill_migration_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final legacy = await ffi.databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE bills (
              id TEXT PRIMARY KEY NOT NULL,
              title TEXT NOT NULL,
              amount_paise INTEGER NOT NULL,
              due_date TEXT NOT NULL,
              recurrence TEXT NOT NULL,
              is_paid INTEGER NOT NULL DEFAULT 0,
              category TEXT,
              notes TEXT,
              created_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await legacy.insert('bills', {
      'id': 'legacy-monthly',
      'title': 'Legacy bill',
      'amount_paise': 1200,
      'due_date': '2027-01-31T12:00:00.000Z',
      'recurrence': 'monthly',
      'is_paid': 0,
      'created_at': '2026-10-01T00:00:00.000Z',
    });
    await legacy.close();

    final upgraded = AppDatabase(
      factory: ffi.databaseFactoryFfi,
      databasePath: () async => path,
    );
    final migrated = await BillRepository(upgraded).getById('legacy-monthly');
    expect(migrated?.recurrenceAnchorDate, DateTime.utc(2027, 1, 31, 12));
    expect(migrated?.recurrenceSeriesId, 'legacy-monthly');
    await upgraded.close();
    await ffi.databaseFactoryFfi.deleteDatabase(path);
  });
}

BillReminder _bill({
  required String id,
  required DateTime due,
  BillRecurrence recurrence = BillRecurrence.none,
  bool isPaid = false,
}) => BillReminder(
  id: id,
  title: 'Electricity',
  amountPaise: 12550,
  dueDate: due,
  recurrence: recurrence,
  isPaid: isPaid,
  category: 'Utilities',
  notes: 'Monthly utility bill',
);
