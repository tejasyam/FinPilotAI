import 'package:flutter/foundation.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/finance_models.dart';
import '../../../data/repositories/finance_repositories.dart';
import '../../../domain/finance_calculator.dart';
import '../../bills/services/bill_notification_service.dart';

class FinanceController extends ChangeNotifier {
  FinanceController({
    AppDatabase? database,
    BillNotificationService? notificationService,
  }) : _database = database ?? AppDatabase(),
       _notificationService =
           notificationService ?? PlatformBillNotificationService() {
    _transactions = TransactionRepository(_database);
    _accounts = AccountRepository(_database);
    _budgets = BudgetRepository(_database);
    _bills = BillRepository(_database);
    _settings = LocalSettingsRepository(_database);
  }

  final AppDatabase _database;
  late final TransactionRepository _transactions;
  late final AccountRepository _accounts;
  late final BudgetRepository _budgets;
  late final BillRepository _bills;
  late final LocalSettingsRepository _settings;
  final BillNotificationService _notificationService;

  bool isLoading = true;
  String? error;
  List<FinanceTransaction> transactions = [];
  List<FinanceAccount> accounts = [];
  List<FinanceBudget> budgets = [];
  List<BillReminder> bills = [];
  bool billRemindersEnabled = false;
  String? notificationError;

  DateTime get now => DateTime.now();
  DateTime get monthStart =>
      FinanceCalculator.monthStartUtc(now.year, now.month);
  DateTime get nextMonthStart =>
      FinanceCalculator.nextMonthStartUtc(now.year, now.month);
  String get currentPeriodId =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  int get currentBalancePaise => FinanceCalculator.currentBalancePaise(
    accounts: accounts,
    transactions: transactions,
  );
  PeriodTotals get currentMonthTotals => FinanceCalculator.totalsForPeriod(
    transactions,
    start: monthStart,
    end: nextMonthStart,
  );
  Map<String, int> get currentMonthCategoryTotals =>
      FinanceCalculator.expensesByCategory(
        transactions,
        start: monthStart,
        end: nextMonthStart,
      );
  List<FinanceTransaction> get recentTransactions =>
      transactions.take(5).toList(growable: false);
  int get monthlyBudgetPaise => budgets
      .where((budget) => budget.category == null)
      .fold<int>(0, (sum, budget) => sum + budget.limitPaise);
  List<BillReminder> get upcomingBills => bills
      .where((bill) => !bill.isPaid && !_isOverdue(bill, now))
      .toList(growable: false);
  List<BillReminder> get overdueBills => bills
      .where((bill) => !bill.isPaid && _isOverdue(bill, now))
      .toList(growable: false);
  List<BillReminder> get paidBills =>
      bills.where((bill) => bill.isPaid).toList(growable: false);

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      transactions = await _transactions.getAll();
      accounts = await _accounts.getAll();
      budgets = await _budgets.getForMonth(currentPeriodId);
      bills = await _bills.getAll();
    } catch (exception) {
      error = 'Could not load local finance data: $exception';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initializeDatabase() async {
    await _database.initialize();
    try {
      await _notificationService.initialize();
    } catch (exception) {
      notificationError = 'Could not initialize local reminders: $exception';
    }
    billRemindersEnabled = await _settings.getBillRemindersEnabled();
    if (billRemindersEnabled) {
      for (final bill in await _bills.getAll()) {
        if (!bill.isPaid) await _scheduleReminder(bill);
      }
    }
  }

  void setStartupError(Object exception) {
    error = 'Could not initialize local finance storage: $exception';
    isLoading = false;
    notifyListeners();
  }

  Future<void> createTransaction(FinanceTransaction value) async {
    await _transactions.create(value);
    await load();
  }

  Future<void> updateTransaction(FinanceTransaction value) async {
    await _transactions.update(value);
    await load();
  }

  Future<void> deleteTransaction(String id) async {
    await _transactions.delete(id);
    await load();
  }

  Future<void> createAccount(FinanceAccount value) async {
    await _accounts.create(value);
    await load();
  }

  Future<List<FinanceBudget>> budgetsForMonth(DateTime month) => _budgets
      .getForMonth('${month.year}-${month.month.toString().padLeft(2, '0')}');

  Future<void> createBudget(FinanceBudget value) async {
    await _budgets.create(value);
    await load();
  }

  Future<void> updateBudget(FinanceBudget value) async {
    await _budgets.update(value);
    await load();
  }

  Future<void> deleteBudget(String id) async {
    await _budgets.delete(id);
    await load();
  }

  Future<void> createBill(BillReminder bill) async {
    await _bills.create(bill);
    await _scheduleReminder(bill);
    await load();
  }

  Future<void> updateBill(BillReminder bill) async {
    final previous = await _bills.getById(bill.id);
    await _bills.update(bill);
    if (previous != null) await _cancelReminder(previous);
    await _scheduleReminder(bill);
    await load();
  }

  Future<void> deleteBill(String id) async {
    final bill = await _bills.getById(id);
    await _bills.delete(id);
    if (bill != null) await _cancelReminder(bill);
    await load();
  }

  Future<BillReminder?> markBillPaid(String id) async {
    final bill = await _bills.getById(id);
    final next = await _bills.markPaidAndAdvance(id);
    if (bill != null) await _cancelReminder(bill);
    if (next != null) await _scheduleReminder(next);
    await load();
    return next;
  }

  Future<bool> setBillRemindersEnabled(bool enabled) async {
    notificationError = null;
    if (!enabled) {
      await _settings.setBillRemindersEnabled(false);
      billRemindersEnabled = false;
      try {
        await _notificationService.cancelAll();
      } catch (exception) {
        notificationError = 'Could not cancel local reminders: $exception';
      }
      notifyListeners();
      return true;
    }
    if (!_notificationService.supported) {
      notificationError = 'Scheduled reminders are available on Android and iOS only. Browser previews do not support scheduled bill reminders.';
      notifyListeners();
      return false;
    }
    try {
      final granted = await _notificationService.requestPermission();
      if (!granted) {
        notificationError = 'Notification permission was not granted. Enable it in device settings to use bill reminders.';
        notifyListeners();
        return false;
      }
      await _settings.setBillRemindersEnabled(true);
      billRemindersEnabled = true;
      for (final bill in bills) {
        if (!bill.isPaid) await _scheduleReminder(bill);
      }
      notifyListeners();
      return true;
    } catch (exception) {
      notificationError = 'Could not enable local reminders: $exception';
      notifyListeners();
      return false;
    }
  }

  Future<void> _scheduleReminder(BillReminder bill) async {
    if (!billRemindersEnabled || bill.isPaid) return;
    try {
      await _notificationService.schedule(bill);
      notificationError = null;
    } catch (exception) {
      notificationError = 'Could not schedule reminder: $exception';
    }
  }

  Future<void> _cancelReminder(BillReminder bill) async {
    try {
      await _notificationService.cancel(bill);
    } catch (exception) {
      notificationError = 'Could not update reminder: $exception';
    }
  }

  FinanceTransaction? transactionById(String id) {
    for (final transaction in transactions) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }
}

bool _isOverdue(BillReminder bill, DateTime reference) {
  final due = bill.dueDate.toLocal();
  final today = reference.toLocal();
  final dueDay = DateTime(due.year, due.month, due.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  return dueDay.isBefore(todayDay);
}
