import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String message;

  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  final Widget? illustration;
  final bool compact;
  final bool fill;

  const EmptyState({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
    this.compact = false,
    this.fill = false,
  });

  // Variants using AppColor
  factory EmptyState.error({
    required BuildContext context,
    required String title,
    required String message,
    String? primaryActionLabel,
    VoidCallback? onPrimaryAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) =>
      EmptyState(
        icon: LucideIcons.alertTriangle,
        accentColor: AppColor.of(context).error,
        title: title,
        message: message,
        primaryActionLabel: primaryActionLabel,
        onPrimaryAction: onPrimaryAction,
        secondaryActionLabel: secondaryActionLabel,
        onSecondaryAction: onSecondaryAction,
      );

  factory EmptyState.noData({
    required BuildContext context,
    required String title,
    required String message,
    String? primaryActionLabel,
    VoidCallback? onPrimaryAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) =>
      EmptyState(
        icon: LucideIcons.inbox,
        accentColor: AppColor.of(context).info,
        title: title,
        message: message,
        primaryActionLabel: primaryActionLabel,
        onPrimaryAction: onPrimaryAction,
        secondaryActionLabel: secondaryActionLabel,
        onSecondaryAction: onSecondaryAction,
      );

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final basePad = compact ? 16.0 : 24.0;
    final iconSize = compact ? 44.0 : 56.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.all(basePad),
          child: Column(
            mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment:
            fill ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (illustration != null) ...[
                Padding(
                  padding: EdgeInsets.only(bottom: basePad),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: FittedBox(
                        fit: BoxFit.contain, child: illustration),
                  ),
                ),
              ],
              _IconBadge(icon: icon, color: accentColor, size: iconSize),
              SizedBox(height: basePad * 0.66),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (primaryActionLabel != null || secondaryActionLabel != null) ...[
                SizedBox(height: basePad),
                Column(
                  children: [
                    if (primaryActionLabel != null && onPrimaryAction != null)
                      CustomButton(
                        text: primaryActionLabel!,
                        onPressed: onPrimaryAction!,
                        type: ButtonType.filled,
                        fullWidth: false,
                      ),
                    if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                      const SizedBox(height: 12),
                      CustomButton(
                        text: secondaryActionLabel!,
                        onPressed: onSecondaryAction!,
                        type: ButtonType.outlined,
                        fullWidth: false,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconBadge({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.12);
    return Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size),
    );
  }
}
