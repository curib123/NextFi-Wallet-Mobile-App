import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/features/scanner/presentation/viewmodels/scanner_state.dart';
import 'package:next_fi/features/scanner/presentation/viewmodels/scanner_controller.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/features/scanner/presentation/widgets/scan_controls.dart';
import 'package:next_fi/features/scanner/presentation/widgets/scan_overlay.dart';
import 'package:next_fi/features/scanner/presentation/widgets/scan_permission_card.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<ScannerState>(scannerControllerProvider, (previous, next) {
      final previousRaw = previous?.lastRawValue;
      final nextRaw = next.lastRawValue;
      if (nextRaw == null || nextRaw.isEmpty || nextRaw == previousRaw) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(nextRaw);
        }
      });
    });

    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(scannerControllerProvider);
    final controller = ref.read(scannerControllerProvider.notifier);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (state.status == ScannerStatus.ready ||
              state.status == ScannerStatus.paused ||
              state.status == ScannerStatus.initializing)
            MobileScanner(
              controller: controller.controller,
              onDetect: controller.onDetect,
              fit: BoxFit.cover,
            ),
          if (state.status == ScannerStatus.ready ||
              state.status == ScannerStatus.paused ||
              state.status == ScannerStatus.initializing)
            const ScanOverlay(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ScanControls(
              torchOn: state.torchOn,
              facing: state.facing,
              onToggleTorch: controller.toggleTorch,
              onSwitchCamera: controller.switchCamera,
              onPickFromGallery: () async {
                final message = await controller.pickQrFromGallery();
                if (!context.mounted || message == null || message.isEmpty) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              },
              onClose: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          if (state.status == ScannerStatus.ready ||
              state.status == ScannerStatus.paused)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.onPrimary,
                          shadows: [
                            Shadow(
                              color: colors.background.withValues(alpha: 0.55),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Position the QR code within the frame',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onPrimary.withValues(alpha: 0.9),
                          shadows: [
                            Shadow(
                              color: colors.background.withValues(alpha: 0.55),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (state.lastRawValue != null && state.status == ScannerStatus.paused)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.checkCircle2,
                            color: colors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Code Detected',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.lastRawValue!,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: AppFilledButton.icon(
                          onPressed: controller.resume,
                          icon: const Icon(LucideIcons.scanLine, size: 18),
                          label: const Text('Scan Another'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (state.status == ScannerStatus.noPermission)
            ScanPermissionCard(onTryAgain: controller.retryPermission),
          if (state.status == ScannerStatus.error)
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.42 : 0.12,
                      ),
                      blurRadius: isDark ? 26 : 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.alertTriangle,
                        size: 32,
                        color: colors.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Scanner Error',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.errorMessage ?? 'An unexpected error occurred',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: AppFilledButton.icon(
                        onPressed: controller.init,
                        icon: const Icon(LucideIcons.refreshCw, size: 20),
                        label: const Text('Try Again'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (state.status == ScannerStatus.initializing)
            Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
        ],
      ),
    );
  }
}

