import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerGalleryResult {
  const ScannerGalleryResult({this.rawValue, this.errorMessage});

  final String? rawValue;
  final String? errorMessage;
}

class ScannerGalleryService {
  ScannerGalleryService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<ScannerGalleryResult> pickQrFromGallery(
    MobileScannerController controller,
  ) async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        return const ScannerGalleryResult();
      }

      final capture = await controller.analyzeImage(image.path);
      final rawValue = (capture?.barcodes.isNotEmpty ?? false)
          ? capture!.barcodes.first.rawValue?.trim()
          : null;

      if (rawValue == null || rawValue.isEmpty) {
        return const ScannerGalleryResult(
          errorMessage: 'No QR code found in selected image',
        );
      }

      return ScannerGalleryResult(rawValue: rawValue);
    } catch (e) {
      return ScannerGalleryResult(errorMessage: 'Failed to read QR image: $e');
    }
  }
}
