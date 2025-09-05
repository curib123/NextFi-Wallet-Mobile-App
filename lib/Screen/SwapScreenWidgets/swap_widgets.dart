import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/AssetProvider.dart';

/* ===================== Common widgets for Swap ===================== */

class PageLoader extends StatelessWidget {
  const PageLoader({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()),
  );
}

class ErrorStateCard extends StatelessWidget {
  const ErrorStateCard({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.alertTriangle, size: 42, color: colors.warning),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: colors.textPrimary)),
        ]),
      ),
    );
  }
}

class WalletCard extends StatelessWidget {
  const WalletCard({super.key, required this.trx, required this.usdt});
  final double trx;
  final double usdt;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final fmt = NumberFormat('#,##0.######');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(child: BalanceTile(label: 'TRX', value: fmt.format(trx), assetKey: 'tron')),
          const SizedBox(width: 10),
          Expanded(child: BalanceTile(label: 'USDT', value: fmt.format(usdt), assetKey: 'tether_trc20')),
        ],
      ),
    );
  }
}

class BalanceTile extends StatelessWidget {
  const BalanceTile({super.key, required this.label, required this.value, required this.assetKey});
  final String label;
  final String value;
  final String assetKey;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          AssetLogo(assetKey: assetKey, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DirectionPill extends StatelessWidget {
  const DirectionPill({
    super.key,
    required this.isTrxToUsdt,
    required this.onTapTRXtoUSDT,
    required this.onTapUSDTtoTRX,
  });

  final bool isTrxToUsdt;
  final VoidCallback onTapTRXtoUSDT;
  final VoidCallback onTapUSDTtoTRX;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    Widget pill({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? colors.primary : colors.surface,
                border: Border.all(color: selected ? colors.primary : colors.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(
          label: 'Swap to USDT',
          selected: isTrxToUsdt,
          onTap: onTapTRXtoUSDT,
        ),
        const SizedBox(width: 10),
        pill(
          label: 'Swap to TRX',
          selected: !isTrxToUsdt,
          onTap: onTapUSDTtoTRX,
        ),
      ],
    );
  }
}

class SwapCard extends StatelessWidget {
  const SwapCard({
    super.key,
    required this.fromSymbol,
    required this.toSymbol,
    required this.amountCtl,
    required this.minOutCtl,
    required this.slippage,
    required this.useMinGuard,
    required this.fromBalance,
    required this.hasEnoughBalance,
    required this.onToggleMinGuard,
    required this.onSlippageChanged,
    required this.onFlip,
    required this.onUseMax,
    required this.onQuickPercent,
  });

  final String fromSymbol;
  final String toSymbol;
  final TextEditingController amountCtl;
  final TextEditingController minOutCtl;
  final double slippage;
  final bool useMinGuard;
  final double fromBalance;
  final bool hasEnoughBalance;
  final ValueChanged<bool> onToggleMinGuard;
  final ValueChanged<double> onSlippageChanged;
  final VoidCallback onFlip;
  final VoidCallback onUseMax;
  final void Function(double p) onQuickPercent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          // From amount
          LabeledField(
            label: 'You pay ($fromSymbol)',
            hint: '0.0',
            icon: LucideIcons.keyboard,
            controller: amountCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            trailing: TextButton(onPressed: onUseMax, child: const Text('MAX')),
            validatorHint: _buildValidatorHint(context, hasEnoughBalance, fromSymbol),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}$')),
            ],
          ),

