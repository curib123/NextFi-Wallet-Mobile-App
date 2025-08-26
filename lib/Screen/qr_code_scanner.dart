
import 'package:flutter/material.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AiBarcodeScanner(
        controller: MobileScannerController(
          formats: [BarcodeFormat.qrCode],
        ),
        overlayConfig: const ScannerOverlayConfig(
          scannerBorder: ScannerBorder.full,
          borderColor: Colors.teal,
          successColor: Colors.green,
          errorColor: Colors.red,
          borderRadius: 16,
          cornerLength: 40,
          scannerAnimation: ScannerAnimation.fullWidth,
        ),
        galleryButtonType: GalleryButtonType.icon,
        onDetect: (BarcodeCapture capture) {
          final code = capture.barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            Navigator.of(context).pop(code);
          }
        },
      ),
    );
  }
}
