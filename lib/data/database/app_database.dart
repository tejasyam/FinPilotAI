import 'package:sqflite/sqflite.dart';

import 'database_factory_provider.dart';
import 'database_migrations.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, this._databasePath})
    : _factoryOverride = factory;

  final DatabaseFactory? _factoryOverride;
  final Future<String> Function()? _databasePath;
  Database? _database;
  Future<Database>? _opening;
  Future<DatabaseFactory>? _factory;

  Future<void> initialize() async {
    await database;
  }

  Future<Database> get database async {
    final openDatabase = _database;
    if (openDatabase != null && openDatabase.isOpen) return openDatabase;
    return _opening ??= _open();
  }

  Future<String> _resolvePath() async {
    if (_databasePath != null) return _databasePath();
    await (_factory ??= initializePlatformDatabaseFactory());
    return platformDatabasePath();
  }

  Future<Database> _open() async {
    try {
      final path = await _resolvePath();
      final factory = await (_factory ??= _factoryOverride != null
          ? Future.value(_factoryOverride)
          : initializePlatformDatabaseFactory());
      final opened = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.version,
          onCreate: DatabaseMigrations.onCreate,
          onUpgrade: DatabaseMigrations.onUpgrade,
          onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      _database = opened;
      return opened;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    _opening = null;
    if (db != null && db.isOpen) await db.close();
  }
}
