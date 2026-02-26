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
    this.onPickFromGallery,
    this.onClose,
  });

  final bool torchOn;
  final CameraFacing facing;
  final VoidCallback onToggleTorch;
  final VoidCallback onSwitchCamera;
  final VoidCallback? onPickFromGallery;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (onClose != null)
              _buildControl(
                icon: LucideIcons.x,
                onTap: onClose!,
              ),
            if (onClose == null) const SizedBox(width: 48),
            const Spacer(),
            _buildControl(
              icon: torchOn ? LucideIcons.zap : LucideIcons.zapOff,
              onTap: onToggleTorch,
              isActive: torchOn,
            ),
            const SizedBox(width: 12),
            if (onPickFromGallery != null) ...[
              _buildControl(
                icon: LucideIcons.image,
                onTap: onPickFromGallery!,
              ),
              const SizedBox(width: 12),
            ],
            _buildControl(
              icon: LucideIcons.flipHorizontal2,
              onTap: onSwitchCamera,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControl({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.25)
                : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? Colors.white.withOpacity(0.4)
                  : Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
