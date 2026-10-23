import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finpilot_ai/data/database/app_database.dart';

int _databaseCounter = 0;

AppDatabase createTestDatabase() {
  sqfliteFfiInit();
  final databaseName =
      'finpilot_test_${DateTime.now().microsecondsSinceEpoch}_${_databaseCounter++}.db';
  return AppDatabase(
    factory: databaseFactoryFfi,
    databasePath: () async =>
        p.join(await databaseFactoryFfi.getDatabasesPath(), databaseName),
  );
}

AppDatabase createPersistentTestDatabase(String path) {
  sqfliteFfiInit();
  return AppDatabase(
    factory: databaseFactoryFfi,
    databasePath: () async => path,
  );
}

AppDatabase createTestDatabaseAt(String path) {
  sqfliteFfiInit();
  return AppDatabase(
    factory: databaseFactoryFfi,
    databasePath: () async => path,
  );
}
