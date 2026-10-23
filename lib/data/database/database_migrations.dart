import 'package:sqflite/sqflite.dart';

abstract final class DatabaseMigrations {
  static const version = 2;

  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('cash', 'bank', 'credit', 'other')),
        opening_balance_paise INTEGER NOT NULL CHECK (opening_balance_paise >= 0),
        currency_code TEXT NOT NULL DEFAULT 'INR' CHECK (length(currency_code) = 3),
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY NOT NULL,
        amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
        type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        transaction_date TEXT NOT NULL,
        account_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX transactions_date_idx ON transactions(transaction_date)',
    );
    await db.execute(
      'CREATE INDEX transactions_category_idx ON transactions(category)',
    );
    await db.execute(
      'CREATE INDEX transactions_type_idx ON transactions(type)',
    );
    await db.execute(
      'CREATE INDEX transactions_account_idx ON transactions(account_id)',
    );
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        category TEXT,
        limit_paise INTEGER NOT NULL CHECK (limit_paise > 0),
        period_id TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        UNIQUE(period_id, category)
      )
    ''');
    await db.execute('CREATE INDEX budgets_period_idx ON budgets(period_id)');
    await db.execute('''
      CREATE TABLE bills (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
        due_date TEXT NOT NULL,
        recurrence_anchor_date TEXT NOT NULL,
        recurrence_series_id TEXT,
        recurrence TEXT NOT NULL CHECK (recurrence IN ('none', 'weekly', 'monthly', 'yearly')),
        is_paid INTEGER NOT NULL DEFAULT 0 CHECK (is_paid IN (0, 1)),
        category TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX bills_due_status_idx ON bills(is_paid, due_date)',
    );
    await db.execute('''
      CREATE UNIQUE INDEX bills_series_due_unique
      ON bills(recurrence_series_id, due_date)
      WHERE recurrence_series_id IS NOT NULL
    ''');
    await db.execute(
      "CREATE TABLE app_settings (setting_key TEXT PRIMARY KEY NOT NULL, setting_value TEXT NOT NULL)",
    );
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE bills ADD COLUMN recurrence_anchor_date TEXT',
      );
      await db.execute(
        'ALTER TABLE bills ADD COLUMN recurrence_series_id TEXT',
      );
      await db.execute('''
        UPDATE bills SET recurrence_anchor_date = due_date,
          recurrence_series_id = CASE WHEN recurrence = 'none' THEN NULL ELSE id END
      ''');
      await db.execute('''
        CREATE UNIQUE INDEX bills_series_due_unique
        ON bills(recurrence_series_id, due_date)
        WHERE recurrence_series_id IS NOT NULL
      ''');
      await db.execute(
        'CREATE TABLE app_settings (setting_key TEXT PRIMARY KEY NOT NULL, setting_value TEXT NOT NULL)',
      );
    }
  }
}
