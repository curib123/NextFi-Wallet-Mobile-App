import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      _handled = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /* Camera + overlay */
          AiBarcodeScanner(
            controller: _controller,
            overlayConfig: ScannerOverlayConfig(
              scannerBorder: ScannerBorder.corner,
              borderColor: scheme.primary,
              successColor: Colors.greenAccent,
              errorColor: Colors.redAccent,
              borderRadius: 16,
              cornerLength: 36,
              scannerAnimation: ScannerAnimation.fullWidth,
            ),
            galleryButtonType: GalleryButtonType.icon,
            onDetect: _onDetect,
          ),

          /* Header controls */
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  _RoundIconButton(
                    tooltip: 'Close',
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Scan QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  _RoundIconButton(
                    tooltip: _torchOn ? 'Flashlight off' : 'Flashlight on',
                    icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    onTap: () async {
                      await _controller.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                  ),
                  const SizedBox(width: 8),
                  _RoundIconButton(
                    tooltip: 'Flip camera',
                    icon: Icons.cameraswitch_rounded,
                    onTap: () => _controller.switchCamera(),
                  ),
                ],
              ),
            ),
          ),

          /* Bottom hint */
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: Colors.white70),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Align the QR within the frame.\nAuto-detect will capture instantly.',
                        style: const TextStyle(color: Colors.white70, height: 1.25),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---- Small UI helper ---- */
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
