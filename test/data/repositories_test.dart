import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/data/database/app_database.dart';
import 'package:finpilot_ai/data/repositories/finance_repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

void main() {
  late final db = createTestDatabase();
  late final transactions = TransactionRepository(db);
  late final accounts = AccountRepository(db);
  late final budgets = BudgetRepository(db);
  late final bills = BillRepository(db);

  setUpAll(() async {
    await accounts.create(
      FinanceAccount(
        id: 'acc-1',
        name: 'Daily',
        type: AccountType.bank,
        openingBalancePaise: 250000,
      ),
    );
    await transactions.create(
      FinanceTransaction(
        id: 'food-1',
        amountPaise: 1200,
        type: TransactionType.expense,
        category: 'Food',
        description: 'Lunch',
        transactionDate: DateTime.utc(2026, 10, 5),
        accountId: 'acc-1',
      ),
    );
    await transactions.create(
      FinanceTransaction(
        id: 'food-2',
        amountPaise: 800,
        type: TransactionType.expense,
        category: 'Food',
        description: 'Tea',
        transactionDate: DateTime.utc(2026, 10, 6),
        accountId: 'acc-1',
      ),
    );
    await transactions.create(
      FinanceTransaction(
        id: 'salary-1',
        amountPaise: 50000,
        type: TransactionType.income,
        category: 'Salary',
        description: 'Pay',
        transactionDate: DateTime.utc(2026, 10, 1),
        accountId: 'acc-1',
      ),
    );
    await budgets.create(
      FinanceBudget(
        id: 'budget-1',
        name: 'October food',
        category: 'Food',
        limitPaise: 30000,
        periodId: '2026-10',
        startDate: DateTime.utc(2026, 10, 1),
        endDate: DateTime.utc(2026, 11, 1),
      ),
    );
    await bills.create(
      BillReminder(
        id: 'bill-1',
        title: 'Internet',
        amountPaise: 2500,
        dueDate: DateTime.utc(2026, 10, 20),
      ),
    );
    await bills.create(
      BillReminder(
        id: 'bill-2',
        title: 'Insurance',
        amountPaise: 6000,
        dueDate: DateTime.utc(2026, 10, 21),
        isPaid: true,
      ),
    );
  });

  tearDownAll(() async => db.close());

  test(
    'transaction filtering combines date, category, type, and account',
    () async {
      final result = await transactions.getAll(
        startDate: DateTime.utc(2026, 10, 5),
        endDate: DateTime.utc(2026, 10, 6, 12),
        category: 'Food',
        type: TransactionType.expense,
        accountId: 'acc-1',
      );
      expect(result.map((item) => item.id), ['food-2', 'food-1']);
      expect(
        await transactions.getAll(type: TransactionType.income),
        hasLength(1),
      );
    },
  );

  test('transaction CRUD and update replaces the existing row', () async {
    final original = await transactions.getById('food-1');
    expect(original?.amountPaise, 1200);
    await transactions.update(
      FinanceTransaction(
        id: 'food-1',
        amountPaise: 1500,
        type: TransactionType.expense,
        category: 'Food',
        description: 'Lunch edited',
        transactionDate: DateTime.utc(2026, 10, 5),
        accountId: 'acc-1',
      ),
    );
    expect(await transactions.getById('food-1'), isNotNull);
    expect((await transactions.getById('food-1'))?.amountPaise, 1500);
    await transactions.delete('food-2');
    expect(await transactions.getById('food-2'), isNull);
    expect(
      await transactions.getAll(
        startDate: DateTime.utc(2026, 10, 1),
        endDate: DateTime.utc(2026, 11, 1),
      ),
      hasLength(2),
    );
  });

  test('account budget and bill repository CRUD and queries work', () async {
    expect((await accounts.getById('acc-1'))?.openingBalancePaise, 250000);
    expect(await accounts.getAll(), hasLength(1));
    expect(await budgets.getForMonth('2026-10'), hasLength(1));
    final upcoming = await bills.getUpcomingUnpaid(
      from: DateTime.utc(2026, 10, 1),
      through: DateTime.utc(2026, 11, 1),
    );
    expect(upcoming.map((item) => item.id), ['bill-1']);
    expect(await bills.getById('bill-2'), isNotNull);
    await bills.update(
      BillReminder(
        id: 'bill-1',
        title: 'Internet',
        amountPaise: 2500,
        dueDate: DateTime.utc(2026, 10, 20),
        isPaid: true,
      ),
    );
    expect(
      await bills.getUpcomingUnpaid(
        from: DateTime.utc(2026, 10, 1),
        through: DateTime.utc(2026, 11, 1),
      ),
      isEmpty,
    );
    await budgets.delete('budget-1');
    expect(await budgets.getById('budget-1'), isNull);
    await accounts.delete('acc-1');
    expect(await accounts.getById('acc-1'), isNull);
  });

  test(
    'data persists after closing and reopening the same database path',
    () async {
      sqfliteFfiInit();
      final path = p.join(
        await databaseFactoryFfi.getDatabasesPath(),
        'finpilot_persist_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final first = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: () async => path,
      );
      await AccountRepository(first).create(
        FinanceAccount(
          id: 'persist',
          name: 'Persist',
          type: AccountType.cash,
          openingBalancePaise: 1,
        ),
      );
      await first.close();

      final reopened = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: () async => path,
      );
      expect(
        (await AccountRepository(reopened).getById('persist'))
            ?.openingBalancePaise,
        1,
      );
      await reopened.close();
      await databaseFactoryFfi.deleteDatabase(path);
    },
  );
}