          // Quick chips
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                QuickChip(percent: 0.25, onTap: () => onQuickPercent(0.25)),
                QuickChip(percent: 0.50, onTap: () => onQuickPercent(0.50)),
                QuickChip(percent: 0.75, onTap: () => onQuickPercent(0.75)),
                QuickChip(label: 'MAX', onTap: onUseMax),
              ],
            ),
          ),

          // Available & swap button
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Available: ${fromBalance.toStringAsFixed(6)} $fromSymbol',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ),
              InkWell(
                onTap: onFlip,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.primary.withOpacity(0.25)),
                  ),
                  child: Icon(LucideIcons.arrowUpDown, size: 18, color: colors.primary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Toggle: Slippage guard (Min receive)
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 18, color: colors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Slippage guard (Min receive)',
                    style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
              ),
              Switch(value: useMinGuard, onChanged: onToggleMinGuard),
            ],
          ),

          if (useMinGuard) ...[
            const SizedBox(height: 8),
            LabeledField(
              label: 'Min receive ($toSymbol)',
              hint: '0.0',
              icon: LucideIcons.checkCircle2,
              controller: minOutCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}$')),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Slippage slider
          SlippageSection(value: slippage, onChanged: onSlippageChanged),
        ],
      ),
    );
  }

  Widget? _buildValidatorHint(BuildContext context, bool ok, String from) {
    final colors = AppColor.of(context);
    if (ok) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle, size: 14, color: colors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              from == 'TRX'
                  ? 'Not enough TRX to cover amount and fee limit.'
                  : 'Not enough $from balance.',
              style: TextStyle(color: colors.warning, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.trailing,
    this.validatorHint,
    this.inputFormatters,
  });
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final Widget? validatorHint;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hint,
            filled: true,
            fillColor: colors.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        if (validatorHint != null) validatorHint!,
      ],
    );
  }
}

class SlippageSection extends StatelessWidget {
  const SlippageSection({super.key, required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Slippage tolerance', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Slider(
                value: value,
                min: 0.1,
                max: 5.0,
                divisions: 49,
                label: '${value.toStringAsFixed(1)}%',
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '${value.toStringAsFixed(1)}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Tip: Keep slippage low for safety. If your swap keeps failing, raise it slightly.',
            style: TextStyle(color: colors.textSecondary, fontSize: 10, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/* ------------- Fee section ------------- */
// Shows guidance ONLY when Custom is active (feeAuto == false)
class FeeSection extends StatelessWidget {
  const FeeSection({
    super.key,
    required this.isTrxToUsdt,
    required this.feeAuto,
    required this.feeLimitTrx,
    required this.minFeeTrx,
    required this.maxFeeTrx,
    required this.trxBalance,
    required this.currentAmountTrx,
    required this.onModeChanged,
    required this.onFeeChanged,
    this.autoDefaultTrx = 5.0, // NEW: default auto fee label helper
  });

  final bool isTrxToUsdt;
  final bool feeAuto;
  final double feeLimitTrx;
  final double minFeeTrx;
  final double maxFeeTrx;
  final double trxBalance;
  final double currentAmountTrx;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<double> onFeeChanged;
  final double autoDefaultTrx;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final effectiveFee = feeAuto ? autoDefaultTrx : feeLimitTrx;
    final dust = 0.1;
    final willExceed =
    isTrxToUsdt ? (currentAmountTrx + effectiveFee + dust) > trxBalance + 1e-9 : false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.gauge, color: colors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Network Fee Limit',
                style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700),
              ),
            ),
                Switch(value: !feeAuto, onChanged: (v) => onModeChanged(!v)),

          ]),
          const SizedBox(height: 10),

          // Only show guides when Custom is active
          if (!feeAuto) ...[
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: feeLimitTrx.clamp(minFeeTrx, maxFeeTrx),
                    min: minFeeTrx,
                    max: maxFeeTrx,
                    divisions: (maxFeeTrx - minFeeTrx).round(),
                    label: '${feeLimitTrx.toStringAsFixed(0)} TRX',
                    onChanged: onFeeChanged,
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${feeLimitTrx.toStringAsFixed(0)}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('TRX', style: TextStyle(color: colors.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                TextChip(label: '5 TRX', onTap: () => onFeeChanged(5)),
                TextChip(label: '10 TRX', onTap: () => onFeeChanged(10)),
                TextChip(label: '20 TRX', onTap: () => onFeeChanged(20)),
                TextChip(label: '40 TRX', onTap: () => onFeeChanged(40)),
                TextChip(label: '60 TRX', onTap: () => onFeeChanged(60)),
              ],
            ),
            const SizedBox(height: 8),
            InfoRow(
              icon: LucideIcons.info,
              text: isTrxToUsdt
                  ? 'Max spend = amount + fee limit. Unused fee is not charged.'
                  : 'Fee is paid in TRX only; your USDT input is unaffected by the fee limit.',
            ),
          ],

          // Warning is not a "guide"—keep it visible always when applicable
          if (willExceed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.warning.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertTriangle, size: 16, color: colors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Insufficient TRX for amount + fee limit. Lower the fee limit or amount.',
                      style: TextStyle(color: colors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.isTrxToUsdt,
    required this.amount,
    required this.minOut,
    required this.feeTrx,
    required this.feeAuto,
  });

  final bool isTrxToUsdt;
  final double amount;
  final double? minOut;
  final double feeTrx;
  final bool feeAuto;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final from = isTrxToUsdt ? 'TRX' : 'USDT';
    final to = isTrxToUsdt ? 'USDT' : 'TRX';
    final maxSpend = isTrxToUsdt ? (amount + feeTrx) : null;

    Widget row(String l, String r, {Color? color, IconData? icon}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: colors.textSecondary),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text(l, style: TextStyle(color: colors.textSecondary))),
            Text(r, style: TextStyle(color: color ?? colors.textPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: TextStyle(fontWeight: FontWeight.w800, color: colors.textPrimary)),
          const SizedBox(height: 8),
          row('You pay', '${amount.toStringAsFixed(6)} $from', icon: LucideIcons.wallet),
          row('Min receive', minOut == null ? '—' : '${minOut!.toStringAsFixed(6)} $to',
              icon: LucideIcons.badgeCheck),
          row('Fee limit', '${feeAuto ? 'Auto' : 'Custom'} (${feeTrx.toStringAsFixed(0)} TRX)',
              icon: LucideIcons.gauge),
          if (maxSpend != null)
            row('Max TRX spend', '${maxSpend.toStringAsFixed(6)} TRX',
                icon: LucideIcons.database, color: colors.textPrimary),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: colors.textSecondary, fontSize: 12))),
      ],
    );
  }
}

