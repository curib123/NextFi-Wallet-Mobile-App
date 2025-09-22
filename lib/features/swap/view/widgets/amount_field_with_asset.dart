import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/features/swap/view/widgets/form_style.dart'; // ensure this path/file matches your project

class AmountFieldWithAsset extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onClear;

  /// the asset shown in the badge next to the field (the "input unit")
  /// i.e. what the user is typing in: 'XLM' or 'USDC'
  final String symbol;

  /// called when user picks a new asset from the badge menu ('XLM' or 'USDC')
  final ValueChanged<String> onPickAsset;

  final double radius;
  final EdgeInsets contentPad;

  const AmountFieldWithAsset({
    super.key,
    required this.label,
    required this.controller,
    required this.onClear,
    required this.symbol,
    required this.onPickAsset,
    this.radius = 12,
    this.contentPad = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: FormStyles.inputDecoration(
        context,
        label: label,
        radius: radius,
        contentPadding: contentPad,
      ).copyWith(
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // clear icon
            IconButton(
              tooltip: 'Clear',
              icon: Icon(LucideIcons.x, size: 18, color: c.textSecondary),
              onPressed: onClear,
            ),
            // divider
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: c.border.withOpacity(.45),
            ),
            // asset badge with dropdown
            _AssetToggle(symbol: symbol, onPick: onPickAsset),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _AssetToggle extends StatelessWidget {
  final String symbol;
  final ValueChanged<String> onPick;

  const _AssetToggle({required this.symbol, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Change input unit',
      position: PopupMenuPosition.under,
      onSelected: onPick,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'XLM',
          child: Row(
            children: [
              AssetLogo(keyOrSymbol: 'XLM', size: 18),
              SizedBox(width: 8),
              Text('XLM'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'USDC',
          child: Row(
            children: [
              AssetLogo(keyOrSymbol: 'USDC', size: 18),
              SizedBox(width: 8),
              Text('USDC'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border.withOpacity(.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetLogo(keyOrSymbol: symbol, size: 18),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronDown, size: 16, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}
