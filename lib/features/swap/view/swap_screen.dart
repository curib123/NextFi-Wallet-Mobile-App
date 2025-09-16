// lib/features/swap/view/swap_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/AppAlert.dart';
import 'package:next_fi/common/components/SnackBar.dart';
import 'package:next_fi/features/send/view/widgets/error_card.dart';
import 'package:next_fi/features/send/view/widgets/page_loader.dart';
import 'package:next_fi/features/send/view/widgets/percent_chips_row.dart';
import 'package:next_fi/features/swap/view/widgets/amount_field.dart';
import 'package:next_fi/features/swap/view/widgets/balance_row.dart' show BalanceRow;
import 'package:next_fi/features/swap/view/widgets/card_header.dart';
import 'package:next_fi/features/swap/view/widgets/direction_switcher.dart';
import 'package:next_fi/features/swap/view/widgets/hint_box.dart';
import 'package:next_fi/features/swap/view/widgets/info_row.dart';
import 'package:next_fi/features/swap/view/widgets/section_card.dart';
import 'package:next_fi/features/swap/view/widgets/tiny_info_row.dart';
import 'package:next_fi/features/swap/view_model/swap_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/AppColor.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final _amountCtl = TextEditingController();
  final _fmt = NumberFormat('#,##0.######');
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Let the VM own the logic; UI forwards raw input.
    _amountCtl.addListener(() {
      final vm = context.read<SwapVM>();
      vm.onAmountChanged(_amountCtl.text);
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

  // ─── small UI helpers ──────────────────────────────────────────────────────
  String _fmtAmountTight(double v, {int decimals = 7}) {
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
    _amountCtl.text = newAmt <= 0 ? '' : _fmtAmountTight(newAmt);
    _amountCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountCtl.text.length),
    );
  }

  Future<void> _onFlip(SwapVM vm) async {
    HapticFeedback.lightImpact();
    final adjusted = await vm.flipDirectionAndRequote();
    _amountCtl.text = adjusted <= 0 ? '' : _fmtAmountTight(adjusted);
    _amountCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountCtl.text.length),
    );
  }

  Future<void> _confirmAndSwap(SwapVM vm) async {
    if (!vm.canSwap) {
      if ((_amountCtl.text.trim()).isEmpty) {
        showFloatingSnackBar(context, message: 'Enter amount', type: SnackBarType.error);
      } else {
        showFloatingSnackBar(context, message: 'Insufficient balance', type: SnackBarType.error);
      }
      return;
    }

    // Ensure we have a fresh quote for the current amount.
    final s = vm.state;
    final est = s.estReceive ?? await vm.updateQuote(vm.amount);
    if (est == null) {
      showFloatingSnackBar(context, message: 'No price quote available. Try a different amount.', type: SnackBarType.error);
      return;
    }
    final minOut = vm.currentMinOut ?? (est * (1 - vm.slippagePct)); // safety fallback

    final colors = AppColor.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: colors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: 10),
          Text('Confirm Swap', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
          const SizedBox(height: 12),
          InfoRow('From', '${_fmt.format(vm.amount)} ${s.isXlmToUsdc ? 'XLM' : 'USDC'}'),
          InfoRow('To (est.)', '${_fmt.format(est)} ${s.isXlmToUsdc ? 'USDC' : 'XLM'}'),
          InfoRow('Slippage', '${_fmtPct(vm.slippagePct)}%'),
          InfoRow('Min receive', '${_fmt.format(minOut)} ${s.isXlmToUsdc ? 'USDC' : 'XLM'}'),
          InfoRow('Network fee', s.feeXlm == null ? '—' : '≈ ${_fmt.format(s.feeXlm!)} XLM${s.needsTrustline ? ' (incl. trustline)' : ''}'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.primary.withOpacity(0.35)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async { Navigator.pop(context); await _doSwap(vm, vm.amount, minOut); },
              icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
              label: const Text('Swap now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            )),
          ]),
        ]),
      ),
    );
  }

  Future<void> _doSwap(SwapVM vm, double amount, double minOut) async {
    // One alert that starts in "loading" state, then updates to success/error.
    final ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Submitting swap…',
      subtitle: vm.state.isXlmToUsdc
          ? 'Swapping ${_fmt.format(amount)} XLM → at least ${_fmt.format(minOut)} USDC'
          : 'Swapping ${_fmt.format(amount)} USDC → at least ${_fmt.format(minOut)} XLM',
      primaryText: 'Hide',
      barrierDismissible: true,
    );

    try {
      final txid = await vm.executeSwap(
        amount: amount,
        minOut: minOut,
      );
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

      // Reset amount both in VM and TextField
      await vm.setAmount(0.0);
      _amountCtl.clear();
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

    final canSwap = vm.canSwap;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Swap'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: vm.refreshBalances,
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SizedBox(height: 8),
            BalanceRow(xlm: s.xlmBal, usdc: s.usdcBal),
            const SizedBox(height: 10),

            // Direction
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardHeader(
                    icon: LucideIcons.arrowLeftRight,
                    title: 'Swap Direction',
                    trailing: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _onFlip(vm),
                      icon: Icon(LucideIcons.repeat2, color: colors.primary),
                      tooltip: 'Flip',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DirectionSwitcher(
                    isXlmToUsdc: s.isXlmToUsdc,
                    onFlip: () => _onFlip(vm),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Amount + chips + slippage slider
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardHeader(icon: LucideIcons.badgeDollarSign, title: 'You send (${s.isXlmToUsdc ? 'XLM' : 'USDC'})'),
                  const SizedBox(height: 8),
                  AmountField(label: 'Amount', controller: _amountCtl),
                  const SizedBox(height: 10),
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
                      Text('Slippage tolerance', style: TextStyle(fontWeight: FontWeight.w300, color: colors.textPrimary)),
                      Text('${_fmtPct(vm.slippagePct)}%', style: TextStyle(fontWeight: FontWeight.w800, color: colors.primary)),
                    ],
                  ),
                  SizedBox(height: 5,),
                  if (s.isXlmToUsdc) ...[
                    const SizedBox(height: 8),
                    const HintBox(text: 'We keep ~1 XLM for fees & account reserve. Use quick chips to prefill a safe percentage.'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Quote
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CardHeader(icon: LucideIcons.activity, title: 'Quote', subtitle: 'Live path find result'),
                  const SizedBox(height: 8),
                  TinyInfoRow(
                    icon: LucideIcons.info,
                    text: vm.buildQuoteLine((num x) => _fmt.format(x)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 96),
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
            child: ElevatedButton.icon(
              onPressed: canSwap
                  ? () => _confirmAndSwap(vm)
                  : () {
                HapticFeedback.selectionClick();
                if ((_amountCtl.text.trim()).isEmpty) {
                  showFloatingSnackBar(context, message: 'Enter amount', type: SnackBarType.warning);
                } else {
                  showFloatingSnackBar(context, message: 'Insufficient balance', type: SnackBarType.error);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(LucideIcons.arrowRightLeft, size: 18),
              label: Text(
                s.isXlmToUsdc ? 'Swap XLM → USDC' : 'Swap USDC → XLM',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
