import 'package:finpilot_ai/core/utils/money_parser.dart';
import 'package:finpilot_ai/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts rupees to integer paise without floating point', () {
    expect(MoneyParser.rupeesToPaise('1'), 100);
    expect(MoneyParser.rupeesToPaise('32,450.05'), 3245005);
    expect(MoneyParser.rupeesToPaise('₹0.10'), 10);
    expect(MoneyParser.rupeesToPaise('0.1'), 10);
    expect(MoneyParser.rupeesToPaise('0.01'), 1);
  });

  test('rejects zero, malformed grouping, and more than two decimals', () {
    expect(() => MoneyParser.rupeesToPaise('0'), throwsA(isA<AppException>()));
    expect(
      () => MoneyParser.rupeesToPaise('12,34.56'),
      throwsA(isA<AppException>()),
    );
    expect(
      () => MoneyParser.rupeesToPaise('12.345'),
      throwsA(isA<AppException>()),
    );
    expect(
      () => MoneyParser.rupeesToPaise('-1.00'),
      throwsA(isA<AppException>()),
    );
    expect(
      () => MoneyParser.rupeesToPaise('1e2'),
      throwsA(isA<AppException>()),
    );
    expect(
      () => MoneyParser.rupeesToPaise('1,0000'),
      throwsA(isA<AppException>()),
    );
    expect(() => MoneyParser.rupeesToPaise(''), throwsA(isA<AppException>()));
  });

  test('accepts the maximum exact paise amount on web and native', () {
    expect(
      MoneyParser.rupeesToPaise('90071992547409.91'),
      MoneyParser.maxExactPaise,
    );
    expect(
      MoneyParser.rupeesToPaise('90071992547409.9'),
      MoneyParser.maxExactPaise - 1,
    );
  });

  test('rejects amounts one paise above the cross-platform limit', () {
    expect(
      () => MoneyParser.rupeesToPaise('90071992547409.92'),
      throwsA(isA<AppException>()),
    );
    expect(
      () =>
          MoneyParser.rupeesToPaise('999999999999999999999999999999999999999'),
      throwsA(isA<AppException>()),
    );
  });
}
