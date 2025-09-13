import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/AppColor.dart';
import '../model/scanner_state.dart';
import '../view_model/scanner_vm.dart';
import 'widgets/scan_controls.dart';
import 'widgets/scan_overlay.dart';
import 'widgets/scan_permission_card.dart';

/// Usage:
/// final result = await Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const ScannerScreen(),
/// ));
/// if (result is String) { /* do something with scanned value */ }
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return ChangeNotifierProvider(
      create: (_) => ScannerVM(onResult: (raw) {
        // When a result is detected, return it then close.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(raw);
        }
      })..init(),
      child: Consumer<ScannerVM>(
        builder: (context, vm, _) {
          final s = vm.state;

          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Camera / Scanner view
                if (s.status == ScannerStatus.ready || s.status == ScannerStatus.paused || s.status == ScannerStatus.initializing)
                  MobileScanner(
                    controller: vm.controller,
                    onDetect: vm.onDetect,
                    overlayBuilder: (ctx, constraints) => const SizedBox.shrink(), // we render our own overlay
                    fit: BoxFit.cover,
                  ),

                // Overlay + controls (only when not in hard error/permission)
                if (s.status == ScannerStatus.ready || s.status == ScannerStatus.paused || s.status == ScannerStatus.initializing)
                  const ScanOverlay(),

                // Top controls
                Align(
                  alignment: Alignment.topCenter,
                  child: ScanControls(
                    torchOn: s.torchOn,
                    facing: s.facing,
                    onToggleTorch: vm.toggleTorch,
                    onSwitchCamera: vm.switchCamera,
                    onClose: () {
                      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    },
                  ),
                ),

                // Bottom status panel
                if (s.lastRawValue != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.55),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.checkCircle2, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.lastRawValue!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.primary.withOpacity(.15),
                                foregroundColor: colors.primary,
                              ),
                              onPressed: () {
                                // Resume if they want to scan another
                                vm.resume();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ready to scan another code')),
                                );
                              },
                              child: const Text('Scan again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Permission / Error cards
                if (s.status == ScannerStatus.noPermission)
                  ScanPermissionCard(onTryAgain: vm.retryPermission),
                if (s.status == ScannerStatus.error)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withOpacity(.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.error),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.alertTriangle, size: 40, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 12),
                          const Text('Scanner Error', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            s.errorMessage ?? 'Unknown error occurred.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: vm.init,
                            child: const Text('Retry'),
                          )
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
