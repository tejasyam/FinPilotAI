import '../../core/errors/app_exception.dart';

enum TransactionType { income, expense }

enum AccountType { cash, bank, credit, other }

enum BillRecurrence { none, weekly, monthly, yearly }

DateTime _readDate(Object? value, String field) {
  if (value is! String) {
    throw AppException('Invalid $field value in database.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw AppException('Invalid $field value in database.');
  return parsed.toUtc();
}

int _positiveAmount(int value) {
  if (value <= 0) {
    throw const AppException('Amount must be greater than zero paise.');
  }
  return value;
}

String _requiredText(String value, String field) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw AppException('$field is required.');
  }
  return trimmed;
}

class FinanceTransaction {
  FinanceTransaction({
    required this.id,
    required this.amountPaise,
    required this.type,
    required this.category,
    required this.description,
    required DateTime transactionDate,
    this.accountId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : transactionDate = transactionDate.toUtc(),
       createdAt = (createdAt ?? DateTime.now()).toUtc(),
       updatedAt = (updatedAt ?? DateTime.now()).toUtc() {
    _requiredText(id, 'ID');
    _positiveAmount(amountPaise);
    _requiredText(category, 'Category');
    _requiredText(description, 'Description');
  }

  final String id;
  final int amountPaise;
  final TransactionType type;
  final String category;
  final String description;
  final DateTime transactionDate;
  final String? accountId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'amount_paise': amountPaise,
    'type': type.name,
    'category': category,
    'description': description,
    'transaction_date': transactionDate.toIso8601String(),
    'account_id': accountId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory FinanceTransaction.fromMap(Map<String, Object?> map) {
    final type = TransactionType.values.where(
      (item) => item.name == map['type'],
    );
    if (type.isEmpty) {
      throw const AppException('Unknown transaction type in database.');
    }
    return FinanceTransaction(
      id: map['id']! as String,
      amountPaise: map['amount_paise']! as int,
      type: type.first,
      category: map['category']! as String,
      description: map['description']! as String,
      transactionDate: _readDate(map['transaction_date'], 'transaction date'),
      accountId: map['account_id'] as String?,
      createdAt: _readDate(map['created_at'], 'creation timestamp'),
      updatedAt: _readDate(map['updated_at'], 'update timestamp'),
    );
  }
}

class FinanceAccount {
  FinanceAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalancePaise,
    this.currencyCode = 'INR',
    DateTime? createdAt,
  }) : createdAt = (createdAt ?? DateTime.now()).toUtc() {
    _requiredText(id, 'ID');
    _requiredText(name, 'Account name');
    if (openingBalancePaise < 0) {
      throw const AppException('Opening balance cannot be negative.');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode)) {
      throw const AppException(
        'Currency code must be three uppercase letters.',
      );
    }
  }

  final String id;
  final String name;
  final AccountType type;
  final int openingBalancePaise;
  final String currencyCode;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'opening_balance_paise': openingBalancePaise,
    'currency_code': currencyCode,
    'created_at': createdAt.toIso8601String(),
  };

  factory FinanceAccount.fromMap(Map<String, Object?> map) {
    final type = AccountType.values.where((item) => item.name == map['type']);
    if (type.isEmpty) {
      throw const AppException('Unknown account type in database.');
    }
    return FinanceAccount(
      id: map['id']! as String,
      name: map['name']! as String,
      type: type.first,
      openingBalancePaise: map['opening_balance_paise']! as int,
      currencyCode: map['currency_code']! as String,
      createdAt: _readDate(map['created_at'], 'creation timestamp'),
    );
  }
}

class FinanceBudget {
  FinanceBudget({
    required this.id,
    required this.name,
    required this.limitPaise,
    required this.periodId,
    required DateTime startDate,
    required DateTime endDate,
    this.category,
  }) : startDate = startDate.toUtc(),
       endDate = endDate.toUtc() {
    _requiredText(id, 'ID');
    _requiredText(name, 'Budget name');
    _requiredText(periodId, 'Period');
    _positiveAmount(limitPaise);
    if (!this.endDate.isAfter(this.startDate)) {
      throw const AppException('Budget end date must be after its start date.');
    }
  }

  final String id;
  final String name;
  final String? category;
  final int limitPaise;
  final String periodId;
  final DateTime startDate;
  final DateTime endDate;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'limit_paise': limitPaise,
    'period_id': periodId,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
  };

  factory FinanceBudget.fromMap(Map<String, Object?> map) => FinanceBudget(
    id: map['id']! as String,
    name: map['name']! as String,
    category: map['category'] as String?,
    limitPaise: map['limit_paise']! as int,
    periodId: map['period_id']! as String,
    startDate: _readDate(map['start_date'], 'budget start date'),
    endDate: _readDate(map['end_date'], 'budget end date'),
  );
}

class BillReminder {
  BillReminder({
    required this.id,
    required this.title,
    required this.amountPaise,
    required DateTime dueDate,
    this.recurrence = BillRecurrence.none,
    this.isPaid = false,
    this.category,
    this.notes,
    DateTime? recurrenceAnchorDate,
    String? recurrenceSeriesId,
    DateTime? createdAt,
  }) : dueDate = dueDate.toUtc(),
       recurrenceAnchorDate = (recurrenceAnchorDate ?? dueDate).toUtc(),
       recurrenceSeriesId = recurrence == BillRecurrence.none
           ? null
           : (recurrenceSeriesId ?? id),
       createdAt = (createdAt ?? DateTime.now()).toUtc() {
    _requiredText(id, 'ID');
    _requiredText(title, 'Title');
    _positiveAmount(amountPaise);
  }

  final String id;
  final String title;
  final int amountPaise;
  final DateTime dueDate;
  final DateTime recurrenceAnchorDate;
  final String? recurrenceSeriesId;
  final BillRecurrence recurrence;
  final bool isPaid;
  final String? category;
  final String? notes;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'amount_paise': amountPaise,
    'due_date': dueDate.toIso8601String(),
    'recurrence_anchor_date': recurrenceAnchorDate.toIso8601String(),
    'recurrence_series_id': recurrenceSeriesId,
    'recurrence': recurrence.name,
    'is_paid': isPaid ? 1 : 0,
    'category': category,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };

  factory BillReminder.fromMap(Map<String, Object?> map) {
    final recurrence = BillRecurrence.values.where(
      (item) => item.name == map['recurrence'],
    );
    if (recurrence.isEmpty) {
      throw const AppException('Unknown bill recurrence in database.');
    }
    return BillReminder(
      id: map['id']! as String,
      title: map['title']! as String,
      amountPaise: map['amount_paise']! as int,
      dueDate: _readDate(map['due_date'], 'bill due date'),
      recurrenceAnchorDate: map['recurrence_anchor_date'] == null
          ? null
          : _readDate(map['recurrence_anchor_date'], 'bill recurrence anchor'),
      recurrenceSeriesId: map['recurrence_series_id'] as String?,
      recurrence: recurrence.first,
      isPaid: map['is_paid'] == 1,
      category: map['category'] as String?,
      notes: map['notes'] as String?,
      createdAt: _readDate(map['created_at'], 'creation timestamp'),
    );
  }
}
