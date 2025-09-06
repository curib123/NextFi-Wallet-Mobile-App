import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';

// Compact UI kit
import 'package:next_fi/Screen/SwapScreenWidgets/swap_widgets.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';


class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

enum _SwapDir { xlmToUsdc, usdcToXlm }

class _SwapScreenState extends State<SwapScreen> with TickerProviderStateMixin {
  // Keep at least this much XLM to cover base reserve/fees.
  static const double _kDustXlm = 1.0;

  // Controllers
  final _amountCtl = TextEditingController();
  final _minOutCtl = TextEditingController();

  // Format
  final _fmt = NumberFormat('#,##0.######');

  // State
  _SwapDir _dir = _SwapDir.xlmToUsdc;
  bool _loading = true;
  String? _errorMsg;

  String? _secretSeed; // Stellar secret seed (S...)
  String? _accountId;  // Stellar account id (G...)

  double _xlmBal = 0.0;
  double _usdcBal = 0.0;

  double _slippage = 1.0; // %
  bool _useMinGuard = false;

  // Anim
  late final AnimationController _swapSpin =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  // Stellar
  StellarWalletService? _stellar;

  /* ---------------- Getters ---------------- */
  bool get _isXlmToUsdc => _dir == _SwapDir.xlmToUsdc;
  String get _fromSymbol => _isXlmToUsdc ? 'XLM' : 'USDC';
  String get _toSymbol   => _isXlmToUsdc ? 'USDC' : 'XLM';

  @override
  void initState() {
    super.initState();
    _loadWalletAndData();
    _amountCtl.addListener(_onAmountInput);
  }

  @override
  void dispose() {
    _amountCtl.removeListener(_onAmountInput);
    _amountCtl.dispose();
    _minOutCtl.dispose();
    _swapSpin.dispose();
    super.dispose();
  }

