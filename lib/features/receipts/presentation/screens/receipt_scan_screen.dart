import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../transactions/controllers/finance_controller.dart';
import '../../services/receipt_image_source.dart';
import '../../services/receipt_ocr_contract.dart';
import '../../services/receipt_ocr_service.dart';
import 'receipt_review_screen.dart';

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({
    required this.controller,
    this.imageSource,
    this.ocrService,
    super.key,
  });

  final FinanceController controller;
  final ReceiptImageSource? imageSource;
  final ReceiptOcrService? ocrService;

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  late final ReceiptImageSource _imageSource =
      widget.imageSource ?? DeviceReceiptImageSource();
  late final ReceiptOcrService _ocr =
      widget.ocrService ?? createReceiptOcrService();
  bool _working = false;
  String? _error;
  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _choose(ImageSource source) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan privately on this device'),
        content: Text(
          source == ImageSource.camera
              ? 'FinPilotAI uses the camera only to read this receipt. The image and its text are not uploaded or saved by the app.'
              : 'FinPilotAI reads the selected receipt on this device. The image and its text are not uploaded or saved with your finance data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              source == ImageSource.camera ? 'Open camera' : 'Choose image',
            ),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final image = await _imageSource.pick(source);
      if (image == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt selection canceled.')),
          );
        }
        return;
      }
      final result = await _ocr.recognize(image.path);
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => ReceiptReviewScreen(
            controller: widget.controller,
            result: result,
          ),
        ),
      );
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt transaction saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString();
        setState(() {
          _error = message.contains('denied') || message.contains('permission')
              ? 'Camera or photo permission was denied. Allow access in device settings and try again.'
              : 'Could not scan this image. Try a clearer, well-lit receipt.';
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    _ocr.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan receipt')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.document_scanner_outlined,
                color: AppColors.mint,
                size: 32,
              ),
              SizedBox(height: 14),
              Text(
                'Receipt scanning stays on your device',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'OCR suggestions can be wrong. Review and confirm every field before anything is saved.',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_isSupportedPlatform)
          const AppCard(
            child: Text(
              'Receipt OCR requires the on-device text recognition service available in Android and iOS builds. Browser and desktop previews do not scan receipts.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else ...[
          FilledButton.icon(
            onPressed: _working ? null : () => _choose(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Take receipt photo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _working ? null : () => _choose(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
        ],
        if (_working) ...[
          const SizedBox(height: 18),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Reading receipt on device…', textAlign: TextAlign.center),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          AppCard(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ],
    ),
  );
}
