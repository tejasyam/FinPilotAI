import 'package:finpilot_ai/features/receipts/domain/receipt_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'extracts merchant, Indian date, and grand total in integer-safe text',
    () {
      final result = ReceiptTextParser.parse('''
      Green Basket
      TAX INVOICE
      Date: 31/01/2025
      Subtotal  ₹1,450.00
      GST  ₹72.50
      Discount -₹20.00
      Grand Total  ₹1,502.50
    ''');

      expect(result.merchant, 'Green Basket');
      expect(result.date, DateTime(2025, 1, 31));
      expect(result.amountRupees, '1502.50');
      expect(result.rawText, contains('Grand Total'));
    },
  );

  test('supports ISO and named dates and decimal separators', () {
    final iso = ReceiptTextParser.parse(
      'Corner Shop\n2025-02-03\nTotal INR 99.25',
    );
    expect(iso.date, DateTime(2025, 2, 3));
    expect(iso.amountRupees, '99.25');

    final european = ReceiptTextParser.parse(
      'Store\n3 Feb 2025\nTotal 1.234,56',
    );
    expect(european.date, DateTime(2025, 2, 3));
    expect(european.amountRupees, '1234.56');
  });

  test('prefers explicit total labels over larger subtotal or tax values', () {
    final result = ReceiptTextParser.parse('''
      Grocery Market
      Subtotal 5000.00
      Tax 900.00
      Item 6000.00
      Total Due  4500.00
    ''');
    expect(result.amountRupees, '4500.00');
  });

  test(
    'reports missing or invalid detected fields without inventing values',
    () {
      final missing = ReceiptTextParser.parse(
        'TAX INVOICE\nGSTIN: 29ABCDE1234F1Z5',
      );
      expect(missing.merchant, isNull);
      expect(missing.date, isNull);
      expect(missing.amountRupees, isNull);
      expect(missing.hasAnySuggestedField, isFalse);

      final invalidDate = ReceiptTextParser.parse(
        'Shop\n31/02/2025\nTotal ₹0.00',
      );
      expect(invalidDate.merchant, 'Shop');
      expect(invalidDate.date, isNull);
      expect(invalidDate.amountRupees, isNull);
    },
  );

  test('does not guess between multiple unlabeled receipt amounts', () {
    final result = ReceiptTextParser.parse('''
      Neighborhood Shop
      Milk ₹52.00
      Bread ₹45.00
    ''');
    expect(result.merchant, 'Neighborhood Shop');
    expect(result.amountRupees, isNull);
  });
}
