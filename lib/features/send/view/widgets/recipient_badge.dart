// lib/features/send/view/widgets/recipient_badge.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class RecipientBadge extends StatelessWidget {
  const RecipientBadge({
    super.key,
    required this.name,
    required this.colorValue,
    required this.address,
    required this.onEdit,
  });

  final String name;
  final int colorValue;
  final String address;
  final VoidCallback onEdit;

  String _shortenAddress(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 6)}';
  }

  /// Returns a solid, non-opacity tinted background color derived from the
  /// brand color but mixed toward the surface so it stays readable.
  Color _solidTint(Color brand, bool isDark, AppColor c) {
    // Blend brand toward white (light) or dark surface
    final base = isDark ? c.textPrimary : c.surface;
    return Color.lerp(base, brand, isDark ? 0.14 : 0.10)!;
  }

  Color _solidBorder(Color brand, bool isDark, AppColor c) {
    final base = isDark ? c.textPrimary : c.surface;
    return Color.lerp(base, brand, isDark ? 0.26 : 0.22)!;
  }

  Color _solidAvatarBg(Color brand, bool isDark, AppColor c) {
    final base = isDark ? c.textPrimary : c.onPrimary;
    return Color.lerp(base, brand, isDark ? 0.22 : 0.15)!;
  }

  Color _solidEditBg(Color brand, bool isDark, AppColor c) {
    final base = isDark ? c.textPrimary : c.onPrimary;
    return Color.lerp(base, brand, isDark ? 0.20 : 0.13)!;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final color = Color(colorValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = _solidTint(color, isDark, c);
    final borderColor = _solidBorder(color, isDark, c);
    final avatarBg = _solidAvatarBg(color, isDark, c);
    final editBg = _solidEditBg(color, isDark, c);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          // ── Avatar ────────────────────────────────────────────────────
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: avatarBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),

          // ── Name + address ────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.4,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _shortenAddress(address),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11.5,
                    letterSpacing: 0.3,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Edit button ───────────────────────────────────────────────
          GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: editBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Center(
                child: Icon(LucideIcons.pencil, size: 15, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
