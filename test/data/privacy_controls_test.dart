import 'dart:convert';

import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/data/repositories/finance_repositories.dart';
import 'package:finpilot_ai/features/settings/domain/finance_export.dart';
import 'package:finpilot_ai/features/transactions/controllers/finance_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_bill_notification_service.dart';
import '../helpers/test_database.dart';

void main() {
  test(
    'restored local session can sign out without deleting finance records',
    () async {
      sqfliteFfiInit();
      final path = p.join(
        await databaseFactoryFfi.getDatabasesPath(),
        'finpilot_session_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final database = createPersistentTestDatabase(path);
      final notifications = FakeBillNotificationService();
      final controller = FinanceController(
        database: database,
        notificationService: notifications,
      );
      await controller.initializeDatabase();
      await controller.saveLocalProfile(
        name: 'Pilot',
        email: 'pilot@example.com',
      );
      await AccountRepository(database).create(
        FinanceAccount(
          id: 'session-account',
          name: 'Cash',
          type: AccountType.cash,
          openingBalancePaise: 12000,
        ),
      );
      await database.close();
      final restoredDatabase = createPersistentTestDatabase(path);
      final restored = FinanceController(
        database: restoredDatabase,
        notificationService: FakeBillNotificationService(),
      );
      await restored.initializeDatabase();
      expect(restored.localSessionActive, isTrue);
      await restored.signOut();
      expect(restored.localSessionActive, isFalse);
      expect(
        await AccountRepository(restoredDatabase).getById('session-account'),
        isNotNull,
      );
      await restoredDatabase.close();
      await databaseFactoryFfi.deleteDatabase(path);
    },
  );

  test(
    'deletion removes linked and recurring finance rows and preferences',
    () async {
      final database = createTestDatabase();
      final notifications = FakeBillNotificationService();
      final controller = FinanceController(
        database: database,
        notificationService: notifications,
      );
      await controller.initializeDatabase();
      final accounts = AccountRepository(database);
      final transactions = TransactionRepository(database);
      final budgets = BudgetRepository(database);
      final bills = BillRepository(database);
      await accounts.create(
        FinanceAccount(
          id: 'a',
          name: 'Main',
          type: AccountType.bank,
          openingBalancePaise: 5000,
        ),
      );
      await transactions.create(
        FinanceTransaction(
          id: 't',
          amountPaise: 100,
          type: TransactionType.expense,
          category: 'Food',
          description: 'Snack',
          transactionDate: DateTime.utc(2026, 1, 1),
          accountId: 'a',
        ),
      );
      await budgets.create(
        FinanceBudget(
          id: 'b',
          name: 'Monthly',
          limitPaise: 5000,
          periodId: '2026-01',
          startDate: DateTime.utc(2026, 1, 1),
          endDate: DateTime.utc(2026, 2, 1),
        ),
      );
      await bills.create(
        BillReminder(
          id: 'bill',
          title: 'Rent',
          amountPaise: 250000,
          dueDate: DateTime.utc(2026, 1, 5),
          recurrence: BillRecurrence.monthly,
        ),
      );
      await controller.saveLocalProfile(name: 'Pilot');
      await controller.setBillRemindersEnabled(true);

      final export = jsonDecode(
        FinanceExport.encode(await controller.buildFinancialExport()),
      ) as Map<String, dynamic>;
      expect(export['accounts'], hasLength(1));
      expect(export['transactions'].single['amount_paise'], 100);
      expect(export['budgets'].single['limit_paise'], 5000);
      expect(export['bills'].single['amount_paise'], 250000);
      expect(export.containsKey('app_settings'), isFalse);

      await controller.deleteAllLocalData();

      expect(await accounts.getAll(), isEmpty);
      expect(await transactions.getAll(), isEmpty);
      expect(await budgets.getAll(), isEmpty);
      expect(await bills.getAll(), isEmpty);
      expect(
        await LocalSettingsRepository(database).getLocalSessionActive(),
        isFalse,
      );
      expect(
        await LocalSettingsRepository(database).getBillRemindersEnabled(),
        isFalse,
      );
      expect(notifications.cancelAllCalls, greaterThanOrEqualTo(1));
      await database.close();
    },
  );

  test(
    'denied notification permission is not requested again automatically',
    () async {
      final database = createTestDatabase();
      final notifications = FakeBillNotificationService(
        permissionGranted: false,
      );
      final controller = FinanceController(
        database: database,
        notificationService: notifications,
      );
      await controller.initializeDatabase();

      expect(await controller.setBillRemindersEnabled(true), isFalse);
      expect(await controller.setBillRemindersEnabled(true), isFalse);
      expect(notifications.permissionRequests, 1);
      expect(controller.notificationPermissionDenied, isTrue);
      expect(await controller.retryBillNotificationPermission(), isFalse);
      expect(notifications.permissionRequests, 2);
      await database.close();
    },
  );

  test('startup error text does not expose implementation details', () {
    final controller = FinanceController();
    controller.setStartupError(StateError('sensitive database path'));
    expect(controller.error, isNot(contains('sensitive database path')));
  });
}
