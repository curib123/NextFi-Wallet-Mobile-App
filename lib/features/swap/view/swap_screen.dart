// lib/features/swap/view/swap_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/common/components/drawer/appdrawer.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/common/components/modal/confirm_swap_sheet.dart';

import 'package:next_fi/features/swap/model/swap_mode.dart';
import 'package:next_fi/features/swap/view/widgets/section_card.dart';
import 'package:next_fi/features/swap/view/widgets/percent_chips_row.dart';
import 'package:next_fi/features/swap/view/widgets/error_card.dart';
import 'package:next_fi/features/swap/view_model/swap_vm.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen>
    with SingleTickerProviderStateMixin {
  final _fmt    = NumberFormat('#,##0.######');
  final _fromCtl = TextEditingController();
  final _toCtl   = TextEditingController();

  final RegExp _partialRe = RegExp(r'^\d{0,12}([.]\d{0,7})?$');

  bool _booted      = false;
  bool _syncingFrom = false;
  bool _syncingTo   = false;
  double? _lastPct;

  late final AnimationController _flipCtl;
  late final Animation<double>    _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnim = CurvedAnimation(parent: _flipCtl, curve: Curves.easeInOut);
    _fromCtl.addListener(_onFromChanged);
    _toCtl.addListener(_onToChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vm = context.read<SwapVM>();
      await vm.start();
      if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);
      _syncBoth(vm);
    });
  }

  @override
  void dispose() {
    _fromCtl.removeListener(_onFromChanged);
    _toCtl.removeListener(_onToChanged);
    _fromCtl.dispose();
    _toCtl.dispose();
    _flipCtl.dispose();
    super.dispose();
  }

  // ── Field listeners ───────────────────────────────────────────────────────

  Future<void> _onFromChanged() async {
    if (_syncingFrom) return;
    final vm = context.read<SwapVM>();
    if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);

    var raw = _fromCtl.text;
    if (raw == '.') {
      _setField(_fromCtl, '0.', isFrom: true);
      return;
    }

    _lastPct = null;
    await vm.onAmountChanged(raw);

    // VM already clamped _amount to availableFrom (fees deducted).
    // If the raw text exceeds what the VM accepted, snap the field.
    final accepted = vm.amount;
    final typed    = double.tryParse(raw.replaceAll(',', '').trim()) ?? 0.0;
    if (typed > 0 && (accepted - typed).abs() > 1e-9) {
      _setField(_fromCtl, _tight(accepted), isFrom: true);
    }

    if (_partialRe.hasMatch(raw)) {
      _syncTo(vm);
    } else {
      _syncBoth(vm);
    }
    if (mounted) setState(() {});
  }

  Future<void> _onToChanged() async {
    if (_syncingTo) return;
    final vm = context.read<SwapVM>();
    if (vm.mode != AmountMode.to) await vm.setAmountMode(AmountMode.to);

    var raw = _toCtl.text;
    if (raw == '.') {
      _setField(_toCtl, '0.', isFrom: false);
      return;
    }

    _lastPct = null;
    await vm.onAmountChanged(raw);
    // VM solved the required input and clamped it to availableFrom.

    if (_partialRe.hasMatch(raw)) {
      _syncFrom(vm);
    } else {
      _syncBoth(vm);
    }
    if (mounted) setState(() {});
  }

  // ── Sync helpers ──────────────────────────────────────────────────────────

  void _setField(TextEditingController ctl, String text, {required bool isFrom}) {
    if (isFrom) {
      _syncingFrom = true;
    } else {
      _syncingTo = true;
    }
    try {
      ctl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } finally {
      if (isFrom) {
        _syncingFrom = false;
      } else {
        _syncingTo = false;
      }
    }
  }

  void _syncFrom(SwapVM vm) {
    _syncingFrom = true;
    try {
      final t = vm.amount <= 0 ? '' : _tight(vm.amount);
      _fromCtl.value = TextEditingValue(
          text: t, selection: TextSelection.collapsed(offset: t.length));
    } finally {
      _syncingFrom = false;
    }
  }

  void _syncTo(SwapVM vm) {
    _syncingTo = true;
    try {
      final est = vm.state.estReceive;
      final t   = (est == null || est <= 0) ? '' : _tight(est);
      _toCtl.value = TextEditingValue(
          text: t, selection: TextSelection.collapsed(offset: t.length));
    } finally {
      _syncingTo = false;
    }
  }

  void _syncBoth(SwapVM vm) {
    _syncingFrom = true;
    _syncingTo   = true;
    try {
      final fromT = vm.amount <= 0 ? '' : _tight(vm.amount);
      final est   = vm.state.estReceive;
      final toT   = (est == null || est <= 0) ? '' : _tight(est);
      _fromCtl.value = TextEditingValue(
          text: fromT, selection: TextSelection.collapsed(offset: fromT.length));
      _toCtl.value = TextEditingValue(
          text: toT, selection: TextSelection.collapsed(offset: toT.length));
    } finally {
      _syncingFrom = false;
      _syncingTo   = false;
    }
    if (mounted) setState(() {});
  }

  // ── Formatting ────────────────────────────────────────────────────────────

  String _tight(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  String _fmtPct(double pct) =>
      pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1);

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _flip(SwapVM vm) async {
    HapticFeedback.lightImpact();
    _flipCtl.forward(from: 0);
    await vm.flipDirectionAndRequote();
    if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);
    _lastPct = null;
    _syncBoth(vm);
  }

  Future<void> _applyPct(SwapVM vm, double p) async {
    HapticFeedback.selectionClick();
    if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);
    // vm.applyPercent uses availableFrom (already fee-deducted) for both assets.
    await vm.applyPercent(p);
    _lastPct = p;
    _syncBoth(vm);
  }

  Future<void> _confirmMarket(SwapVM vm) async {
    // Flush any pending input.
    await vm.onAmountChanged(
        vm.mode == AmountMode.from ? _fromCtl.text : _toCtl.text);
    if (!mounted) return;

    if (!vm.hasAmount) return;

    if (!vm.canSwap) {
      showAppAlert(
        context,
        type: AppAlertType.warning,
        title: 'Insufficient balance',
        subtitle:
        'Your available ${vm.state.isXlmToUsdc ? 'XLM' : 'USDC'} '
            'is not enough for this swap.',
        primaryText: 'OK',
      );
      return;
    }

    if ((vm.state.estReceive ?? 0) <= 0) {
      showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'No price quote',
        subtitle: 'A live quote is not available. Please try again.',
        primaryText: 'OK',
      );
      return;
    }

    if (!mounted) return;
    final minOut = await showConfirmMarketSheet(context, fmt: _fmt);
    if (minOut != null) await _execute(vm, vm.amount, minOut);
  }

  Future<void> _execute(SwapVM vm, double amount, double minOut) async {
    final ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Submitting swap…',
      subtitle: 'This usually takes a few seconds.',
      primaryText: 'Hide',
      barrierDismissible: false,
    );

    try {
      final tx = await vm.executeSwap(amount: amount, minOut: minOut);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ctl.update(
        AppAlertType.success,
        title: 'Swap submitted',
        subtitle: 'Transaction ID:\n$tx',
        primaryText: 'OK',
        onPrimary: ctl.close,
      );
      await vm.setAmount(0);
      _lastPct = null;
      _syncBoth(vm);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      ctl.update(
        AppAlertType.error,
        title: 'Swap failed',
        subtitle: msg.length > 400 ? '${msg.substring(0, 400)}…' : msg,
        primaryText: 'Dismiss',
        onPrimary: ctl.close,
      );
    }
  }

  Future<void> _showSlippagePicker(SwapVM vm) async {
    final c = AppColor.of(context);
    double tempPct = vm.slippagePctPercent;

    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4, width: 36,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: c.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Icon(LucideIcons.slidersHorizontal, size: 18, color: c.textPrimary),
                  const SizedBox(width: 8),
                  Text('Slippage Tolerance',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_fmtPct(tempPct)}%',
                        style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: c.primary,
                  inactiveTrackColor: c.border.withValues(alpha: 0.3),
                  thumbColor: c.primary,
                  overlayColor: c.primary.withValues(alpha: 0.12),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: tempPct.clamp(SwapVM.slippageMinPct, SwapVM.slippageMaxPct),
                  min: SwapVM.slippageMinPct,
                  max: SwapVM.slippageMaxPct,
                  divisions: ((SwapVM.slippageMaxPct - SwapVM.slippageMinPct) / 0.1).round(),
                  label: '${_fmtPct(tempPct)}%',
                  onChanged: (v) => set(() => tempPct = v),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      type: ButtonType.outlined,
                      text: 'Cancel',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomButton(
                      type: ButtonType.filled,
                      text: 'Apply',
                      onPressed: () {
                        vm.setSlippagePctPercent(tempPct);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SwapVM>();
    final s  = vm.state;
    final c  = AppColor.of(context);

    final fromSymbol = s.isXlmToUsdc ? 'XLM' : 'USDC';
    final toSymbol   = s.isXlmToUsdc ? 'USDC' : 'XLM';

    final priceLine = (vm.amount > 0 && (s.estReceive ?? 0) > 0)
        ? '1 $fromSymbol ≈ ${_tight(s.estReceive! / vm.amount)} $toSymbol'
        : '—';

    final minOut = vm.currentMinOut;
    final minReceiveText = (minOut != null && minOut > 0)
        ? '${_tight(minOut)} $toSymbol (min.)'
        : null;

    final balanceStr = s.isXlmToUsdc
        ? '${_fmt.format(s.xlmBal)} XLM'
        : '${_fmt.format(s.usdcBal)} USDC';

    return Scaffold(
      backgroundColor: c.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.background,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            icon: Icon(
              LucideIcons.menu,
              color: c.primary,
              size: 26,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text('Swap',
            style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(LucideIcons.refreshCcw, color: c.textPrimary),
            onPressed: () async {
              HapticFeedback.selectionClick();
              await vm.refreshBalances();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: _buildBody(vm, s, c, fromSymbol, toSymbol, priceLine,
          minReceiveText, balanceStr),
      bottomNavigationBar: _buildBottomBar(vm, s, c),
    );
  }

  Widget _buildBody(
      SwapVM vm, dynamic s, AppColor c,
      String fromSymbol, String toSymbol,
      String priceLine, String? minReceiveText, String balanceStr,
      ) {
    if (s.loading && s.accountId == null) return const PageLoader();
    if (s.error != null && s.error!.isNotEmpty) {
      return ErrorCard(
        message: s.error!,
        onRetry: () async {
          await vm.refreshBalances();
          if (mounted) setState(() {});
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _buildExchangeCard(vm, c, fromSymbol, toSymbol, balanceStr, minReceiveText),
        const SizedBox(height: 14),
        _buildPriceRow(vm, c, priceLine),
        const SizedBox(height: 14),
        PercentChipsRow(activePct: _lastPct, onPick: (p) => _applyPct(vm, p)),
      ],
    );
  }

  Widget _buildExchangeCard(
      SwapVM vm, AppColor c,
      String fromSymbol, String toSymbol,
      String balanceStr, String? minReceiveText,
      ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SectionCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            children: [
              _AmountTile(
                label: 'You pay',
                symbol: fromSymbol,
                controller: _fromCtl,
                hint: '0.0',
                balanceText: balanceStr,
                onMax: () => _applyPct(vm, 1.0),
                onAssetTap: () => _flip(vm),
              ),
              const SizedBox(height: 20),
              _AmountTile(
                label: 'You receive',
                symbol: toSymbol,
                controller: _toCtl,
                hint: '0.0',
                onAssetTap: () => _flip(vm),
              ),
              if (minReceiveText != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 14, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Text(minReceiveText,
                        style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Flip button
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _flipAnim,
              builder: (_, child) =>
                  Transform.rotate(angle: _flipAnim.value * math.pi, child: child),
              child: GestureDetector(
                onTap: () => _flip(vm),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border.withValues(alpha: 0.5)),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.textPrimary.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(LucideIcons.arrowUpDown, size: 18, color: c.primary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(SwapVM vm, AppColor c, String priceLine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.trendingUp, size: 16, color: c.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(priceLine,
                style: TextStyle(color: c.textSecondary, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showSlippagePicker(vm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.slidersHorizontal, size: 13, color: c.primary),
                  const SizedBox(width: 4),
                  Text('${_fmtPct(vm.slippagePctPercent)}%',
                      style: TextStyle(
                          color: c.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar(SwapVM vm, dynamic s, AppColor c) {
    if ((s.loading && s.accountId == null) ||
        (s.error != null && s.error!.isNotEmpty)) {
      return null;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: CustomButton(
          text: s.isXlmToUsdc ? 'Swap XLM → USDC' : 'Swap USDC → XLM',
          icon: LucideIcons.arrowRightLeft,
          type: vm.hasAmount ? ButtonType.filled : ButtonType.disabled,
          onPressed: !vm.hasAmount
              ? () {}
              : vm.canSwap
              ? () => _confirmMarket(vm)
              : () {
            HapticFeedback.selectionClick();
            showAppAlert(
              context,
              type: AppAlertType.warning,
              title: 'Insufficient balance',
              subtitle:
              'Your available ${s.isXlmToUsdc ? 'XLM' : 'USDC'} '
                  'is not enough for this swap.',
              primaryText: 'OK',
            );
          },
        ),
      ),
    );
  }
}

// ── Amount Tile ───────────────────────────────────────────────────────────────

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.symbol,
    required this.controller,
    this.hint = '0.0',
    this.readOnly = false,
    this.onAssetTap,
    this.balanceText,
    this.onMax,
  });

  final String label;
  final String symbol;
  final TextEditingController controller;
  final String hint;
  final bool readOnly;
  final VoidCallback? onAssetTap;
  final String? balanceText;
  final VoidCallback? onMax;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Column(
      children: [
        // Header
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
            const Spacer(),
            if (balanceText != null) ...[
              Text('Balance: ', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              Text(balanceText!,
                  style: TextStyle(
                      fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w500)),
              if (onMax != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onMax,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('MAX',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: c.primary)),
                  ),
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Input row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              // Asset chip
              InkWell(
                onTap: onAssetTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AssetLogo(keyOrSymbol: symbol, size: 20),
                      const SizedBox(width: 8),
                      Text(symbol,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.chevronsUpDown, size: 14, color: c.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Amount field
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.5)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
