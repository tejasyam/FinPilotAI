import '../errors/app_exception.dart';

abstract final class MoneyParser {
  /// Maximum amount whose paise value is an exact integer on web and native.
  /// JavaScript's largest exactly represented integer is 2^53 - 1 paise.
  static const int maxExactPaise = 9007199254740991;
  static const int _maxWholeRupees = maxExactPaise ~/ 100;
  static const int _maxRemainderPaise = maxExactPaise % 100;

  /// Converts a rupee amount string to paise without floating-point math.
  static int rupeesToPaise(String input) {
    final rawValue = input.trim();
    final amountText = rawValue.startsWith('₹')
        ? rawValue.substring(1).trim()
        : rawValue;
    final value = amountText.contains(',')
        ? amountText.replaceAll(',', '')
        : amountText;
    if (rawValue.contains(',') &&
        !RegExp(r'^₹?\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?$').hasMatch(rawValue)) {
      throw const AppException('Enter a valid rupee amount.');
    }
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value);
    if (match == null) {
      throw const AppException(
        'Enter an amount with up to two decimal places.',
      );
    }
    final wholeText = match.group(1)!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final fractionText = (match.group(2) ?? '').padRight(2, '0');
    final normalizedFraction = fractionText.isEmpty ? '00' : fractionText;

    // Compare the whole-number decimal text before parsing it. This avoids an
    // overflowing int parse for arbitrarily long inputs on native Dart and
    // keeps all intermediate values within JavaScript's exact integer range.
    if (wholeText.length > '$_maxWholeRupees'.length ||
        (wholeText.length == '$_maxWholeRupees'.length &&
            wholeText.compareTo('$_maxWholeRupees') > 0)) {
      throw const AppException('Amount is too large.');
    }
    final whole = int.parse(wholeText);
    final fraction = int.parse(normalizedFraction);
    if (whole == _maxWholeRupees && fraction > _maxRemainderPaise) {
      throw const AppException('Amount is too large.');
    }
    final paise = whole * 100 + fraction;
    if (paise <= 0) {
      throw const AppException('Amount must be greater than zero.');
    }
    return paise;
  }
}
