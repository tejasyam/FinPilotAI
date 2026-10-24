import 'package:image_picker/image_picker.dart';

abstract interface class ReceiptImageSource {
  Future<XFile?> pick(ImageSource source);
}

class DeviceReceiptImageSource implements ReceiptImageSource {
  DeviceReceiptImageSource([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pick(ImageSource source) => _picker.pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 2200,
    maxHeight: 3000,
  );
}
