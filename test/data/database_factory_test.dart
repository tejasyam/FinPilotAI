import 'dart:io';

import 'package:finpilot_ai/data/database/app_database.dart';
import 'package:finpilot_ai/data/database/database_factory_provider.dart';
import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/data/repositories/finance_repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  test(
    'selects and initializes the factory for the current native platform',
    () async {
      final factory = await initializePlatformDatabaseFactory();
      if (Platform.isWindows || Platform.isLinux) {
        expect(identical(factory, ffi.databaseFactoryFfi), isTrue);
      } else {
        expect(identical(factory, sqflite.databaseFactory), isTrue);
      }
    },
  );

  test(
    'default platform factory persists records after database reopen',
    () async {
      final factory = await initializePlatformDatabaseFactory();
      final path = p.join(
        await factory.getDatabasesPath(),
        'finpilot_platform_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final first = AppDatabase(databasePath: () async => path);
      await AccountRepository(first).create(
        FinanceAccount(
          id: 'platform-account',
          name: 'Test cash',
          type: AccountType.cash,
          openingBalancePaise: 12345,
        ),
      );
      await first.close();

      final reopened = AppDatabase(databasePath: () async => path);
      expect(
        (await AccountRepository(reopened).getById('platform-account'))
            ?.openingBalancePaise,
        12345,
      );
      await reopened.close();
      await factory.deleteDatabase(path);
    },
  );
}