  /* ---------------- Wallet + balances ---------------- */
  Future<void> _loadWalletAndData() async {
    final mn = await SeedStorage.getSeed();
    if (!mounted) return;

    if (mn == null || mn.isEmpty) {
      setState(() {
        _loading = false;
        _errorMsg = 'No wallet found.';
      });
      return;
    }

    try {
      // Derive Stellar keys from mnemonic
      final wallet = await StellarWalletService.walletFromMnemonic(mn);
      final kp = await StellarWalletService.getKeyPair(wallet, index: 0);

      // Lazy-create the service AFTER we know an address (use self as profit sink; not used here)
      _stellar = StellarWalletService(profitAddress: kp.accountId);

      setState(() {
        _secretSeed = kp.secretSeed; // provided by sdk Wallet.getKeyPair()
        _accountId = kp.accountId;
      });

      await _refreshBalances();

      // Start listening for incoming payments to refresh balances (fire-and-forget).
      // (Service internally manages the stream; we don't need to cancel explicitly.)
      _stellar!.streamPayments(kp.accountId, (_) => _refreshBalances());

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _loading = false;
        _errorMsg = 'Failed to load Stellar wallet (is the account funded?).';
      });
    }
  }

  Future<void> _refreshBalances() async {
    final aid = _accountId;
    final svc = _stellar;
    if (aid == null || svc == null) return;
    try {
      final res = await Future.wait<double>([
        svc.getXlmBalance(aid),
        svc.getUsdcBalance(aid),
      ]);
      if (!mounted) return;
      setState(() {
        _xlmBal = res[0];
        _usdcBal = res[1];
      });
    } catch (_) {
      // Keep previous
    }
  }

  /* ---------------- Helpers ---------------- */
  void _flipDirection() {
    HapticFeedback.lightImpact();
    _swapSpin.forward(from: 0);
    setState(() {
      _dir = _isXlmToUsdc ? _SwapDir.usdcToXlm : _SwapDir.xlmToUsdc;
    });
    _suggestMinReceive();
  }

  void _useMax() {
    if (_isXlmToUsdc) {
      final max = (_xlmBal - _kDustXlm).clamp(0, double.infinity);
      _amountCtl.text = max <= 0 ? '' : max.toStringAsFixed(6);
    } else {
      _amountCtl.text = _usdcBal <= 0 ? '' : _usdcBal.toStringAsFixed(6);
    }
  }

  void _quickPercent(double p) {
    final bal = _isXlmToUsdc ? _xlmBal : _usdcBal;
    var v = bal * p;
    if (_isXlmToUsdc) v = (v - _kDustXlm).clamp(0, bal);
    _amountCtl.text = v <= 0 ? '' : v.toStringAsFixed(6);
  }

  void _onAmountInput() {
    if (_useMinGuard) _suggestMinReceive();
  }

  void _suggestMinReceive() {
    if (!_useMinGuard) return;
    final a = double.tryParse(_amountCtl.text.trim());
    if (a == null || a <= 0) {
      _minOutCtl.clear();
      return;
    }
    _minOutCtl.text = (a * (1 - _slippage / 100)).toStringAsFixed(6);
  }

  bool get _hasEnoughBalance {
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amount <= 0) return false;
    if (_isXlmToUsdc) {
      return (amount + _kDustXlm) <= _xlmBal + 1e-9;
    } else {
      return amount <= _usdcBal + 1e-9;
    }
  }

  /* ---------------- Confirm → Execute ---------------- */
  Future<void> _openConfirmSheet() async {
    if (_secretSeed == null || _accountId == null || _stellar == null) {
      showFloatingSnackBar(context, message: 'Wallet not ready', type: SnackBarType.error);
      return;
    }
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amount <= 0) {
      showFloatingSnackBar(context, message: 'Enter amount', type: SnackBarType.error);
      return;
    }
    if (!_hasEnoughBalance) {
      showFloatingSnackBar(context, message: 'Insufficient balance', type: SnackBarType.error);
      return;
    }

    final minOut = _useMinGuard ? (double.tryParse(_minOutCtl.text.trim()) ?? 0.0) : null;
    final colors = AppColor.of(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Text('Confirm Swap',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
              const SizedBox(height: 8),
              SummaryRow(label: 'Route', value: '$_fromSymbol → $_toSymbol'),
              SummaryRow(label: 'Amount', value: '${_fmt.format(amount)} $_fromSymbol'),
              if (minOut != null) SummaryRow(label: 'Min receive', value: '${_fmt.format(minOut)} $_toSymbol'),
              SummaryRow(label: 'Slippage', value: '${_slippage.toStringAsFixed(1)}%'),
              const SummaryRow(
                label: 'Network fee',
                value: '~ a few stroops (≈ 0.0000100 XLM/op)',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.primary.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _executeSwap(amount: amount, minOut: minOut);
                      },
                      icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeSwap({required double amount, double? minOut}) async {
    final svc = _stellar;
    final seed = _secretSeed;
    if (svc == null || seed == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final txid = _isXlmToUsdc
          ? await svc.swapXlmToUsdc(
        secretSeed: seed,
        sendAmountXlm: amount,
        minUsdcOut: (minOut ?? (amount * (1 - _slippage / 100))).clamp(0, double.infinity),
      )
          : await svc.swapUsdcToXlm(
        secretSeed: seed,
        sendAmountUsdc: amount,
        minXlmOut: (minOut ?? (amount * (1 - _slippage / 100))).clamp(0, double.infinity),
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showFloatingSnackBar(context, type: SnackBarType.success, message: 'Swap submitted\n$txid');
      _amountCtl.clear();
      _minOutCtl.clear();
      await _refreshBalances();
    } catch (e) {
      if (!mounted) return;
      showFloatingSnackBar(context, message: 'Swap failed: $e', type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0.0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Swap'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _refreshBalances,
          ),
        ],
      ),
      body: _loading && _accountId == null
          ? const PageLoader()
          : _errorMsg != null
          ? ErrorCard(message: _errorMsg!)
          : RefreshIndicator(
        onRefresh: _refreshBalances,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BalanceRow(trx: _xlmBal, usdt: _usdcBal,),

              const SizedBox(height: 10),
              // Reuse segmented control; pass our direction bool.
              DirectionSegmented(
                isTrxToUsdt: _isXlmToUsdc, // bool only controls left/right selection
                onFlip: _flipDirection,
                controller: _swapSpin,
              ),

              const SizedBox(height: 10),
              AmountField(
                label: 'You send ($_fromSymbol)',
                controller: _amountCtl,
                onUseMax: _useMax,
                onPct: _quickPercent,
                colors: colors,
              ),

              const SizedBox(height: 8),
              MinReceiveRow(
                enabled: _useMinGuard,
                valueCtl: _minOutCtl,
                slippage: _slippage,
                onToggle: (v) {
                  setState(() => _useMinGuard = v);
                  _suggestMinReceive();
                },
                onSlippage: (v) {
                  setState(() => _slippage = v);
                  _suggestMinReceive();
                },
                toSymbol: _toSymbol,
                colors: colors,
              ),

              const SizedBox(height: 10),
              SummaryCard(
                from: _fromSymbol,
                to: _toSymbol,
                amount: amount,
                minOut: _useMinGuard ? (double.tryParse(_minOutCtl.text.trim()) ?? 0.0) : null,
                feeText: 'Auto (base fee)',
                colors: colors,
                fmt: _fmt,
              ),

              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: (_loading || !_hasEnoughBalance) ? null : _openConfirmSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(LucideIcons.arrowRightLeft),
                label: Text(_isXlmToUsdc ? 'Review XLM → USDC' : 'Review USDC → XLM'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
