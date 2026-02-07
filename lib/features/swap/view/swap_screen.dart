// lib/features/swap/view/swap_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
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
  final _fmt = NumberFormat('#,##0.######');
  final _fromCtl = TextEditingController();
  final _toCtl = TextEditingController();

  final RegExp _partialNumberRe = RegExp(r'^\d{0,12}([.]\d{0,7})?$');

  bool _booted = false;
  bool _syncingFrom = false;
  bool _syncingTo = false;

  /// Tracks last-applied percent chip for highlight state.
  double? _lastPct;

  /// Flip animation controller.
  late final AnimationController _flipCtl;
  late final Animation<double> _flipAnim;

  double _xlmSpendable(SwapVM vm) {
    final cap = vm.state.xlmBal - SwapVM.dustXlm;
    return cap > 0 ? cap : 0;
  }

  double _clampFromDesired(SwapVM vm, double desired) {
    if (!vm.state.isXlmToUsdc) return desired;
    final cap = _xlmSpendable(vm);
    return desired > cap ? cap : desired;
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vm = context.read<SwapVM>();
      await vm.start();
      if (vm.mode != AmountMode.from) {
        await vm.setAmountMode(AmountMode.from);
      }
      _syncBothFields(vm);
    });
    _booted = true;
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

  // ──────────────────────────────────────────────────────────────────────────
  // Field listeners
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _onFromChanged() async {
    if (_syncingFrom) return;
    final vm = context.read<SwapVM>();

    if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);

    var raw = _fromCtl.text;

    if (raw == '.') {
      _syncField(_fromCtl, '0.', syncing: true, isFrom: true);
      return;
    }

    final desired = double.tryParse(raw.replaceAll(',', '').trim()) ?? 0.0;
    final clamped = _clampFromDesired(vm, desired);

    if ((clamped - desired).abs() > 1e-12) {
      _syncField(_fromCtl, clamped <= 0 ? '' : _tight(clamped),
          syncing: true, isFrom: true);
      raw = _fromCtl.text;
    }

    _lastPct = null;
    await vm.onAmountChanged(raw);

    if (_partialNumberRe.hasMatch(raw)) {
      _syncToField(vm);
      if (mounted) setState(() {});
      return;
    }

    _syncBothFields(vm);
  }

  Future<void> _onToChanged() async {
    if (_syncingTo) return;
    final vm = context.read<SwapVM>();

    if (vm.mode != AmountMode.to) await vm.setAmountMode(AmountMode.to);

    var raw = _toCtl.text;

    if (raw == '.') {
      _syncField(_toCtl, '0.', syncing: true, isFrom: false);
      return;
    }

    _lastPct = null;
    await vm.onAmountChanged(raw);

    // Clamp if XLM→USDC and FROM would exceed spendable
    if (vm.state.isXlmToUsdc) {
      final cap = _xlmSpendable(vm);
      if (vm.amount > cap + 1e-12) {
        await vm.setAmount(cap);
        final est =
        cap > 0 ? await vm.updateQuote(cap) : null;
        _syncBothFieldsRaw(
          fromText: cap <= 0 ? '' : _tight(cap),
          toText: (est == null || est <= 0) ? '' : _tight(est),
        );
        if (mounted) setState(() {});
        return;
      }
    }

    if (_partialNumberRe.hasMatch(raw)) {
      _syncFromField(vm);
      if (mounted) setState(() {});
      return;
    }

    _syncBothFields(vm);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Field sync helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _syncField(
      TextEditingController ctl,
      String text, {
        required bool syncing,
        required bool isFrom,
      }) {
    if (isFrom) {
      _syncingFrom = true;
    } else {
      _syncingTo = true;
    }
    try {
      ctl.text = text;
      ctl.selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
    } finally {
      if (isFrom) {
        _syncingFrom = false;
      } else {
        _syncingTo = false;
      }
    }
  }

  void _syncToField(SwapVM vm) {
    _syncingTo = true;
    try {
      final est = vm.state.estReceive;
      _toCtl.text = (est == null || est <= 0) ? '' : _tight(est);
      _toCtl.selection = TextSelection.fromPosition(
          TextPosition(offset: _toCtl.text.length));
    } finally {
      _syncingTo = false;
    }
  }

  void _syncFromField(SwapVM vm) {
    _syncingFrom = true;
    try {
      _fromCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
      _fromCtl.selection = TextSelection.fromPosition(
          TextPosition(offset: _fromCtl.text.length));
    } finally {
      _syncingFrom = false;
    }
  }

  void _syncBothFields(SwapVM vm) {
    _syncingFrom = true;
    _syncingTo = true;
    try {
      _fromCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
      final est = vm.state.estReceive;
      _toCtl.text = (est == null || est <= 0) ? '' : _tight(est);
      _fromCtl.selection = TextSelection.fromPosition(
          TextPosition(offset: _fromCtl.text.length));
      _toCtl.selection = TextSelection.fromPosition(
          TextPosition(offset: _toCtl.text.length));
    } finally {
      _syncingFrom = false;
      _syncingTo = false;
    }
    if (mounted) setState(() {});
  }

  void _syncBothFieldsRaw({required String fromText, required String toText}) {
    _syncingFrom = true;
    _syncingTo = true;
    try {
      _fromCtl.text = fromText;
      _toCtl.text = toText;
      _fromCtl.selection = TextSelection.fromPosition(
          TextPosition(offset: fromText.length));
      _toCtl.selection = TextSelection.fromPosition(
          TextPosition(offset: toText.length));
    } finally {
      _syncingFrom = false;
      _syncingTo = false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Formatting
  // ──────────────────────────────────────────────────────────────────────────

  String _tight(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  String _fmtPctNum(double pct) =>
      pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1);

  // ──────────────────────────────────────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _flip(SwapVM vm) async {
    HapticFeedback.lightImpact();
    _flipCtl.forward(from: 0);
    await vm.flipDirectionAndRequote();

    if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);

    _syncingFrom = true;
    _syncingTo = true;
    try {
      _fromCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
      final est = vm.state.estReceive ??
          (vm.amount > 0 ? await vm.updateQuote(vm.amount) : null);
      _toCtl.text = (est == null || est <= 0) ? '' : _tight(est);
      _fromCtl.selection = TextSelection.fromPosition(
          TextPosition(offset: _fromCtl.text.length));
      _toCtl.selection = TextSelection.fromPosition(
          TextPosition(offset: _toCtl.text.length));
    } finally {
      _syncingFrom = false;
      _syncingTo = false;
    }
    _lastPct = null;
    if (mounted) setState(() {});
  }

  Future<void> _applyPct(SwapVM vm, double p) async {
    HapticFeedback.selectionClick();
    if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);

    double newAmt;
    if (vm.state.isXlmToUsdc) {
      final base = _xlmSpendable(vm);
      newAmt = (p >= 0.999999) ? base : base * p;
      await vm.setAmount(newAmt);
    } else {
      newAmt = await vm.applyPercent(p);
    }

    _syncingFrom = true;
    _syncingTo = true;
    try {
      _fromCtl.text = newAmt <= 0 ? '' : _tight(newAmt);
      final est = vm.state.estReceive ??
          (newAmt > 0 ? await vm.updateQuote(newAmt) : null);
      _toCtl.text = (est == null || est <= 0) ? '' : _tight(est ?? 0);
      _fromCtl.selection = TextSelection.fromPosition(
          TextPosition(offset: _fromCtl.text.length));
      _toCtl.selection = TextSelection.fromPosition(
          TextPosition(offset: _toCtl.text.length));
    } finally {
      _syncingFrom = false;
      _syncingTo = false;
    }
    _lastPct = p;
    if (mounted) setState(() {});
  }

  Future<void> _confirmMarket(SwapVM vm) async {
    if (vm.mode == AmountMode.from) {
      await vm.onAmountChanged(_fromCtl.text);
    } else {
      await vm.onAmountChanged(_toCtl.text);
    }

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

    final estOut = vm.state.estReceive ?? await vm.updateQuote(vm.amount);
    if (estOut == null || estOut <= 0) {
      showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'No price quote',
        subtitle:
        'A live quote is not available at the moment. Please try again.',
        primaryText: 'OK',
      );
      return;
    }

    if (!mounted) return;
    final minOutPreFee = await showConfirmMarketSheet(context, fmt: _fmt);
    if (minOutPreFee != null) {
      await _execute(vm, vm.amount, minOutPreFee);
    }
  }

  Future<void> _execute(
      SwapVM vm, double amount, double minOutPreFee) async {
    final ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Submitting swap…',
      subtitle: 'This usually takes a few seconds.',
      primaryText: 'Hide',
      barrierDismissible: false,
    );

    try {
      final tx = await vm.executeSwap(amount: amount, minOut: minOutPreFee);
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
      _syncingFrom = true;
      _syncingTo = true;
      try {
        _fromCtl.clear();
        _toCtl.clear();
      } finally {
        _syncingFrom = false;
        _syncingTo = false;
      }
      _lastPct = null;
      if (mounted) setState(() {});
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
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                height: 4,
                width: 36,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: c.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Icon(LucideIcons.slidersHorizontal,
                      size: 18, color: c.textPrimary),
                  const SizedBox(width: 8),
                  Text('Slippage Tolerance',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_fmtPctNum(tempPct)}%',
                      style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
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
                  value: tempPct
                      .clamp(SwapVM.slippageMinPct, SwapVM.slippageMaxPct)
                      .toDouble(),
                  min: SwapVM.slippageMinPct,
                  max: SwapVM.slippageMaxPct,
                  divisions:
                  ((SwapVM.slippageMaxPct - SwapVM.slippageMinPct) / 0.1)
                      .round(),
                  label: '${_fmtPctNum(tempPct)}%',
                  onChanged: (v) => setSheetState(() => tempPct = v),
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
                        vm.setSlippagePct(tempPct / 100);
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

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SwapVM>();
    final s = vm.state;
    final c = AppColor.of(context);

    final isXlmToUsdc = s.isXlmToUsdc;
    final fromSymbol = isXlmToUsdc ? 'XLM' : 'USDC';
    final toSymbol = isXlmToUsdc ? 'USDC' : 'XLM';

    // Price line
    String priceLine = '—';
    if (vm.amount > 0 && (s.estReceive ?? 0) > 0) {
      final rate = s.estReceive! / vm.amount;
      priceLine = '1 $fromSymbol ≈ ${_tight(rate)} $toSymbol';
    }

    // Min receive
    String? minReceiveText;
    final minPreFee = vm.currentMinOutPreFee;
    if (minPreFee != null && minPreFee > 0) {
      minReceiveText = '${_tight(minPreFee)} $toSymbol (min.)';
    }

    // Balance string (full balance)
    final balanceStr = isXlmToUsdc
        ? '${_fmt.format(s.xlmBal)} XLM'
        : '${_fmt.format(s.usdcBal)} USDC';

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.background,
        title: Text('Swap',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: c.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(LucideIcons.refreshCcw, color: c.textPrimary),
            onPressed: () async {
              HapticFeedback.selectionClick();
              await vm.refreshBalances();
              if (vm.amount > 0) await vm.updateQuote(vm.amount);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: _buildBody(vm, s, c, fromSymbol, toSymbol, priceLine,
          minReceiveText, balanceStr),
      bottomNavigationBar: _buildBottomBar(vm, s, c, isXlmToUsdc),
    );
  }

  Widget _buildBody(
      SwapVM vm,
      dynamic s,
      AppColor c,
      String fromSymbol,
      String toSymbol,
      String priceLine,
      String? minReceiveText,
      String balanceStr,
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
        // Exchange card with flip button
        _buildExchangeCard(vm, c, fromSymbol, toSymbol, balanceStr,
            minReceiveText),
        const SizedBox(height: 14),

        // Price + slippage row
        _buildPriceRow(vm, c, priceLine),
        const SizedBox(height: 14),

        // Percent chips
        PercentChipsRow(
          activePct: _lastPct,
          onPick: (p) => _applyPct(vm, p),
        ),

        // XLM reserve info
        if (s.isXlmToUsdc) ...[
          const SizedBox(height: 12),
          _buildReserveInfo(c),
        ],
      ],
    );
  }

  Widget _buildExchangeCard(
      SwapVM vm,
      AppColor c,
      String fromSymbol,
      String toSymbol,
      String balanceStr,
      String? minReceiveText,
      ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SectionCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            children: [
              // FROM tile
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

              // TO tile
              _AmountTile(
                label: 'You receive',
                symbol: toSymbol,
                controller: _toCtl,
                hint: '0.0',
                onAssetTap: () => _flip(vm),
              ),

              // Min receive
              if (minReceiveText != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(LucideIcons.shieldCheck,
                        size: 14, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Text(minReceiveText,
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Animated flip button
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _flipAnim,
              builder: (_, child) => Transform.rotate(
                angle: _flipAnim.value * math.pi,
                child: child,
              ),
              child: GestureDetector(
                onTap: () => _flip(vm),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(
                        color: c.border.withValues(alpha: 0.5)),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(LucideIcons.arrowUpDown,
                      size: 18, color: c.primary),
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
            child: Text(
              priceLine,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showSlippagePicker(vm),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.slidersHorizontal,
                      size: 13, color: c.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${_fmtPctNum(vm.slippagePctPercent)}%',
                    style: TextStyle(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReserveInfo(AppColor c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.info, size: 14,
            color: c.textSecondary.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'MAX keeps 1.0 XLM in your wallet for network fees and '
                'account minimum.',
            style: TextStyle(
              color: c.textSecondary,
              height: 1.35,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomBar(
      SwapVM vm, dynamic s, AppColor c, bool isXlmToUsdc) {
    if ((s.loading && s.accountId == null) ||
        (s.error != null && s.error!.isNotEmpty)) {
      return null;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: CustomButton(
          text: isXlmToUsdc ? 'Swap XLM → USDC' : 'Swap USDC → XLM',
          icon: LucideIcons.arrowRightLeft,
          type: vm.hasAmount ? ButtonType.filled : ButtonType.disabled,
          onPressed: !vm.hasAmount
              ? () {}
              : (vm.canSwap
              ? () => _confirmMarket(vm)
              : () {
            HapticFeedback.selectionClick();
            showAppAlert(
              context,
              type: AppAlertType.warning,
              title: 'Insufficient balance',
              subtitle:
              'Your available ${vm.state.isXlmToUsdc ? 'XLM' : 'USDC'} '
                  'is not enough for this swap.',
              primaryText: 'OK',
            );
          }),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Amount Tile
// ──────────────────────────────────────────────────────────────────────────

class _AmountTile extends StatelessWidget {
  final String label;
  final String symbol;
  final TextEditingController controller;
  final String hint;
  final bool readOnly;
  final VoidCallback? onAssetTap;
  final String? balanceText;
  final VoidCallback? onMax;

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

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Column(
      children: [
        // Header row
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary)),
            const Spacer(),
            if (balanceText != null) ...[
              Text('Balance: ',
                  style: TextStyle(fontSize: 12, color: c.textSecondary)),
              Text(balanceText!,
                  style: TextStyle(
                      fontSize: 12,
                      color: c.textPrimary,
                      fontWeight: FontWeight.w500)),
              if (onMax != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onMax,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('MAX',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: c.primary,
                        )),
                  ),
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Input row
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              // Asset selector
              InkWell(
                onTap: onAssetTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border:
                    Border.all(color: c.border.withValues(alpha: 0.5)),
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
                      Icon(LucideIcons.chevronsUpDown,
                          size: 14, color: c.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Amount input
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                        color: c.textSecondary.withValues(alpha: 0.5)),
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