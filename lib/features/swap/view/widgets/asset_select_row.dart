import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/features/swap/view/widgets/form_style.dart';

class AssetSelectRow extends StatelessWidget {
  final bool isXlmToUsdc;
  final VoidCallback onFlip;
  final Future<void> Function(bool fromIsXLM) onChange;
  final double radius;
  final EdgeInsets contentPad;

  const AssetSelectRow({
    super.key,
    required this.isXlmToUsdc,
    required this.onFlip,
    required this.onChange,
    this.radius = 12,
    this.contentPad = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final fromAsset = isXlmToUsdc ? 'XLM' : 'USDC';
    final toAsset = isXlmToUsdc ? 'USDC' : 'XLM';
    return Row(
      children: [
        Expanded(
          child: _AssetDropdown(
            label: 'Send',
            value: fromAsset,
            radius: radius,
            contentPad: contentPad,
            onChanged: (v) async {
              if (v == null) return;
              final fromIsXLM = v == 'XLM';
              await onChange(fromIsXLM);
            },
          ),
        ),
        const SizedBox(width: 8),
        _SwapIconButton(onFlip: onFlip),
        const SizedBox(width: 8),
        Expanded(
          child: _AssetDropdown(
            label: 'Receive',
            value: toAsset,
            radius: radius,
            contentPad: contentPad,
            onChanged: (v) async {
              if (v == null) return;
              // choosing receive XLM means from USDC
              final fromIsXLM = v == 'USDC';
              await onChange(fromIsXLM);
            },
          ),
        ),
      ],
    );
  }
}

class _AssetDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String?> onChanged;
  final double radius;
  final EdgeInsets contentPad;

  const _AssetDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.radius,
    required this.contentPad,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: FormStyles.inputDecoration(
        context,
        label: label,
        radius: radius,
        contentPadding: contentPad,
      ),
      icon: Icon(LucideIcons.chevronDown, size: 18, color: c.textSecondary),
      onChanged: onChanged,
      items: const [
        DropdownMenuItem(value: 'XLM', child: _AssetLogoItem(symbol: 'XLM')),
        DropdownMenuItem(value: 'USDC', child: _AssetLogoItem(symbol: 'USDC')),
      ],
    );
  }
}

class _AssetLogoItem extends StatelessWidget {
  final String symbol;
  const _AssetLogoItem({required this.symbol});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Row(
      children: [
        AssetLogo(keyOrSymbol: symbol, size: 18),
        const SizedBox(width: 8),
        Text(symbol, style: TextStyle(color: c.textPrimary)), // not bold
      ],
    );
  }
}

class _SwapIconButton extends StatelessWidget {
  final VoidCallback onFlip;
  const _SwapIconButton({required this.onFlip});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return InkResponse(
      onTap: onFlip,
      radius: 24,
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border.withOpacity(.35)),
        ),
        alignment: Alignment.center,
        child: const Icon(LucideIcons.arrowLeftRight, size: 18),
      ),
    );
  }
}
