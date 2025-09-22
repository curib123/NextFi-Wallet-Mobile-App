import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/features/swap/view/widgets/info_row.dart';
import 'package:next_fi/features/swap/view_model/swap_vm.dart';

/// Shows a live-updating Market confirmation sheet that LISTENS to SwapVM.
/// Returns the *current* minOutPreFee (double) if the user confirms; null if cancelled.
Future<double?> showConfirmMarketSheet(
    BuildContext context, {
      required NumberFormat fmt,
    }) async {
  final colors = AppColor.of(context);

  // Prime fee stream if needed — keeps VM logic in one place, UI stays lean.
  final vm = context.read<SwapVM>();
  if (!vm.hasFeeEstimates) {
    await vm.refreshBalances();
  }

  return await showModalBottomSheet<double?>(
    context: context,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    builder: (sheetCtx) {
      final vmLive = sheetCtx.watch<SwapVM>();
      final sLive  = vmLive.state;

      final estOutLive = sLive.estReceive;
      final minOutPreFeeLive = vmLive.currentMinOutPreFee ??
          (estOutLive != null ? estOutLive * (1 - vmLive.slippagePct) : null);
      final minAfterFeesLive = vmLive.currentMinOutAfterFees ?? minOutPreFeeLive ?? 0.0;

      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // drag handle
          Container(
            width: 34, height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colors.textSecondary.withOpacity(0.20),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Text(
            'Confirm swap',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 10),

          InfoRow('From', '${fmt.format(vmLive.amount)} ${sLive.isXlmToUsdc ? 'XLM' : 'USDC'}'),
          if (estOutLive != null)
            InfoRow('To (est.)', '${fmt.format(estOutLive)} ${sLive.isXlmToUsdc ? 'USDC' : 'XLM'}'),
          InfoRow('Slippage', _fmtPct(vmLive.slippagePct)),

          InfoRow(
            'Est. minimum receive',
            '${fmt.format(minAfterFeesLive)} ${sLive.isXlmToUsdc ? 'USDC' : 'XLM'}',
          ),
          InfoRow(
            'Est. transaction fee',
            vmLive.hasFeeEstimates
                ? '≈ ${fmt.format(vmLive.estCombinedFeeXlm)} XLM'
                '${sLive.needsTrustline ? '  · includes trustline' : ''}'
                : 'Calculating…',
          ),

          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: CustomButton(
                type: ButtonType.outlined,
                icon: Icons.cancel_rounded,
                text: "Cancel",
                onPressed: () => Navigator.pop(sheetCtx, null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CustomButton(
                icon: LucideIcons.check,
                text: "Swap Now",
                onPressed: () {
                  Navigator.pop(sheetCtx, (minOutPreFeeLive ?? 0.0));
                },
              ),
            ),
          ]),
        ]),
      );
    },
  );
}

/// Shows a live-updating Limit order confirmation sheet.
/// Returns true if confirmed; null/false if cancelled.
Future<bool?> showConfirmLimitSheet(
    BuildContext context, {
      required NumberFormat fmt,
      required double price, // USDC per 1 XLM
    }) async {
  final colors = AppColor.of(context);

  return await showModalBottomSheet<bool?>(
    context: context,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    builder: (sheetCtx) {
      final vmLive = sheetCtx.watch<SwapVM>();
      final isXlmToUsdc = vmLive.state.isXlmToUsdc;
      final side = isXlmToUsdc ? 'Sell XLM' : 'Buy XLM';

      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34, height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colors.textSecondary.withOpacity(0.20),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Text(
            'Place limit order',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 10),

          InfoRow('Side', side),
          InfoRow('Amount (from)', '${fmt.format(vmLive.amount)} ${isXlmToUsdc ? 'XLM' : 'USDC'}'),
          InfoRow('Limit price', '${fmt.format(price)} USDC per 1 XLM'),
          const InfoRow('Order type', 'Good-till-cancel (per backend policy)'),

          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: CustomButton(
                type: ButtonType.outlined,
                icon: Icons.cancel_rounded,
                text: "Cancel",
                onPressed: () => Navigator.pop(sheetCtx, false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CustomButton(
                icon: LucideIcons.check,
                text: "Place Order",
                onPressed: () => Navigator.pop(sheetCtx, true),
              ),
            ),
          ]),
        ]),
      );
    },
  );
}

/// Shows a live-updating Schedule confirmation sheet.
/// Returns true if confirmed; null/false if cancelled.
Future<bool?> showConfirmScheduleSheet(
    BuildContext context, {
      required NumberFormat fmt,
      required DateTime? start,
      required DateTime? end,
    }) async {
  final colors = AppColor.of(context);

  final window =
      '${_fmtDateTimeLocal(start)} → ${_fmtDateTimeLocal(end)}';

  return await showModalBottomSheet<bool?>(
    context: context,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    builder: (sheetCtx) {
      final vmLive = sheetCtx.watch<SwapVM>();
      final isXlmToUsdc = vmLive.state.isXlmToUsdc;

      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34, height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colors.textSecondary.withOpacity(0.20),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Text(
            'Schedule swap',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 10),

          InfoRow('Window', window),
          InfoRow('From', '${fmt.format(vmLive.amount)} ${isXlmToUsdc ? 'XLM' : 'USDC'}'),
          const InfoRow('Execution', 'Market price during window'),

          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: CustomButton(
                type: ButtonType.outlined,
                icon: Icons.cancel_rounded,
                text: "Cancel",
                onPressed: () => Navigator.pop(sheetCtx, false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CustomButton(
                icon: LucideIcons.check,
                text: "Schedule",
                onPressed: () => Navigator.pop(sheetCtx, true),
              ),
            ),
          ]),
        ]),
      );
    },
  );
}

// ── helpers ──────────────────────────────────────────────────────────────────
String _fmtPct(double frac) {
  final p = frac * 100;
  return (p % 1 == 0) ? '${p.toStringAsFixed(0)}%' : '${p.toStringAsFixed(1)}%';
}

String _fmtDateTimeLocal(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  // yyyy-MM-dd HH:mm (24h) keeps it compact and stable
  final two = (int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
