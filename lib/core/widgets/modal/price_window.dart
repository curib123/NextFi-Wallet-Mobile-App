import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_state.dart';

void showPriceWindowModal(
  BuildContext context, {
  required AppColor colors,
  required PriceWindow selectedWindow,
  required void Function(PriceWindow)? onWindowChanged,
}) {
  showAppModalBottomSheet(
    context,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(LucideIcons.trendingUp, size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Text(
                  'Select Price Window',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...PriceWindow.values.map((window) {
            final isSelected = window == selectedWindow;
            return _ModalWindowOption(
              label: _windowLabel(window),
              shortLabel: _windowShortLabel(window),
              isSelected: isSelected,
              colors: colors,
              onTap: () {
                onWindowChanged?.call(window);
                Navigator.pop(context);
              },
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    ),
  );
}

String _windowLabel(PriceWindow w) {
  switch (w) {
    case PriceWindow.h24:
      return '24 Hours';
    case PriceWindow.d7:
      return '7 Days';
    case PriceWindow.d30:
      return '30 Days';
    case PriceWindow.y1:
      return '1 Year';
  }
}

String _windowShortLabel(PriceWindow w) {
  switch (w) {
    case PriceWindow.h24:
      return '24H';
    case PriceWindow.d7:
      return '7D';
    case PriceWindow.d30:
      return '30D';
    case PriceWindow.y1:
      return '1Y';
  }
}

class _ModalWindowOption extends StatelessWidget {
  final String label;
  final String shortLabel;
  final bool isSelected;
  final AppColor colors;
  final VoidCallback onTap;

  const _ModalWindowOption({
    required this.label,
    required this.shortLabel,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary
                    : colors.border.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                shortLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColor.of(context).onPrimary
                      : colors.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colors.primary : colors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.check, size: 20, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
