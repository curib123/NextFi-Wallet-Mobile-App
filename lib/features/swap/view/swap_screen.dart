// lib/features/swap/view/swap_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/common/components/modal/confirm_swap_sheet.dart';

import 'package:next_fi/features/swap/model/swap_mode.dart';
import 'package:next_fi/features/swap/view/widgets/section_card.dart';
import 'package:next_fi/features/swap/view/widgets/balance_row.dart';
import 'package:next_fi/features/swap/view/widgets/percent_chips_row.dart';
import 'package:next_fi/features/swap/view/widgets/hint_box.dart';
import 'package:next_fi/features/swap/view/widgets/error_card.dart';
import 'package:next_fi/features/swap/view/widgets/appbar_compact_switch.dart';
import 'package:next_fi/features/swap/view/widgets/order_type_field.dart';
import 'package:next_fi/features/swap/view/widgets/slippage_control.dart';
import 'package:next_fi/features/swap/view/widgets/asset_select_row.dart';
import 'package:next_fi/features/swap/view/widgets/schedule_range_row.dart';
import 'package:next_fi/features/swap/view/widgets/amount_field_with_asset.dart';
import 'package:next_fi/features/swap/view_model/swap_vm.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final _amountCtl = TextEditingController();
  final _fmt = NumberFormat('#,##0.######');

  // Allow partial decimals while the user is typing/deleting:
  // "", "0", "0.", "1.", "1.2", "1.20" … up to 7 decimals
  final RegExp _partialNumberRe = RegExp(r'^\d{0,12}([.]\d{0,7})?$');

  bool _started = false;
  bool _syncingText = false;
  bool _compact = true;
  SwapTab _tab = SwapTab.market;

  DateTime? _scheduleStart;
  DateTime? _scheduleEnd;

  bool? _lastIsXlmToUsdc;

  @override
  void initState() {
    super.initState();

    _amountCtl.addListener(() async {
      if (_syncingText) return;
      final vm = context.read<SwapVM>();
      var raw = _amountCtl.text;

      // keep "0." when user types just a dot
      if (raw == ".") {
        _syncingText = true;
        try {
          _amountCtl.text = "0.";
          _amountCtl.selection = TextSelection.fromPosition(
            TextPosition(offset: _amountCtl.text.length),
          );
        } finally {
          _syncingText = false;
        }
        return;
      }

      // Always notify VM of what the user typed
      await vm.onAmountChanged(raw);

      // IMPORTANT: if user is typing/deleting a valid partial decimal,
      // DO NOT overwrite the field (prevents "can't delete around decimal" bug)
      if (_partialNumberRe.hasMatch(raw)) {
        if (mounted) setState(() {}); // refresh converted hint
        return;
      }

      // Fallback normalization when input is not a valid partial number
      final parsed = double.tryParse(raw.replaceAll(',', '').trim()) ?? vm.amount;
      if (vm.mode == AmountMode.from && (parsed - vm.amount).abs() > 1e-9) {
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

      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vm = context.read<SwapVM>();
      await vm.start(); // idempotent

      // default visible input: TO (receive) for Market/Schedule, FROM for Limit (even if placeholder)
      await _setModeForContext(vm);
      setState(() {});
    });
    _started = true;
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    super.dispose();
  }

  // ───────────── helpers ─────────────
  String _tight(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  String _fmtPct(double frac) {
    final pct = frac * 100;
    return pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1);
  }

  Future<void> _setModeForContext(SwapVM vm) async {
    final desired = _tab == SwapTab.limit ? AmountMode.from : AmountMode.to;
    if (vm.mode != desired) {
      await vm.setAmountMode(desired);
    }
  }

  String _activeSymbol({required bool isXlmToUsdc, required AmountMode mode}) {
    if (mode == AmountMode.from) {
      return isXlmToUsdc ? 'XLM' : 'USDC';
    } else {
      return isXlmToUsdc ? 'USDC' : 'XLM';
    }
  }

  AmountMode _modeForChosenSymbol({required bool isXlmToUsdc, required String chosen}) {
    if (isXlmToUsdc) {
      return (chosen == 'XLM') ? AmountMode.from : AmountMode.to;
    } else {
      return (chosen == 'USDC') ? AmountMode.from : AmountMode.to;
    }
  }

  Future<void> _applyPct(SwapVM vm, double p) async {
    HapticFeedback.selectionClick();
    final prevMode = vm.mode;

    if (vm.mode != AmountMode.from) {
      await vm.setAmountMode(AmountMode.from);
    }
    final newAmt = await vm.applyPercent(p);

    _syncingText = true;
    try {
      if (prevMode == AmountMode.from) {
        _amountCtl.text = newAmt <= 0 ? '' : _tight(newAmt);
      } else {
        final est = vm.state.estReceive ?? (newAmt > 0 ? await vm.updateQuote(newAmt) : null);
        _amountCtl.text = (est == null || est <= 0) ? '' : _tight(est);
      }
      _amountCtl.selection =
          TextSelection.fromPosition(TextPosition(offset: _amountCtl.text.length));
    } finally {
      _syncingText = false;
    }

    if (prevMode != AmountMode.from) {
      await vm.setAmountMode(prevMode);
    }
    if (mounted) setState(() {});
  }

  Future<void> _flip(SwapVM vm) async {
    HapticFeedback.lightImpact();
    final adjustedFrom = await vm.flipDirectionAndRequote();
    await _setModeForContext(vm);

    _syncingText = true;
    try {
      if (vm.mode == AmountMode.from) {
        _amountCtl.text = adjustedFrom <= 0 ? '' : _tight(adjustedFrom);
      } else {
        final est =
            vm.state.estReceive ?? (vm.amount > 0 ? await vm.updateQuote(vm.amount) : null);
        _amountCtl.text = (est == null || est <= 0) ? '' : _tight(est);
      }
      _amountCtl.selection =
          TextSelection.fromPosition(TextPosition(offset: _amountCtl.text.length));
    } finally {
      _syncingText = false;
    }
    if (mounted) setState(() {});
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Confirm flows — use separated modal that LISTENS to VM inside sheet
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _confirmMarket(SwapVM vm) async {
    final s = vm.state;

    // Ensure VM reflects text now (important in TO mode)
    await vm.onAmountChanged(_amountCtl.text);

    if (!vm.hasAmount) return;
    if (!vm.canSwap) {
      showFloatingSnackBar(context, message: 'Insufficient balance', type: SnackBarType.error);
      return;
    }
    // Ensure quote before showing sheet
    final estOut = s.estReceive ?? await vm.updateQuote(vm.amount);
    if (estOut == null || estOut <= 0) {
      showFloatingSnackBar(context, message: 'No price quote available.', type: SnackBarType.error);
      return;
    }

    final minOutPreFee = await showConfirmMarketSheet(context, fmt: _fmt);
    if (minOutPreFee != null) {
      await _execute(vm, vm.amount, minOutPreFee);
    }
  }

  Future<void> _confirmSchedule(SwapVM vm) async {
    final ok = await showConfirmScheduleSheet(
      context,
      fmt: _fmt,
      start: _scheduleStart,
      end: _scheduleEnd,
    );
    if (ok == true) {
      await vm.placeScheduleOrder(
        xlmToUsdc: vm.state.isXlmToUsdc,
        amountFrom: vm.amount,
        scheduleAt: _scheduleStart!,
      );
      if (!mounted) return;
      showFloatingSnackBar(context, message: 'Scheduled swap added.', type: SnackBarType.success);
      _amountCtl.clear();
      await vm.setAmount(0);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _execute(SwapVM vm, double amount, double minOutPreFee) async {
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
      final tx = await vm.executeSwap(amount: amount, minOut: minOutPreFee);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ctl.update(
        AppAlertType.success,
        title: 'Swap submitted',
        subtitle: tx,
        primaryText: 'Copy TxID',
        onPrimary: () async {
          await Clipboard.setData(ClipboardData(text: tx));
          ctl.close();
        },
      );
      await vm.setAmount(0);
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
    final vm = context.watch<SwapVM>();
    final s = vm.state;
    final c = AppColor.of(context);

    final double r = _compact ? 10 : 12;
    final EdgeInsets pad =
    EdgeInsets.symmetric(horizontal: _compact ? 10 : 12, vertical: _compact ? 9 : 12);
    final double gapS = _compact ? 6 : 10;
    final double gapM = _compact ? 8 : 12;
    final double listTop = _compact ? 6 : 10;
    final double listBottom = _compact ? 10 : 14;

    if (_lastIsXlmToUsdc != s.isXlmToUsdc) {
      _lastIsXlmToUsdc = s.isXlmToUsdc;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _setModeForContext(vm);
        _syncingText = true;
        try {
          if (vm.mode == AmountMode.from) {
            _amountCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
          } else {
            final est =
                vm.state.estReceive ?? (vm.amount > 0 ? await vm.updateQuote(vm.amount) : null);
            _amountCtl.text = (est == null || est <= 0) ? '' : _tight(est);
          }
          _amountCtl.selection =
              TextSelection.fromPosition(TextPosition(offset: _amountCtl.text.length));
        } finally {
          _syncingText = false;
        }
        if (mounted) setState(() {});
      });
    }

    // keep FROM field in sync with VM when VM owns the truth,
    // but don't fight the user while they are typing a valid partial number
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _syncingText || vm.mode != AmountMode.from) return;
      final raw = _amountCtl.text.trim();

      // NEW: don't override while a valid partial is being typed
      if (_partialNumberRe.hasMatch(raw)) return;

      final parsed = double.tryParse(raw.replaceAll(',', '')) ?? 0.0;
      if ((parsed - vm.amount).abs() > 1e-9) {
        _syncingText = true;
        try {
          _amountCtl.text = vm.amount <= 0 ? '' : _tight(vm.amount);
          _amountCtl.selection =
              TextSelection.fromPosition(TextPosition(offset: _amountCtl.text.length));
        } finally {
          _syncingText = false;
        }
      }
    });

    final hasAmount = vm.hasAmount;
    final canSwap = vm.canSwap;

    final isXlmToUsdc = s.isXlmToUsdc;
    final fromSymbol = isXlmToUsdc ? 'XLM' : 'USDC';
    final toSymbol = isXlmToUsdc ? 'USDC' : 'XLM';
    final activeSymbol = _activeSymbol(isXlmToUsdc: isXlmToUsdc, mode: vm.mode);
    final amountLabel =
    vm.mode == AmountMode.from ? 'You send ($activeSymbol)' : 'You receive ($activeSymbol)';

    // converted hint data
    double? convertedValue;
    String convertedSymbol = '';
    if (vm.mode == AmountMode.from) {
      if (s.estReceive != null && s.estReceive! > 0) {
        convertedValue = s.estReceive!;
        convertedSymbol = toSymbol;
      }
    } else {
      if (vm.amount > 0) {
        convertedValue = vm.amount;
        convertedSymbol = fromSymbol;
      }
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.background,
        title: const Text('Swap'),
        actions: [
          AppBarCompactSwitch(value: _compact, onChanged: (v) => setState(() => _compact = v)),
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
        color: c.primary,
        backgroundColor: c.surface,
        onRefresh: () async {
          await vm.refreshBalances();
          if (vm.amount > 0) await vm.updateQuote(vm.amount);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(12, listTop, 12, listBottom),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            SizedBox(height: _compact ? 2 : 4),
            BalanceRow(
              xlm: s.xlmBal,
              usdc: s.usdcBal,
              numberFormat: NumberFormat('#,##0.####'),
            ),
            SizedBox(height: _compact ? 8 : 10),

            SectionCard(
              padding: EdgeInsets.all(_compact ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Direction controls
                  AssetSelectRow(
                    isXlmToUsdc: s.isXlmToUsdc,
                    onFlip: () => _flip(vm),
                    onChange: (fromIsXLM) async {
                      if (fromIsXLM != s.isXlmToUsdc) await _flip(vm);
                    },
                    radius: r,
                    contentPad: pad,
                  ),
                  SizedBox(height: gapS),

                  // Order Type
                  OrderTypeField(
                    value: _tab,
                    onChanged: (t) async {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _tab = t;
                        // no limit-specific UI here anymore
                        if (t != SwapTab.schedule) {
                          _scheduleStart = null;
                          _scheduleEnd = null;
                        }
                      });
                      await _setModeForContext(vm);
                      if (mounted) setState(() {});
                    },
                    radius: r,
                    contentPad: pad,
                  ),

                  if (_tab == SwapTab.schedule) ...[
                    SizedBox(height: _compact ? 8 : 10),
                    ScheduleWindowField(
                      start: _scheduleStart,
                      end: _scheduleEnd,
                      label: 'Execute window',
                      radius: r,
                      padding: pad,
                      dense: _compact,
                      onChanged: (DateTimeRange? range) {
                        setState(() {
                          if (range == null) {
                            _scheduleStart = null;
                            _scheduleEnd = null;
                          } else {
                            _scheduleStart = range.start;
                            _scheduleEnd = range.end;
                          }
                        });
                      },
                    ),
                    SizedBox(height: _compact ? 4 : 6),
                    const HintBox(
                      text:
                      'Your swap will execute in this window using the market price.',
                    ),
                  ],

                  SizedBox(height: gapM),

                  // Amount field with asset dropdown (changes input unit)
                  AmountFieldWithAsset(
                    label: amountLabel,
                    controller: _amountCtl,
                    onClear: () {
                      _syncingText = true;
                      try {
                        _amountCtl.clear();
                      } finally {
                        _syncingText = false;
                      }
                      context.read<SwapVM>().setAmount(0);
                      setState(() {}); // refresh converted hint
                    },
                    symbol: activeSymbol,
                    onPickAsset: (chosen) async {
                      final desired = _modeForChosenSymbol(
                        isXlmToUsdc: isXlmToUsdc,
                        chosen: chosen,
                      );
                      if (desired == vm.mode) return;

                      await vm.setAmountMode(desired);

                      _syncingText = true;
                      try {
                        if (vm.mode == AmountMode.from) {
                          _amountCtl.text =
                          vm.amount <= 0 ? '' : _tight(vm.amount);
                        } else {
                          final est = vm.state.estReceive ??
                              (vm.amount > 0
                                  ? await vm.updateQuote(vm.amount)
                                  : null);
                          _amountCtl.text =
                          (est == null || est <= 0) ? '' : _tight(est);
                        }
                        _amountCtl.selection = TextSelection.fromPosition(
                          TextPosition(offset: _amountCtl.text.length),
                        );
                      } finally {
                        _syncingText = false;
                      }
                      if (mounted) setState(() {});
                    },
                    radius: r,
                    contentPad: pad,
                  ),

                  // converted hint just under amount field
                  if (convertedValue != null && convertedValue! > 0) ...[
                    const SizedBox(height: 6),
                    _ConvertedHint(
                      valueText: _tight(convertedValue!),
                      symbol: convertedSymbol,
                    ),
                  ],

                  SizedBox(height: gapS),

                  // Quick % chips
                  PercentChipsRow(onPick: (p) => _applyPct(vm, p)),

                  SizedBox(height: gapM),

                  // Slippage
                  SlippageControl(
                    value: vm.slippagePct,
                    min: SwapVM.slippageMin,
                    max: SwapVM.slippageMax,
                    label: 'Slippage',
                    onChanged: (v) => vm.setSlippagePct(v),
                    fmt: _fmtPct,
                  ),
                ],
              ),
            ),

            SizedBox(height: _compact ? 8 : 10),

            if (s.isXlmToUsdc)
              const HintBox(
                text:
                'We keep ~1 XLM for fees & reserve. Use the quick chips for a safe prefill.',
              )
            else
              const HintBox(
                text:
                'Stellar fees are paid in XLM. Swapping a small amount to XLM first helps ensure you can transact smoothly.',
              ),
          ],
        ),
      ),
      bottomNavigationBar: (s.loading && s.accountId == null) ||
          (s.error != null && s.error!.isNotEmpty)
          ? null
          : SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, _compact ? 10 : 12),
          child: _bottom(vm, hasAmount, canSwap),
        ),
      ),
    );
  }

  // CTA
  Widget _bottom(SwapVM vm, bool hasAmount, bool canSwap) {
    final s = vm.state;
    switch (_tab) {
      case SwapTab.market:
        return CustomButton(
          text: s.isXlmToUsdc ? 'Swap XLM → USDC' : 'Swap USDC → XLM',
          icon: LucideIcons.arrowRightLeft,
          type: !hasAmount ? ButtonType.disabled : ButtonType.filled,
          onPressed: !hasAmount
              ? () {}
              : (canSwap
              ? () => _confirmMarket(vm)
              : () {
            HapticFeedback.selectionClick();
            showFloatingSnackBar(context,
                message: 'Insufficient balance', type: SnackBarType.error);
          }),
        );

      case SwapTab.limit:
      // Placeholder button that will navigate to a dedicated Limit UI later.
        return CustomButton(
          text: 'Trade (Limit) — Coming Soon',
          icon: LucideIcons.scanLine,
          type: ButtonType.outlined,
          onPressed: () {
            HapticFeedback.selectionClick();
            showFloatingSnackBar(context,
                message: 'Limit trading UI is coming soon.', type: SnackBarType.info);
          },
        );

      case SwapTab.schedule:
        final rangeReady = _scheduleStart != null && _scheduleEnd != null;
        return CustomButton(
          text: s.isXlmToUsdc ? 'Schedule: XLM → USDC' : 'Schedule: USDC → XLM',
          icon: LucideIcons.clock3,
          type: (!hasAmount || !rangeReady) ? ButtonType.disabled : ButtonType.filled,
          onPressed: (!hasAmount || !rangeReady)
              ? () {}
              : () async {
            await _confirmSchedule(vm);
          },
        );
    }
  }
}

// ── tiny, minimalist converted hint ──────────────────────────────────────────
class _ConvertedHint extends StatelessWidget {
  final String valueText;
  final String symbol;
  const _ConvertedHint({required this.valueText, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withOpacity(.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.equal, size: 14, color: c.textSecondary),
          const SizedBox(width: 8),
          AssetLogo(keyOrSymbol: symbol, size: 16),
          const SizedBox(width: 6),
          Text(
            '$valueText $symbol',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
