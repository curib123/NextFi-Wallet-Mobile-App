import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:next_fi/app/theme/app_color.dart';

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
    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (onClose != null)
              _buildControl(
                colors: colors,
                isDark: isDark,
                icon: LucideIcons.x,
                onTap: onClose!,
              ),
            if (onClose == null) const SizedBox(width: 48),
            const Spacer(),
            _buildControl(
              colors: colors,
              isDark: isDark,
              icon: torchOn ? LucideIcons.zap : LucideIcons.zapOff,
              onTap: onToggleTorch,
              isActive: torchOn,
            ),
            const SizedBox(width: 12),
            if (onPickFromGallery != null) ...[
              _buildControl(
                colors: colors,
                isDark: isDark,
                icon: LucideIcons.image,
                onTap: onPickFromGallery!,
              ),
              const SizedBox(width: 12),
            ],
            _buildControl(
              colors: colors,
              isDark: isDark,
              icon: LucideIcons.flipHorizontal2,
              onTap: onSwitchCamera,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControl({
    required AppColor colors,
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final backgroundColor = isActive
        ? colors.primary.withValues(alpha: isDark ? 0.5 : 0.42)
        : colors.background.withValues(alpha: isDark ? 0.7 : 0.58);
    final borderColor = isActive
        ? colors.primary.withValues(alpha: isDark ? 0.75 : 0.62)
        : colors.border.withValues(alpha: isDark ? 0.5 : 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Icon(icon, size: 22, color: colors.onPrimary),
        ),
      ),
    );
  }
}
