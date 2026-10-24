import 'dart:async';

import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/features/receipts/domain/receipt_text_parser.dart';
import 'package:finpilot_ai/features/receipts/presentation/screens/receipt_review_screen.dart';
import 'package:finpilot_ai/features/receipts/presentation/screens/receipt_scan_screen.dart';
import 'package:finpilot_ai/features/receipts/services/receipt_image_source.dart';
import 'package:finpilot_ai/features/receipts/services/receipt_ocr_contract.dart';
import 'package:finpilot_ai/features/transactions/controllers/finance_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('review form validates required merchant and amount', (
    tester,
  ) async {
    final controller = _FakeController();
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptReviewScreen(
          controller: controller,
          result: const ReceiptTextResult(rawText: 'Tax invoice'),
        ),
      ),
    );
    await tester.tap(find.text('Confirm and save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a description.'), findsOneWidget);
    expect(
      find.text('Enter a valid amount greater than zero.'),
      findsOneWidget,
    );
    expect(controller.saved, isEmpty);
  });

  testWidgets('confirmed receipt becomes one expense through controller', (
    tester,
  ) async {
    final controller = _FakeController();
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptReviewScreen(
          controller: controller,
          result: ReceiptTextResult(
            rawText: 'Fresh Mart\nTotal ₹12.50',
            merchant: 'Fresh Mart',
            amountRupees: '12.50',
            date: DateTime(2025, 4, 5),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Confirm and save transaction'));
    await tester.pumpAndSettle();
    expect(controller.saved, hasLength(1));
    expect(controller.saved.single.amountPaise, 1250);
    expect(controller.saved.single.description, 'Fresh Mart');
    expect(
      controller.saved.single.transactionDate.toLocal(),
      DateTime(2025, 4, 5),
    );
    expect(controller.saved.single.type, TransactionType.expense);
  });

  testWidgets('rapid duplicate confirmation saves only once', (tester) async {
    final controller = _FakeController()..saveGate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptReviewScreen(
          controller: controller,
          result: const ReceiptTextResult(
            rawText: '',
            merchant: 'Shop',
            amountRupees: '10.00',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Confirm and save transaction'));
    await tester.pump();
    await tester.tap(find.text('Saving…'));
    await tester.pump();
    expect(controller.saved, hasLength(1));
    controller.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(controller.saved, hasLength(1));
  });

  testWidgets('picker cancellation returns without OCR or error', (
    tester,
  ) async {
    final controller = _FakeController();
    final source = _FakeImageSource(null);
    final ocr = _FakeOcr();
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptScanScreen(
          controller: controller,
          imageSource: source,
          ocrService: ocr,
        ),
      ),
    );
    await tester.tap(find.text('Take receipt photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open camera'));
    await tester.pumpAndSettle();
    expect(source.calls, 1);
    expect(ocr.calls, 0);
    expect(find.text('Scan receipt'), findsOneWidget);
    expect(find.textContaining('Could not scan'), findsNothing);
  });

  testWidgets('permission denial is explained to the user', (tester) async {
    final controller = _FakeController();
    final source = _FakeImageSource.error(
      StateError('camera permission denied'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptScanScreen(
          controller: controller,
          imageSource: source,
          ocrService: _FakeOcr(),
        ),
      ),
    );
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    expect(find.textContaining('permission was denied'), findsOneWidget);
  });
}

class _FakeController extends FinanceController {
  _FakeController() {
    isLoading = false;
  }

  final saved = <FinanceTransaction>[];
  Completer<void>? saveGate;

  @override
  Future<void> createTransaction(FinanceTransaction value) async {
    saved.add(value);
    await saveGate?.future;
    transactions = [value, ...transactions];
    notifyListeners();
  }
}

class _FakeImageSource implements ReceiptImageSource {
  _FakeImageSource(this.result) : failure = null;
  _FakeImageSource.error(this.failure) : result = null;
  final XFile? result;
  final Object? failure;
  int calls = 0;

  @override
  Future<XFile?> pick(ImageSource source) async {
    calls++;
    if (failure != null) throw failure!;
    return result;
  }
}

class _FakeOcr implements ReceiptOcrService {
  int calls = 0;
  @override
  Future<void> close() async {}
  @override
  Future<ReceiptTextResult> recognize(String imagePath) async {
    calls++;
    return const ReceiptTextResult(rawText: '');
  }
}
