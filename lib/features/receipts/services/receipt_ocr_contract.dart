import '../domain/receipt_text_parser.dart';

abstract interface class ReceiptOcrService {
  Future<ReceiptTextResult> recognize(String imagePath);
  Future<void> close();
}
