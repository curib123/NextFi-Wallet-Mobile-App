import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/AppColor.dart';

/* ======================= Compact, reusable widgets ======================= */

class PageLoader extends StatelessWidget {
  const PageLoader({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.only(top: 60),
      child: SizedBox(height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.error.withOpacity(0.2)),
        ),
        child: Text(message, style: TextStyle(color: c.error)),
      ),
    );
  }
}

class BalanceRow extends StatelessWidget {
  final double trx, usdt;
  const BalanceRow({super.key, required this.trx, required this.usdt});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    Widget chip(String label, String value, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.14)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: c.primary),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        Text(value, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
      ]),
    );

    String _num(double v) => v.toStringAsFixed(v >= 100 ? 2 : 4);

    return Row(
      children: [
        Expanded(child: chip('TRX', _num(trx), LucideIcons.triangle)),
        const SizedBox(width: 8),
        Expanded(child: chip('USDT', _num(usdt), LucideIcons.banknote)),
      ],
    );
  }
}

class DirectionSegmented extends StatelessWidget {
  final bool isTrxToUsdt;
  final VoidCallback onFlip;
  final AnimationController controller;
  const DirectionSegmented({
    super.key,
    required this.isTrxToUsdt,
    required this.onFlip,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegBtn(
              active: isTrxToUsdt,
              label: 'TRX → USDT',
              onTap: () {
                if (!isTrxToUsdt) onFlip();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegBtn(
              active: !isTrxToUsdt,
              label: 'USDT → TRX',
              onTap: () {
                if (isTrxToUsdt) onFlip();
              },
            ),
          ),
          const SizedBox(width: 6),
          RotationTransition(
            turns: Tween(begin: 0.0, end: 0.5).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut)),
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onFlip,
              icon: Icon(LucideIcons.arrowUpDown, color: c.primary),
              tooltip: 'Flip',
            ),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;
  const _SegBtn({required this.active, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class AmountField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onUseMax;
  final void Function(double pct) onPct;
  final AppColor colors;
  const AmountField({
    super.key,
    required this.label,
    required this.controller,
    required this.onUseMax,
    required this.onPct,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    Widget pct(String t, double v) => TextButton(
      onPressed: () => onPct(v),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        foregroundColor: c.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}$'))],
            decoration: InputDecoration(
              hintText: '0.0',
              filled: true,
              fillColor: c.primary.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.primary.withOpacity(0.15))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.primary, width: 1.2)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onUseMax,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: c.primary.withOpacity(0.35)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            minimumSize: const Size(52, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('MAX', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 6),
      Row(
        children: [
          pct('25%', 0.25),
          pct('50%', 0.50),
          pct('75%', 0.75),
          pct('100%', 1.00),
        ],
      ),
    ]);
  }
}

class MinReceiveRow extends StatelessWidget {
  final bool enabled;
  final TextEditingController valueCtl;
  final double slippage;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onSlippage;
  final String toSymbol;
  final AppColor colors;
  const MinReceiveRow({
    super.key,
    required this.enabled,
    required this.valueCtl,
    required this.slippage,
    required this.onToggle,
    required this.onSlippage,
    required this.toSymbol,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Switch.adaptive(value: enabled, onChanged: onToggle, activeColor: c.primary),
          const SizedBox(width: 6),
          Text('Min receive', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (enabled)
            SizedBox(
              width: 160,
              child: TextField(
                controller: valueCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}$'))],
                decoration: InputDecoration(
                  hintText: '0.0 $toSymbol',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ]),
        if (enabled) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(LucideIcons.zap, size: 16, color: c.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Slider(
                value: slippage,
                min: 0.1,
                max: 5.0,
                divisions: 49,
                label: '${slippage.toStringAsFixed(1)}%',
                onChanged: onSlippage,
                activeColor: c.primary,
              ),
            ),
          ]),
        ],
      ],
    );
  }
}

class FeeRow extends StatelessWidget {
  final bool auto;
  final double feeTrx;
  final double min, max;
  final ValueChanged<bool> onMode;     // pass true => auto, false => custom
  final ValueChanged<double> onChange; // slider (custom)
  final AppColor colors;
  const FeeRow({
    super.key,
    required this.auto,
    required this.feeTrx,
    required this.min,
    required this.max,
    required this.onMode,
    required this.onChange,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Row(children: [
            Text('Network fee limit', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(auto ? 'Auto (5 TRX)' : '${feeTrx.toStringAsFixed(0)} TRX', style: TextStyle(color: c.textSecondary)),
            const SizedBox(width: 6),
            // Toggle only to switch modes; default (auto=5 TRX) works even untouched
            Switch.adaptive(value: auto, onChanged: onMode, activeColor: c.primary),
          ]),
          if (!auto) ...[
            const SizedBox(height: 6),
            Slider(
              value: feeTrx.clamp(min, max),
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              label: '${feeTrx.toStringAsFixed(0)} TRX',
              onChanged: onChange,
              activeColor: c.primary,
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [5, 10, 20, 40, 60].map((v) {
                return InkWell(
                  onTap: () => onChange(v.toDouble()),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.border),
                    ),
                    child: Text('$v TRX', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String from, to;
  final double amount;
  final double? minOut;
  final String feeText;
  final AppColor colors;
  final NumberFormat fmt;
  const SummaryCard({
    super.key,
    required this.from,
    required this.to,
    required this.amount,
    required this.minOut,
    required this.feeText,
    required this.colors,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          SummaryRow(label: 'Route', value: '$from → $to'),
          SummaryRow(label: 'Amount', value: '${fmt.format(amount)} $from'),
          if (minOut != null) SummaryRow(label: 'Min receive', value: '${fmt.format(minOut)} $to'),
          SummaryRow(label: 'Fee limit', value: feeText),
        ],
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const SummaryRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
          Expanded(
              child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
