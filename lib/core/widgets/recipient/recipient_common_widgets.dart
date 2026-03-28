import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';

String shortenRecipientAddress(String address) {
  if (address.length <= 16) return address;
  return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
}

Color _mix(Color a, Color b, double amount) => Color.lerp(a, b, amount) ?? a;

List<BoxShadow> _recipientShadow(Color color, {double alpha = 0.08}) {
  return [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
}

class RecipientModeChip extends StatelessWidget {
  const RecipientModeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.backgroundColor,
    required this.selectedBackgroundColor,
    required this.borderColor,
    required this.selectedBorderColor,
    required this.textColor,
    required this.selectedTextColor,
    required this.iconColor,
    required this.selectedIconColor,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color selectedBackgroundColor;
  final Color borderColor;
  final Color selectedBorderColor;
  final Color textColor;
  final Color selectedTextColor;
  final Color iconColor;
  final Color selectedIconColor;

  @override
  Widget build(BuildContext context) {
    final chipColor = selected
        ? _mix(selectedBackgroundColor, selectedBorderColor, 0.08)
        : backgroundColor;
    final iconPanelColor = selected
        ? selectedBorderColor.withValues(alpha: 0.14)
        : borderColor.withValues(alpha: 0.16);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? selectedBorderColor : borderColor,
            width: selected ? 1.25 : 1,
          ),
          boxShadow: selected
              ? _recipientShadow(selectedBorderColor, alpha: 0.12)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconPanelColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                icon,
                size: 14,
                color: selected ? selectedIconColor : iconColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? selectedTextColor : textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selectedTextColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RecipientQuickActionButton extends StatelessWidget {
  const RecipientQuickActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final hasLabel = (label ?? '').trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: hasLabel ? 12 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: _recipientShadow(borderColor, alpha: 0.06),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            if (hasLabel) ...[
              const SizedBox(width: 8),
              Text(
                label!,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RecipientLookupLoadingCard extends StatelessWidget {
  const RecipientLookupLoadingCard({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.spinnerColor,
    required this.labelColor,
    this.label = 'Looking up address...',
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color spinnerColor;
  final Color labelColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: _recipientShadow(borderColor, alpha: 0.05),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: spinnerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: spinnerColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Validating destination details',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecipientPickerEmptyState extends StatelessWidget {
  const RecipientPickerEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    this.borderColor,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            backgroundColor,
            _mix(backgroundColor, c.surfaceRaised, 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1),
        boxShadow: _recipientShadow(c.border, alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      c.primary.withValues(alpha: 0.18),
                      c.primary.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: c.primary),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: c.primary.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Recipient setup',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: c.primary.withValues(alpha: 0.06),
                side: BorderSide(color: c.primary.withValues(alpha: 0.16)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onTap,
              icon: Icon(icon, size: 16, color: c.primary),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class RecipientScannedValueCard extends StatelessWidget {
  const RecipientScannedValueCard({
    super.key,
    required this.rawValue,
    required this.emptyMessage,
    required this.backgroundColor,
    this.borderColor,
  });

  final String rawValue;
  final String emptyMessage;
  final Color backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final hasValue = rawValue.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            backgroundColor,
            _mix(backgroundColor, c.surfaceRaised, 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1),
        boxShadow: _recipientShadow(c.border, alpha: 0.045),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: c.primary.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.scanLine, size: 13, color: c.primary),
                    const SizedBox(width: 6),
                    Text(
                      'QR recipient',
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                hasValue ? 'Ready' : 'Awaiting scan',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border.withValues(alpha: 0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasValue ? 'Scanned value' : 'No code scanned yet',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasValue ? rawValue : emptyMessage,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    height: 1.4,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecipientSavedCard extends StatelessWidget {
  const RecipientSavedCard({
    super.key,
    required this.name,
    required this.address,
    required this.colorValue,
    required this.onEdit,
    required this.backgroundColor,
    required this.borderColor,
    required this.avatarBackgroundColor,
    required this.editBackgroundColor,
    required this.addressColor,
  });

  final String name;
  final String address;
  final int colorValue;
  final VoidCallback onEdit;
  final Color backgroundColor;
  final Color borderColor;
  final Color avatarBackgroundColor;
  final Color editBackgroundColor;
  final Color addressColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final brand = Color(colorValue);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundColor, _mix(backgroundColor, brand, 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: _recipientShadow(brand, alpha: 0.09),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: brand.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Saved contact',
                  style: TextStyle(
                    color: brand,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: editBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.pencil, size: 14, color: brand),
                      const SizedBox(width: 6),
                      Text(
                        'Edit',
                        style: TextStyle(
                          color: brand,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: avatarBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: brand,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.75),
                        ),
                      ),
                      child: Text(
                        shortenRecipientAddress(address),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: addressColor,
                          fontSize: 11.8,
                          letterSpacing: 0.35,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecipientNewAddressCard extends StatelessWidget {
  const RecipientNewAddressCard({
    super.key,
    required this.address,
    required this.onAdd,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.addressColor,
    required this.saveBackgroundColor,
    required this.saveBorderColor,
    required this.saveTextColor,
  });

  final String address;
  final VoidCallback onAdd;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color addressColor;
  final Color saveBackgroundColor;
  final Color saveBorderColor;
  final Color saveTextColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundColor, _mix(backgroundColor, iconColor, 0.035)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: _recipientShadow(borderColor, alpha: 0.055),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Unsaved recipient',
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: saveBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: saveBorderColor, width: 1),
                    boxShadow: _recipientShadow(saveBorderColor, alpha: 0.08),
                  ),
                  child: Text(
                    'Save contact',
                    style: TextStyle(
                      color: saveTextColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.2,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(LucideIcons.userPlus, size: 18, color: iconColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save this destination',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.75),
                        ),
                      ),
                      child: Text(
                        shortenRecipientAddress(address),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: addressColor,
                          fontSize: 11.8,
                          letterSpacing: 0.35,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecipientStatusBanner extends StatelessWidget {
  const RecipientStatusBanner({
    super.key,
    required this.title,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    this.icon,
    this.subtitle,
    this.showSpinner = false,
    this.trailing,
    this.titleColor,
    this.subtitleColor,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final bool showSpinner;
  final Widget? trailing;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final Color? titleColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final resolvedTitleColor = titleColor ?? color;
    final resolvedSubtitleColor = subtitleColor ?? color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: _recipientShadow(borderColor, alpha: 0.05),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: showSpinner
                  ? SizedBox(
                      height: 17,
                      width: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: color,
                      ),
                    )
                  : icon != null
                  ? Icon(icon, size: 17, color: color)
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: resolvedTitleColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: resolvedSubtitleColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
