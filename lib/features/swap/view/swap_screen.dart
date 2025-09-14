// lib/features/swap/view/swap_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/AppAlert.dart';
import 'package:next_fi/common/components/SnackBar.dart';
import 'package:next_fi/features/swap/view_model/swap_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import '../model/swap_dir.dart';
import 'widgets/page_loader.dart';
import 'widgets/error_card.dart';
import 'widgets/section_card.dart';
import 'widgets/card_header.dart';
import 'widgets/balance_row.dart';
import 'widgets/direction_switcher.dart';
import 'widgets/amount_field.dart';
import 'widgets/percent_chips_row.dart';
import 'widgets/tiny_info_row.dart';
import 'widgets/info_row.dart';
import 'widgets/hint_box.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final _amountCtl = TextEditingController();
  final _fmt = NumberFormat('#,##0.######');
  static const double _slippage = 0.01; // 1%
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _amountCtl.addListener(() {
      final vm = context.read<SwapVM>();
      final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
      vm.updateQuote(amt);
      setState(() {}); // toggle CTA state immediately
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
  void dispose() { _amountCtl.dispose(); super.dispose(); }

  // ─── helpers ───────────────────────────────────────────────────────────────
  double _floorTo(double v, int dec) {
    final scale = math.pow(10, dec);
    return (v >= 0 ? (v * scale).floor() / scale : (v * scale).ceil() / scale).toDouble();
  }
  String _fmtAmount(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }
  void _applyPercent(SwapVM vm, double percent) {
    final base = vm.availableFrom;
    final v = _floorTo(base * percent, 7);
    HapticFeedback.selectionClick();
    _amountCtl.text = v <= 0 ? '' : _fmtAmount(v);
    _amountCtl.selection = TextSelection.fromPosition(TextPosition(offset: _amountCtl.text.length));
  }
  Future<void> _flipDir(SwapVM vm) async {
    HapticFeedback.lightImpact();
    await vm.setDir(vm.state.isXlmToUsdc ? SwapDir.usdcToXlm : SwapDir.xlmToUsdc);
    final amt = double.tryParse(_amountCtl.text.trim());
    if (amt != null) {
      final cap = vm.availableFrom;
      if (amt > cap && cap > 0) _amountCtl.text = cap.toStringAsFixed(6);
      await vm.updateQuote(double.tryParse(_amountCtl.text.trim()) ?? 0);
    }
  }

  Future<void> _confirmAndSwap(SwapVM vm) async {
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amount <= 0) { showFloatingSnackBar(context, message: 'Enter amount', type: SnackBarType.error); return; }
    if (!vm.hasEnough(amount)) { showFloatingSnackBar(context, message: 'Insufficient balance', type: SnackBarType.error); return; }

    double? est = vm.state.estReceive ?? await vm.updateQuote(amount);
    if (est == null) {
      showFloatingSnackBar(context, message: 'No price quote available. Try a different amount.', type: SnackBarType.error);
      return;
    }
    final minOut = est * (1 - _slippage);

    final colors = AppColor.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 10),
          Text('Confirm Swap', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
          const SizedBox(height: 12),
          InfoRow('From', '${_fmt.format(amount)} ${vm.state.isXlmToUsdc ? 'XLM' : 'USDC'}'),
          InfoRow('To (est.)', '${_fmt.format(est)} ${vm.state.isXlmToUsdc ? 'USDC' : 'XLM'}'),
          InfoRow('Slippage', '1%'),
          InfoRow('Min receive', '${_fmt.format(minOut)} ${vm.state.isXlmToUsdc ? 'USDC' : 'XLM'}'),
          InfoRow('Network fee', vm.state.feeXlm == null ? '—' : '≈ ${_fmt.format(vm.state.feeXlm!)} XLM${vm.state.needsTrustline ? ' (incl. trustline)' : ''}'),
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
              onPressed: () async { Navigator.pop(context); await _doSwap(vm, amount, minOut); },
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
    late final AppAlertController submittingCtl;
    submittingCtl = showAppAlert(
      context,
      type: AppAlertType.info,
      title: 'Submitting swap…',
      subtitle: vm.state.isXlmToUsdc
          ? 'Swapping ${_fmt.format(amount)} XLM → at least ${_fmt.format(minOut)} USDC'
          : 'Swapping ${_fmt.format(amount)} USDC → at least ${_fmt.format(minOut)} XLM',
      primaryText: 'Hide',
      barrierDismissible: true,
      onPrimary: () => submittingCtl.close(),
    );

    try {
      final txid = await vm.executeSwap(
        amount: amount,
        minOut: minOut,
        secretSupplier: () async {
          final mnemonic = await SeedStorage.getActiveSeed() ?? await SeedStorage.getSeed();
          if (mnemonic == null || mnemonic.isEmpty) return null;
          final wallet = await StellarWalletService.walletFromMnemonic(mnemonic);
          final kp = await StellarWalletService.getKeyPair(wallet, index: 0);
          return kp.secretSeed;
        },
      );
      if (!mounted) return;
      submittingCtl.close();
      HapticFeedback.mediumImpact();

      late final AppAlertController okCtl;
      okCtl = showAppAlert(
        context,
        type: AppAlertType.success,
        title: 'Swap submitted',
        subtitle: txid,
        primaryText: 'Copy TxID',
        onPrimary: () async { await Clipboard.setData(ClipboardData(text: txid)); okCtl.close(); },
      );
      _amountCtl.clear();
    } catch (e) {
      if (!mounted) return;
      submittingCtl.close();
      final msg = e.toString();
      showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'Swap failed',
        subtitle: msg.length > 220 ? '${msg.substring(0, 220)}…' : msg,
        primaryText: 'OK',
        onPrimary: () {},
        barrierDismissible: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<SwapVM>();
    final s = vm.state;

    String quoteLine() {
      if (s.estReceive == null) return 'Getting live quote…';
      final recv = _fmt.format(s.estReceive!);
      final fee = s.feeXlm == null ? '' : ' · Fee≈ ${_fmt.format(s.feeXlm!)} XLM${s.needsTrustline ? ' (incl. trustline)' : ''}';
      return 'Est. receive: $recv ${s.isXlmToUsdc ? 'USDC' : 'XLM'} · Slippage: 1%$fee';
    }

    final canSwap = () {
      final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
      return amt > 0 && vm.hasEnough(amt) && !s.loading;
    }();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Swap'),
        centerTitle: false,
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(LucideIcons.refreshCcw), onPressed: vm.refreshBalances),
        ],
      ),
      body: (s.loading && s.accountId == null)
          ? const PageLoader()
          : (s.error != null && s.error!.isNotEmpty)
          ? ErrorCard(message: s.error!)
          : RefreshIndicator(
        onRefresh: () async {
          await vm.refreshBalances();
          final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
          if (amt > 0) await vm.updateQuote(amt);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SizedBox(height: 8),
            BalanceRow(xlm: s.xlmBal, usdc: s.usdcBal),
            const SizedBox(height: 10),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CardHeader(
                icon: LucideIcons.arrowLeftRight,
                title: 'Swap Direction',
                trailing: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _flipDir(vm),
                  icon: Icon(LucideIcons.repeat2, color: colors.primary),
                  tooltip: 'Flip',
                ),
              ),
              const SizedBox(height: 10),
              DirectionSwitcher(isXlmToUsdc: s.isXlmToUsdc, onFlip: () => _flipDir(vm)),
            ])),
            const SizedBox(height: 10),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CardHeader(icon: LucideIcons.badgeDollarSign, title: 'You send (${s.isXlmToUsdc ? 'XLM' : 'USDC'})'),
              const SizedBox(height: 8),
              AmountField(label: 'Amount', controller: _amountCtl),
              const SizedBox(height: 10),
              PercentChipsRow(onPick: (pct) => _applyPercent(vm, pct)),
              if (s.isXlmToUsdc) ...[
                const SizedBox(height: 8),
                const HintBox(text: 'We keep ~1 XLM for fees & account reserve. Use quick chips to prefill a safe percentage.'),
              ],
            ])),
            const SizedBox(height: 10),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const CardHeader(icon: LucideIcons.activity, title: 'Quote', subtitle: 'Live path find result'),
              const SizedBox(height: 8),
              TinyInfoRow(icon: LucideIcons.info, text: quoteLine()),
            ])),
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
              onPressed: canSwap ? () => _confirmAndSwap(vm) : () {
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
              label: Text(s.isXlmToUsdc ? 'Swap XLM → USDC' : 'Swap USDC → XLM',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }
}
