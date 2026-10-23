import 'package:finpilot_ai/core/errors/app_exception.dart';
import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction round trips typed fields and UTC dates', () {
    final original = FinanceTransaction(
      id: 'tx-1',
      amountPaise: 12550,
      type: TransactionType.expense,
      category: 'Food',
      description: 'Lunch',
      transactionDate: DateTime.utc(2026, 10, 24, 0, 5),
      accountId: 'acct-1',
      createdAt: DateTime.utc(2026, 10, 24),
      updatedAt: DateTime.utc(2026, 10, 24),
    );
    final decoded = FinanceTransaction.fromMap(original.toMap());
    expect(decoded.type, TransactionType.expense);
    expect(decoded.amountPaise, 12550);
    expect(decoded.transactionDate, DateTime.utc(2026, 10, 24, 0, 5));
    expect(decoded.accountId, 'acct-1');
  });

  test('all model types serialize and deserialize', () {
    final account = FinanceAccount(
      id: 'a',
      name: 'Everyday',
      type: AccountType.bank,
      openingBalancePaise: 1000,
    );
    expect(FinanceAccount.fromMap(account.toMap()).currencyCode, 'INR');
    final budget = FinanceBudget(
      id: 'b',
      name: 'October',
      limitPaise: 20000,
      periodId: '2026-10',
      startDate: DateTime.utc(2026, 10),
      endDate: DateTime.utc(2026, 11),
    );
    expect(FinanceBudget.fromMap(budget.toMap()).periodId, '2026-10');
    final bill = BillReminder(
      id: 'bill',
      title: 'Rent',
      amountPaise: 100000,
      dueDate: DateTime.utc(2026, 10, 30),
      recurrence: BillRecurrence.monthly,
      isPaid: true,
    );
    expect(BillReminder.fromMap(bill.toMap()).isPaid, isTrue);
    expect(
      BillReminder.fromMap(bill.toMap()).recurrence,
      BillRecurrence.monthly,
    );
  });

  test('transaction amount must be positive paise', () {
    expect(
      () => FinanceTransaction(
        id: 'bad',
        amountPaise: 0,
        type: TransactionType.income,
        category: 'Salary',
        description: 'Pay',
        transactionDate: DateTime.now(),
      ),
      throwsA(isA<AppException>()),
    );
  });
}
