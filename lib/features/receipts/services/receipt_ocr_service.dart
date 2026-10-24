import 'receipt_ocr_service_stub.dart'
    if (dart.library.io) 'receipt_ocr_service_native.dart'
    as platform;
import 'receipt_ocr_contract.dart';

ReceiptOcrService createReceiptOcrService() =>
    platform.createReceiptOcrServiceImpl();
