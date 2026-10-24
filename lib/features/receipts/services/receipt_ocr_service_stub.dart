import '../domain/receipt_text_parser.dart';
import 'receipt_ocr_contract.dart';

ReceiptOcrService createReceiptOcrServiceImpl() =>
    UnsupportedReceiptOcrService();

class UnsupportedReceiptOcrService implements ReceiptOcrService {
  @override
  Future<void> close() async {}

  @override
  Future<ReceiptTextResult> recognize(String imagePath) =>
      throw UnsupportedError('On-device receipt OCR is not available here.');
}
