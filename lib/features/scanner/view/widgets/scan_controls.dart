import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanControls extends StatelessWidget {
  const ScanControls({
    super.key,
    required this.torchOn,
    required this.facing,
    required this.onToggleTorch,
    required this.onSwitchCamera,
    this.onClose,
  });

  final bool torchOn;
  final CameraFacing facing;
  final VoidCallback onToggleTorch;
  final VoidCallback onSwitchCamera;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    Widget _pill(IconData icon, String label, VoidCallback onTap, {bool active = false}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.primary.withOpacity(.15) : Colors.black26,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: active ? c.primary : Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? c.primary : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (onClose != null)
              _pill(LucideIcons.x, 'Close', onClose!),
            const Spacer(),
            _pill(
              torchOn ? LucideIcons.sunMedium : LucideIcons.sun,
              torchOn ? 'Torch On' : 'Torch',
              onToggleTorch,
              active: torchOn,
            ),
            const SizedBox(width: 8),
            _pill(
              LucideIcons.shuffle,
              facing == CameraFacing.back ? 'Back' : 'Front',
              onSwitchCamera,
            ),
          ],
        ),
      ),
    );
  }
}
