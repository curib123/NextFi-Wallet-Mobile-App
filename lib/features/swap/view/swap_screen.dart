// lib/features/swap/view/swap_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/features/swap/view/widgets/balance_row.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';

import 'package:next_fi/features/send/view/widgets/error_card.dart';
import 'package:next_fi/features/send/view/widgets/page_loader.dart';
import 'package:next_fi/features/send/view/widgets/percent_chips_row.dart';

import 'package:next_fi/features/swap/view/widgets/amount_field.dart';
import 'package:next_fi/features/swap/view/widgets/direction_switcher.dart';
import 'package:next_fi/features/swap/view/widgets/hint_box.dart';
import 'package:next_fi/features/swap/view/widgets/info_row.dart';
import 'package:next_fi/features/swap/view/widgets/section_card.dart';
import 'package:next_fi/features/swap/view/widgets/tiny_info_row.dart';

import 'package:next_fi/features/swap/view_model/swap_vm.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final _amountCtl = TextEditingController();
  final _fmt = NumberFormat('#,##0.######');
  bool _started = false;

  // Prevent loops when syncing TextField ⇄ VM after VM clamps amount.
  bool _syncingText = false;

  @override
  void initState() {
    super.initState();
    _amountCtl.addListener(() async {
      if (_syncingText) return;
      final vm = context.read<SwapVM>();
      final raw = _amountCtl.text;
      await vm.onAmountChanged(raw);

      // After VM may clamp, mirror back to field if needed
      final parsed = double.tryParse(raw.replaceAll(',', '').trim()) ?? 0.0;
      if ((parsed - vm.amount).abs() > 1e-9) {
        _syncingText = true;
        try {
          final fixed = _tight(vm.amount);
          _amountCtl.text = vm.amount <= 0 ? '' : fixed;
          _amountCtl.selection = TextSelection.fromPosition(
            TextPosition(offset: _amountCtl.text.length),
          );
        } finally {
          _syncingText = false;
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SwapVM>().start(); // idempotent
    });
    _started = true;
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  String _tight(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  String _fmtPct(double frac) {
    final p = frac * 100;
    return (p % 1 == 0) ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
  }

  Future<void> _onApplyPercent(SwapVM vm, double percent) async {
    HapticFeedback.selectionClick();
    final newAmt = await vm.applyPercent(percent);
    _syncingText = true;
    try {
      _amountCtl.text = newAmt <= 0 ? '' : _tight(newAmt);
      _amountCtl.selection = TextSelection.fromPosition(
        TextPosition(offset: _amountCtl.text.length),
      );
    } finally {
      _syncingText = false;
    }
  }

  Future<void> _onFlip(SwapVM vm) async {
    HapticFeedback.lightImpact();
    final adjusted = await vm.flipDirectionAndRequote();
    _syncingText = true;
    try {
      _amountCtl.text = adjusted <= 0 ? '' : _tight(adjusted);
      _amountCtl.selection = TextSelection.fromPosition(
        TextPosition(offset: _amountCtl.text.length),
      );
    } finally {
      _syncingText = false;
    }
  }

  Future<void> _confirmAndSwap(SwapVM vm) async {
    final s = vm.state;

    if (!vm.hasAmount) return; // disabled state should prevent this
    if (!vm.canSwap) {
      showFloatingSnackBar(context, message: 'Insufficient balance', type: SnackBarType.error);
      return;
    }

    // Fresh quote if needed
    final estOut = s.estReceive ?? await vm.updateQuote(vm.amount);
    if (estOut == null) {
      showFloatingSnackBar(context, message: 'No price quote available. Try a different amount.', type: SnackBarType.error);
      return;
    }

    // Pre-fee minOut for on-chain path
    final minOutPreFee = vm.currentMinOutPreFee ?? (estOut * (1 - vm.slippagePct));

    // For user display: after-fee min receive (VM already knows direction rules)
    final minAfterFees = vm.currentMinOutAfterFees ?? minOutPreFee;

    final colors = AppColor.of(context);

    // right before showModalBottomSheet
    if (context.read<SwapVM>().hasFeeEstimates == false) {
      // No-op if already wired; VM will ignore.
      await context.read<SwapVM>().refreshBalances();
    }


    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (sheetCtx) {
        // 👇 listening read; this rebuilds when VM notifies (fees/quotes update)
        final vmLive = sheetCtx.watch<SwapVM>();
        final sLive  = vmLive.state;

        final estOutLive = sLive.estReceive ?? estOut; // keep the earlier estOut as fallback
        final minOutPreFeeLive =
            vmLive.currentMinOutPreFee ?? (estOutLive != null ? estOutLive * (1 - vmLive.slippagePct) : null);
        final minAfterFeesLive = vmLive.currentMinOutAfterFees ?? minOutPreFeeLive ?? 0.0;

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
            Text('Confirm swap',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary, letterSpacing: .2),
            ),
            const SizedBox(height: 10),

            InfoRow('From', '${_fmt.format(vmLive.amount)} ${sLive.isXlmToUsdc ? 'XLM' : 'USDC'}'),
            if (estOutLive != null)
              InfoRow('To (est.)', '${_fmt.format(estOutLive)} ${sLive.isXlmToUsdc ? 'USDC' : 'XLM'}'),
            InfoRow('Slippage', '${_fmtPct(vmLive.slippagePct)}%'),

            InfoRow(
              'Est. minimum receive',
              '${_fmt.format(minAfterFeesLive)} ${sLive.isXlmToUsdc ? 'USDC' : 'XLM'}',
            ),
            InfoRow(
              'Est. transaction fee',
              vmLive.hasFeeEstimates
                  ? '≈ ${_fmt.format(vmLive.estCombinedFeeXlm)} XLM'
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
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomButton(
                  icon: LucideIcons.check,
                  text: "Swap Now",
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    await _doSwap(vmLive, vmLive.amount, minOutPreFeeLive ?? 0);
                  },
                ),
              ),
            ]),
          ]),
        );
      },
    );

  }

  Future<void> _doSwap(SwapVM vm, double amount, double minOutPreFee) async {
    final ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Submitting swap…',
      subtitle: vm.state.isXlmToUsdc
          ? 'Swapping ${_fmt.format(amount)} XLM → ≥ ${_fmt.format(minOutPreFee)} USDC'
          : 'Swapping ${_fmt.format(amount)} USDC → ≥ ${_fmt.format(minOutPreFee)} XLM',
      primaryText: 'Hide',
      barrierDismissible: true,
    );

    try {
      final txid = await vm.executeSwap(amount: amount, minOut: minOutPreFee);
      if (!mounted) return;
      HapticFeedback.mediumImpact();

      ctl.update(
        AppAlertType.success,
        title: 'Swap submitted',
        subtitle: txid,
        primaryText: 'Copy TxID',
        onPrimary: () async {
          await Clipboard.setData(ClipboardData(text: txid));
          ctl.close();
        },
      );

      // Clear text + VM
      await vm.setAmount(0.0);
      _syncingText = true;
      try {
        _amountCtl.clear();
      } finally {
        _syncingText = false;
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      ctl.update(
        AppAlertType.error,
        title: 'Swap failed',
        subtitle: msg.length > 220 ? '${msg.substring(0, 220)}…' : msg,
        primaryText: 'OK',
        onPrimary: () => ctl.close(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<SwapVM>();
    final s = vm.state;

    final hasAmount = vm.hasAmount;
    final canSwap = vm.canSwap;

    // If VM clamped amount due to streams/balance changes, mirror back to field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _syncingText) return;
      final raw = _amountCtl.text.trim();
      final parsed = double.tryParse(raw.replaceAll(',', '')) ?? 0.0;
      if ((parsed - vm.amount).abs() > 1e-9) {
        _syncingText = true;
        try {
          _amountCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
          _amountCtl.selection = TextSelection.fromPosition(
            TextPosition(offset: _amountCtl.text.length),
          );
        } finally {
          _syncingText = false;
        }
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.background,
        titleSpacing: 20,
        title: const Text('Swap'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: () async {
              HapticFeedback.selectionClick();
              await vm.refreshBalances();
              if (vm.amount > 0) await vm.updateQuote(vm.amount);
            },
          ),
        ],
      ),
      body: (s.loading && s.accountId == null)
          ? const PageLoader()
          : (s.error != null && s.error!.isNotEmpty)
          ? ErrorCard(message: s.error!)
          : RefreshIndicator(
        onRefresh: () async {
          await vm.refreshBalances();
          if (vm.amount > 0) await vm.updateQuote(vm.amount);
        },
        color: colors.primary,
        backgroundColor: colors.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SizedBox(height: 6),
            BalanceRow(
              xlm: s.xlmBal,
              usdc: s.usdcBal,
              numberFormat: NumberFormat('#,##0.####'),
            ),
            const SizedBox(height: 8),

            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  DirectionSwitcher(
                    isXlmToUsdc: s.isXlmToUsdc,
                    onFlip: () => _onFlip(vm),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AmountField(label: 'Amount', controller: _amountCtl),
                  const SizedBox(height: 8),
                  PercentChipsRow(onPick: (pct) => _onApplyPercent(vm, pct)),
                  const SizedBox(height: 10),
                  Slider(
                    value: vm.slippagePct,
                    min: SwapVM.slippageMin,
                    max: SwapVM.slippageMax,
                    divisions: 45, // 0.1% steps
                    label: '${_fmtPct(vm.slippagePct)}%',
                    onChanged: (v) => vm.setSlippagePct(v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Slippage tolerance',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: colors.textSecondary,
                            letterSpacing: .2,
                          )),
                      Text('${_fmtPct(vm.slippagePct)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          )),
                    ],
                  ),
                  if (s.isXlmToUsdc) ...[
                    const SizedBox(height: 8),
                    const HintBox(
                      text: 'We keep ~1 XLM for fees & reserve. Use the quick chips for a safe prefill.',
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    const HintBox(
                      text: 'Stellar fees are paid in XLM. Swapping a small amount to XLM first ensures you can send and swap smoothly.',
                    ),
                  ]

                ],
              ),
            ),

            const SizedBox(height: 8),

          ],
        ),
      ),
      bottomNavigationBar: (s.loading && s.accountId == null) || (s.error != null && s.error!.isNotEmpty)
          ? null
          : SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: s.isXlmToUsdc ? 'Swap XLM → USDC' : 'Swap USDC → XLM',
              icon: LucideIcons.arrowRightLeft,
              type: !hasAmount ? ButtonType.disabled : ButtonType.filled,
              onPressed: !hasAmount
                  ? () {} // won't be called; button is disabled by type
                  : (canSwap
                  ? () => _confirmAndSwap(vm)
                  : () {
                HapticFeedback.selectionClick();
                showFloatingSnackBar(
                  context,
                  message: 'Insufficient balance',
                  type: SnackBarType.error,
                );
              }),
              // fullWidth defaults to true; omit or set explicitly if you like:
              // fullWidth: true,
            )

          ),
        ),
      ),
    );
  }
}