class QuickChip extends StatelessWidget {
  const QuickChip({super.key, this.percent, this.label, required this.onTap});
  final double? percent;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final display = label ?? '${(percent! * 100).toStringAsFixed(0)}%';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          display,
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class TextChip extends StatelessWidget {
  const TextChip({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.border),
        ),
        child: Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.info.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(LucideIcons.info, color: colors.info),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colors.textSecondary, height: 1.25),
          ),
        ),
      ]),
    );
  }
}

/* ===================== Logo helpers (AssetProvider) ===================== */

class AssetLogo extends StatefulWidget {
  const AssetLogo({super.key, required this.assetKey, this.size = 24, this.invert = false});
  final String assetKey; // 'tron' or 'tether_trc20'
  final double size;
  final bool invert; // when pill is selected (white text), keep logo visible
  @override
  State<AssetLogo> createState() => _AssetLogoState();
}

class _AssetLogoState extends State<AssetLogo> {
  int _idx = 0;
  late List<String> _urls;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logos = context.read<AssetProvider>();
    final first = logos.logoFor(widget.assetKey);
    final isUsdt = widget.assetKey.toLowerCase().contains('usdt') ||
        widget.assetKey.toLowerCase().contains('tether');
    _urls = [
      first,
      if (isUsdt) ...AssetProvider.usdtLogoFallbacks,
    ];
    _idx = 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final size = widget.size;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        color: widget.invert ? Colors.white.withOpacity(0.9) : Colors.transparent,
        child: Image.network(
          _urls[_idx],
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          frameBuilder: (ctx, child, frame, _) {
            if (frame == null) {
              return Center(
                child: SizedBox(
                  width: size * .5,
                  height: size * .5,
                  child: const CircularProgressIndicator(strokeWidth: 1.6),
                ),
              );
            }
            return child;
          },
          errorBuilder: (ctx, err, stack) {
            if (_idx + 1 < _urls.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _idx++));
              return const SizedBox.shrink();
            }
            // ultimate fallback: colored circle with first letter
            final letter = widget.assetKey.toUpperCase().startsWith('T') ? 'T' : 'U';
            return Container(
              color: widget.invert ? Colors.white : colors.primary.withOpacity(0.12),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: size * .5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
