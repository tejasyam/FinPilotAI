import '../../../../core/utils/money_parser.dart';

/// Best-effort receipt field extraction. All suggestions remain editable.
class ReceiptTextResult {
  const ReceiptTextResult({
    required this.rawText,
    this.merchant,
    this.date,
    this.amountRupees,
  });

  final String rawText;
  final String? merchant;
  final DateTime? date;
  final String? amountRupees;

  bool get hasAnySuggestedField =>
      merchant != null || date != null || amountRupees != null;
}

abstract final class ReceiptTextParser {
  static ReceiptTextResult parse(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return ReceiptTextResult(
      rawText: text,
      merchant: _merchant(lines),
      date: _date(lines),
      amountRupees: _total(lines),
    );
  }

  static String? _merchant(List<String> lines) {
    final ignored = RegExp(
      r'receipt|invoice|tax|gst|bill no|invoice no|date|time|cashier|phone|tel|www\.|http',
      caseSensitive: false,
    );
    for (final line in lines.take(8)) {
      if (line.length < 2 ||
          line.length > 64 ||
          RegExp(r'^[-=\d\s.,:/]+$').hasMatch(line) ||
          ignored.hasMatch(line) ||
          _dateFrom(line) != null ||
          _amountFrom(line) != null) {
        continue;
      }
      return line;
    }
    return null;
  }

  static DateTime? _date(List<String> lines) {
    for (final line in lines) {
      final result = _dateFrom(line);
      if (result != null) return result;
    }
    return null;
  }

  static DateTime? _dateFrom(String text) {
    final iso = RegExp(r'\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b')
        .firstMatch(text);
    if (iso != null) {
      return _validDate(
        int.parse(iso[1]!),
        int.parse(iso[2]!),
        int.parse(iso[3]!),
      );
    }
    final numeric = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b')
        .firstMatch(text);
    if (numeric != null) {
      var year = int.parse(numeric[3]!);
      if (year < 100) year += year < 70 ? 2000 : 1900;
      // Indian receipts conventionally use day/month/year.
      return _validDate(year, int.parse(numeric[2]!), int.parse(numeric[1]!));
    }
    final named = RegExp(
      r'\b(\d{1,2})\s+([A-Za-z]{3,9})\s+(20\d{2})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (named != null) {
      const months = {
        'jan': 1,
        'january': 1,
        'feb': 2,
        'february': 2,
        'mar': 3,
        'march': 3,
        'apr': 4,
        'april': 4,
        'may': 5,
        'jun': 6,
        'june': 6,
        'jul': 7,
        'july': 7,
        'aug': 8,
        'august': 8,
        'sep': 9,
        'sept': 9,
        'september': 9,
        'oct': 10,
        'october': 10,
        'nov': 11,
        'november': 11,
        'dec': 12,
        'december': 12,
      };
      final month = months[named[2]!.toLowerCase()];
      if (month != null) {
        return _validDate(int.parse(named[3]!), month, int.parse(named[1]!));
      }
    }
    return null;
  }

  static DateTime? _validDate(int year, int month, int day) {
    if (year < 2000 || year > 2100 || month < 1 || month > 12) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static String? _total(List<String> lines) {
    final candidates =
        <({String line, int priority, int index, String amount})>[];
    final excludedTerms = RegExp(
      r'sub\s*total|tax|gst|vat|discount|saving|change|cash tendered|round.?off',
      caseSensitive: false,
    );
    final totalTerms = RegExp(
      r'grand\s*total|total\s*due|amount\s*(?:payable|paid)|net\s*payable|balance\s*due|\btotal\b',
      caseSensitive: false,
    );
    final currencyTerms = RegExp(r'₹|\bINR\b|\bRs\.?', caseSensitive: false);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!totalTerms.hasMatch(line) && !currencyTerms.hasMatch(line)) continue;
      final amount = _amountFrom(line);
      if (amount == null) continue;
      if (excludedTerms.hasMatch(line)) continue;
      final priority =
          RegExp(
            r'grand\s*total|amount\s*(?:payable|paid)|net\s*payable|balance\s*due',
            caseSensitive: false,
          ).hasMatch(line)
          ? 3
          : RegExp(r'total\s*due|total', caseSensitive: false).hasMatch(line)
          ? 2
          : 1;
      candidates.add((
        line: line,
        priority: priority,
        index: i,
        amount: amount,
      ));
    }
    if (candidates.isEmpty) return null;
    final bestPriority = candidates
        .map((candidate) => candidate.priority)
        .reduce((a, b) => a > b ? a : b);
    if (bestPriority == 1 &&
        candidates.where((candidate) => candidate.priority == 1).length > 1) {
      // Multiple unlabeled currency amounts do not reveal which is the total.
      return null;
    }
    candidates.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      return priority != 0 ? priority : b.index.compareTo(a.index);
    });
    return candidates.first.amount;
  }

  static String? _amountFrom(String line) {
    final matches = RegExp(
      r'(?:₹|INR\s*|Rs\.?\s*)?\s*((?:\d{1,3}(?:\.\d{3})+,\d{1,2})|(?:\d[\d,]*(?:\.\d{1,2})?))(?<![.,])(?![\d.,])',
      caseSensitive: false,
    ).allMatches(line).toList();
    for (final match in matches.reversed) {
      var value = match.group(1)!.trim();
      if (value.contains(',') &&
          value.contains('.') &&
          value.lastIndexOf(',') > value.lastIndexOf('.')) {
        value = value.replaceAll('.', '').replaceFirst(',', '.');
      } else {
        value = value.replaceAll(',', '');
      }
      try {
        MoneyParser.rupeesToPaise(value);
        return value;
      } catch (_) {
        // A malformed OCR candidate should not prevent trying another token.
      }
    }
    return null;
  }
}
