// lib/features/swap/view/swap_screen.dart
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

class _SwapScreenState extends State<SwapScreen> {
  final _fmt = NumberFormat('#,##0.######');

  // Controllers for "From" and "To" fields (common exchange UX)
  final _fromCtl = TextEditingController();
  final _toCtl = TextEditingController();

  // Allow partial decimals while typing/deleting: "", "0.", "1.20", etc (max 7 dp)
  final RegExp _partialNumberRe = RegExp(r'^\d{0,12}([.]\d{0,7})?$');

  bool _booted = false;
  bool _syncingFrom = false;
  bool _syncingTo = false;

  @override
  void initState() {
    super.initState();

    // FROM listener — user edits "You pay"
    _fromCtl.addListener(() async {
      if (_syncingFrom) return;
      final vm = context.read<SwapVM>();

      // If user is editing FROM, make sure VM is in FROM mode.
      if (vm.mode != AmountMode.from) {
        await vm.setAmountMode(AmountMode.from);
      }

      var raw = _fromCtl.text;

      // Keep "0." when user types only a dot (convert to 0.)
      if (raw == ".") {
        _syncingFrom = true;
        try {
          _fromCtl.text = "0.";
          _fromCtl.selection =
              TextSelection.fromPosition(TextPosition(offset: _fromCtl.text.length));
        } finally {
          _syncingFrom = false;
        }
        return;
      }

      // Always notify VM (it does parsing/quoting)
      await vm.onAmountChanged(raw);

      // If valid partial number, don't normalize; just update TO side
      if (_partialNumberRe.hasMatch(raw)) {
        // Update the TO field with latest estimated receive
        _syncingTo = true;
        try {
          final est = vm.state.estReceive;
          _toCtl.text = (est == null || est <= 0) ? '' : _tight(est);
          _toCtl.selection =
              TextSelection.fromPosition(TextPosition(offset: _toCtl.text.length));
        } finally {
          _syncingTo = false;
        }
        if (mounted) setState(() {});
        return;
      }

      // Fallback normalization
      final parsed = double.tryParse(raw.replaceAll(',', '').trim()) ?? vm.amount;
      if ((parsed - vm.amount).abs() > 1e-9) {
        _syncingFrom = true;
        try {
          _fromCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
          _fromCtl.selection =
              TextSelection.fromPosition(TextPosition(offset: _fromCtl.text.length));
        } finally {
          _syncingFrom = false;
        }
      }

      // Reflect to TO
      _syncingTo = true;
      try {
        final est = vm.state.estReceive;
        _toCtl.text = (est == null || est <= 0) ? '' : _tight(est);
        _toCtl.selection =
            TextSelection.fromPosition(TextPosition(offset: _toCtl.text.length));
      } finally {
        _syncingTo = false;
      }
      if (mounted) setState(() {});
    });

    // TO listener — user edits "You get"
    _toCtl.addListener(() async {
      if (_syncingTo) return;
      final vm = context.read<SwapVM>();

      // If user is editing TO, set VM to TO mode.
      if (vm.mode != AmountMode.to) {
        await vm.setAmountMode(AmountMode.to);
      }

      var raw = _toCtl.text;

      if (raw == ".") {
        _syncingTo = true;
        try {
          _toCtl.text = "0.";
          _toCtl.selection =
              TextSelection.fromPosition(TextPosition(offset: _toCtl.text.length));
        } finally {
          _syncingTo = false;
        }
        return;
      }

      await vm.onAmountChanged(raw);

      // Keep partial input as-is; reflect computed FROM
      if (_partialNumberRe.hasMatch(raw)) {
        _syncingFrom = true;
        try {
          _fromCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
          _fromCtl.selection =
              TextSelection.fromPosition(TextPosition(offset: _fromCtl.text.length));
        } finally {
          _syncingFrom = false;
        }
        if (mounted) setState(() {});
        return;
      }

      // Fallback normalization for TO field (keep user's desired receive visible)
      final estReceive = vm.state.estReceive;
      if (estReceive != null && estReceive > 0) {
        _syncingTo = true;
        try {
          _toCtl.text = _tight(estReceive);
          _toCtl.selection =
              TextSelection.fromPosition(TextPosition(offset: _toCtl.text.length));
        } finally {
          _syncingTo = false;
        }
      }

      // Mirror required FROM
      _syncingFrom = true;
      try {
        _fromCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
        _fromCtl.selection =
            TextSelection.fromPosition(TextPosition(offset: _fromCtl.text.length));
      } finally {
        _syncingFrom = false;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vm = context.read<SwapVM>();
      await vm.start(); // idempotent
      // Default to editing "From" (typical exchange UX)
      if (vm.mode != AmountMode.from) {
        await vm.setAmountMode(AmountMode.from);
      }
      // Seed visible fields
      _syncingFrom = true;
      _syncingTo = true;
      try {
        _fromCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
        final est = vm.state.estReceive ?? (vm.amount > 0 ? await vm.updateQuote(vm.amount) : null);
        _toCtl.text = (est == null || est <= 0) ? '' : _tight(est);
      } finally {
        _syncingFrom = false;
        _syncingTo = false;
      }
      if (mounted) setState(() {});
    });
    _booted = true;
  }

  @override
  void dispose() {
    _fromCtl.dispose();
    _toCtl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  String _tight(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  String _fmtPctNum(double pct) => pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1);

  Future<void> _flip(SwapVM vm) async {
    HapticFeedback.lightImpact();
    await vm.flipDirectionAndRequote();

    // After flip, keep editing FROM by default (common exchange behavior)
    if (vm.mode != AmountMode.from) {
      await vm.setAmountMode(AmountMode.from);
    }

    // Refill fields
    _syncingFrom = true;
    _syncingTo = true;
    try {
      _fromCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
      final est = vm.state.estReceive ?? (vm.amount > 0 ? await vm.updateQuote(vm.amount) : null);
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

  Future<void> _applyPct(SwapVM vm, double p) async {
    HapticFeedback.selectionClick();
    if (vm.mode != AmountMode.from) {
      await vm.setAmountMode(AmountMode.from);
    }
    final newAmt = await vm.applyPercent(p);

    _syncingFrom = true;
    _syncingTo = true;
    try {
      _fromCtl.text = newAmt <= 0 ? '' : _tight(newAmt);
      final est = vm.state.estReceive ?? (newAmt > 0 ? await vm.updateQuote(newAmt) : null);
      _toCtl.text = (est == null || est <= 0) ? '' : _tight(est ?? 0);
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

  Future<void> _confirmMarket(SwapVM vm) async {
    // Ensure VM reflects current visible input based on active mode
    if (vm.mode == AmountMode.from) {
      await vm.onAmountChanged(_fromCtl.text);
    } else {
      await vm.onAmountChanged(_toCtl.text);
    }

    if (!vm.hasAmount) return;

    if (!vm.canSwap) {
      showAppAlert(
        context,
        type:AppAlertType.warning,
        title: 'Insufficient balance',
        subtitle: 'Your available ${vm.state.isXlmToUsdc ? 'XLM' : 'USDC'} '
            'is not enough for this swap.',
        primaryText: 'OK',
      );
      return;
    }

    // Ensure quote exists
    final estOut = vm.state.estReceive ?? await vm.updateQuote(vm.amount);
    if (estOut == null || estOut <= 0) {
      showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'No price quote',
        subtitle: 'A live quote is not available at the moment. Please try again.',
        primaryText: 'OK',
      );
      return;
    }

    // Confirm sheet still provides the minOut-pre-fee value if you need it.
    final minOutPreFee = await showConfirmMarketSheet(context, fmt: _fmt);
    if (minOutPreFee != null) {
      await _execute(vm, vm.amount, minOutPreFee);
    }
  }

  Future<void> _execute(SwapVM vm, double amount, double minOutPreFee) async {
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

      // Success alert
      ctl.update(
        AppAlertType.success,
        title: 'Swap submitted',
        subtitle: 'Transaction ID:\n$tx',
        primaryText: 'OK',
        onPrimary: ctl.close,
      );

      // Clear fields
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
      setState(() {});
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

    // Work in PERCENT for UI; convert back to fraction on Apply.
    double tempPct = vm.slippagePctPercent;

    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 4, width: 36, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(LucideIcons.slidersHorizontal, size: 18),
                      const SizedBox(width: 8),
                      Text('Slippage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                      const Spacer(),
                      Text('${_fmtPctNum(tempPct)}%', style: TextStyle(color: c.textSecondary)),
                    ],
                  ),
                  Slider(
                    value: tempPct.clamp(SwapVM.slippageMinPct, SwapVM.slippageMaxPct).toDouble(),
                    min: SwapVM.slippageMinPct,
                    max: SwapVM.slippageMaxPct,
                    divisions: ((SwapVM.slippageMaxPct - SwapVM.slippageMinPct) / 0.1).round(), // 0.1% steps
                    label: '${_fmtPctNum(tempPct)}%',
                    onChanged: (v) => setSheetState(() => tempPct = v),
                  ),
                  const SizedBox(height: 4),
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
                            vm.setSlippagePct(tempPct / 100); // back to FRACTION
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SwapVM>();
    final s = vm.state;
    final c = AppColor.of(context);

    final isXlmToUsdc = s.isXlmToUsdc;
    final fromSymbol = isXlmToUsdc ? 'XLM' : 'USDC';
    final toSymbol = isXlmToUsdc ? 'USDC' : 'XLM';

    // Derive a display price (rough) from current quote if available
    String priceLine = '—';
    final baseAmt = vm.mode == AmountMode.from
        ? (vm.amount > 0 ? vm.amount : 0)
        : (s.estReceive != null && s.estReceive! > 0 ? s.estReceive! : 0);

    if (baseAmt > 0) {
      final est = s.estReceive ?? 0;
      if (est > 0) {
        final rate = est / baseAmt; // generic A->B rate for display
        final r = _tight(rate);
        priceLine = '1 $fromSymbol ≈ $r $toSymbol';
      }
    }

    // Min receive (pre-fee) using FRACTIONAL slippage correctly
    String? minReceiveText;
    final minPreFee = vm.currentMinOutPreFee;
    if (minPreFee != null && minPreFee > 0) {
      minReceiveText = '${_tight(minPreFee)} $toSymbol (min)';
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.background,
        title: const Text('Swap'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: () async {
              HapticFeedback.selectionClick();
              await vm.refreshBalances();
              if (vm.amount > 0) await vm.updateQuote(vm.amount);
              setState(() {});
            },
          ),
        ],
      ),
      body: (s.loading && s.accountId == null)
          ? const PageLoader()
          : (s.error != null && s.error!.isNotEmpty)
          ? ErrorCard(message: s.error!)
          : ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          // Exchange card
          Stack(
            clipBehavior: Clip.none,
            children: [
              SectionCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  children: [
                    // FROM
                    _AmountTile(
                      label: 'From',
                      symbol: fromSymbol,
                      controller: _fromCtl,
                      hint: '0.0',
                      onAssetTap: () async {
                        // Toggle asset for FROM – only two assets, so flip.
                        await _flip(vm);
                      },
                      balanceText: fromSymbol == 'XLM'
                          ? '${_fmt.format(s.xlmBal)} XLM'
                          : '${_fmt.format(s.usdcBal)} USDC',
                      onMax: () => _applyPct(vm, 1.0),
                    ),
                    const SizedBox(height: 16),

                    // TO
                    _AmountTile(
                      label: 'To',
                      symbol: toSymbol,
                      controller: _toCtl,
                      hint: '0.0',
                      readOnly: false, // allow editing TO (AmountMode.to)
                      onAssetTap: () async {
                        // Toggle asset for TO – flip direction
                        await _flip(vm);
                      },
                    ),
                  ],
                ),
              ),

              // Center flip button (floating)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      tooltip: 'Flip',
                      icon: const Icon(LucideIcons.arrowUpDown, size: 18),
                      onPressed: () => _flip(vm),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Price + Slippage row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border.withOpacity(.5)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.badgeDollarSign, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    priceLine,
                    style: TextStyle(color: c.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _showSlippagePicker(vm),
                  icon: const Icon(LucideIcons.slidersHorizontal, size: 16),
                  label: Text(
                    'Slippage ${_fmtPctNum(vm.slippagePctPercent)}%',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Quick percent chips (common on FROM)
          PercentChipsRow(onPick: (p) => _applyPct(vm, p)),

          if (minReceiveText != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(LucideIcons.shieldCheck, size: 16, color: c.textSecondary),
                const SizedBox(width: 6),
                Text(minReceiveText, style: TextStyle(color: c.textSecondary)),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: (s.loading && s.accountId == null) ||
          (s.error != null && s.error!.isNotEmpty)
          ? null
          : SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                subtitle: 'Your available ${vm.state.isXlmToUsdc ? 'XLM' : 'USDC'} '
                    'is not enough for this swap.',
                primaryText: 'OK',
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── UI pieces ────────────────────────────────────────────────────────────────

class _AmountTile extends StatelessWidget {
  final String label;
  final String symbol;
  final TextEditingController controller;
  final String hint;
  final bool readOnly;
  final VoidCallback? onAssetTap;
  final String? balanceText; // only shown for FROM
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
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
            const Spacer(),
            if (balanceText != null) ...[
              Text('Balance: ',
                  style: TextStyle(fontSize: 12, color: c.textSecondary)),
              Text(balanceText!,
                  style: TextStyle(fontSize: 12, color: c.textPrimary)),
              if (onMax != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onMax,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('MAX',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: c.accent,
                        )),
                  ),
                ),
              ]
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border.withOpacity(.55)),
          ),
          child: Row(
            children: [
              // Asset pill (logo + symbol)
              InkWell(
                onTap: onAssetTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border.withOpacity(.8)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      AssetLogo(keyOrSymbol: symbol, size: 18),
                      const SizedBox(width: 8),
                      Text(symbol,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.chevronDown, size: 16, color: c.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(color: c.textSecondary),
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
