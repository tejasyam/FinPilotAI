import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/receipt_text_parser.dart';
import 'receipt_ocr_contract.dart';

ReceiptOcrService createReceiptOcrServiceImpl() => NativeReceiptOcrService();

class NativeReceiptOcrService implements ReceiptOcrService {
  final TextRecognizer _recognizer = TextRecognizer();

  @override
  Future<ReceiptTextResult> recognize(String imagePath) async {
    final recognized = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return ReceiptTextParser.parse(recognized.text);
  }

  @override
  Future<void> close() => _recognizer.close();
}
