import 'dart:convert';

import '../../../data/models/finance_models.dart';

/// Builds a versioned JSON snapshot without profile details or app settings.
/// Monetary values remain integer paise so the export is lossless.
abstract final class FinanceExport {
  static Map<String, Object?> build({
    required List<FinanceAccount> accounts,
    required List<FinanceTransaction> transactions,
    required List<FinanceBudget> budgets,
    required List<BillReminder> bills,
  }) => {
    'format': 'finpilotai-finance-export',
    'version': 1,
    'accounts': [
      for (final value in accounts)
        {
          'id': value.id,
          'name': value.name,
          'type': value.type.name,
          'opening_balance_paise': value.openingBalancePaise,
          'currency_code': value.currencyCode,
        },
    ],
    'transactions': [
      for (final value in transactions)
        {
          'id': value.id,
          'amount_paise': value.amountPaise,
          'type': value.type.name,
          'category': value.category,
          'description': value.description,
          'transaction_date': value.transactionDate.toIso8601String(),
          'account_id': value.accountId,
        },
    ],
    'budgets': [
      for (final value in budgets)
        {
          'id': value.id,
          'name': value.name,
          'category': value.category,
          'limit_paise': value.limitPaise,
          'period_id': value.periodId,
          'start_date': value.startDate.toIso8601String(),
          'end_date': value.endDate.toIso8601String(),
        },
    ],
    'bills': [
      for (final value in bills)
        {
          'id': value.id,
          'title': value.title,
          'amount_paise': value.amountPaise,
          'due_date': value.dueDate.toIso8601String(),
          'recurrence_anchor_date': value.recurrenceAnchorDate
              .toIso8601String(),
          'recurrence_series_id': value.recurrenceSeriesId,
          'recurrence': value.recurrence.name,
          'is_paid': value.isPaid,
          'category': value.category,
          'notes': value.notes,
        },
    ],
  };

  static String encode(Map<String, Object?> data) =>
      const JsonEncoder.withIndent('  ').convert(data);
}
