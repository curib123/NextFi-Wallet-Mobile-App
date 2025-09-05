import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Components/confirm_action_sheet.dart';
import 'package:next_fi/Screen/SwapScreenWidgets/swap_widgets.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron/tron_wallet_service.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

enum _SwapDir { trxToUsdt, usdtToTrx }

class _SwapScreenState extends State<SwapScreen> with TickerProviderStateMixin {
  static const double _kDefaultAutoFeeTrx = 5.0; // NEW: default auto fee is 5 TRX

  final _amountCtl = TextEditingController();
  final _minOutCtl = TextEditingController();
  final _fmt = NumberFormat('#,##0.######');

  _SwapDir _dir = _SwapDir.trxToUsdt;
  bool _loading = true;
  String? _errorMsg;

  Uint8List? _privateKey;
  String? _userAddress;

  double _trxBal = 0;
  double _usdtBal = 0;

  double _slippage = 1.0; // %
  bool _useMinGuard = false;

  // Fee limit controls (TRX units for UX)
  bool _feeAuto = true;                 // Auto uses 5 TRX now
  double _feeLimitTrx = _kDefaultAutoFeeTrx; // start aligned with auto default
  final double _minFeeTrx = 5;          // Lower bound (TRX)
  final double _maxFeeTrx = 60;         // Upper bound (TRX)

  StreamSubscription<Map<String, dynamic>>? _incomingSub;
  late final AnimationController _swapSpin =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  TronWalletService _tron = TronWalletService(TronClientConfig());

  @override
  void initState() {
    super.initState();
    _loadWalletAndData();
    _amountCtl.addListener(_onAmountChange);
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _amountCtl.dispose();
    _minOutCtl.dispose();
    _swapSpin.dispose();
    super.dispose();
  }

  /* ---------------- Wallet load ---------------- */
  Future<void> _loadWalletAndData() async {
    final storedMnemonic = await SeedStorage.getSeed();
    if (!mounted) return;

    if (storedMnemonic == null || storedMnemonic.isEmpty) {
      setState(() {
        _loading = false;
        _errorMsg = 'No wallet found. Please import or create a wallet.';
      });
      return;
    }

    try {
      final priv = TronWalletService.derivePrivateKey(storedMnemonic);
      final pub = TronWalletService.publicKeyFromPrivateKey(priv);
      final address = TronWalletService.tronAddressFromPublicKey(pub);

      setState(() {
        _privateKey = priv;
        _userAddress = address;
      });

      await _refreshBalances();

      _incomingSub = _tron
          .watchIncoming(_userAddress!, interval: const Duration(seconds: 12))
          .listen(_handleIncomingTx, onError: (_) {});

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Failed to load wallet: $e';
      });
    }
  }

  Future<void> _refreshBalances() async {
    if (_userAddress == null) return;
    try {
      final sun = await _tron.getTrxBalance(_userAddress!);
      final usdt = await _tron.getTrc20BalanceViaHolders(walletBase58: _userAddress!);
      if (!mounted) return;
      setState(() {
        _trxBal = sun / 1e6;
        _usdtBal = usdt;
      });
    } catch (_) {}
  }

  void _handleIncomingTx(Map<String, dynamic> tx) {
    if (!mounted) return;
    showFloatingSnackBar(
      context,
      type: SnackBarType.info,
      message: 'Incoming ${tx['asset']} ${tx['amount']} detected',
    );
    _refreshBalances();
  }

  void _flipDirection() {
    HapticFeedback.lightImpact();
    _swapSpin.forward(from: 0);
    setState(() {
      _dir = _dir == _SwapDir.trxToUsdt ? _SwapDir.usdtToTrx : _SwapDir.trxToUsdt;
    });
    _suggestMinReceive();
  }

  void _useMax() {
    final dust = 0.1; // keep dust for network fees
    if (_dir == _SwapDir.trxToUsdt) {
      final fee = _feeAuto ? _kDefaultAutoFeeTrx : _feeLimitTrx;
      final max = (_trxBal - fee - dust).clamp(0, double.infinity);
      _amountCtl.text = max <= 0 ? '' : max.toStringAsFixed(6);
    } else {
      _amountCtl.text = _usdtBal <= 0 ? '' : _usdtBal.toStringAsFixed(6);
    }
  }

  void _quickPercent(double p) {
    final fromBal = _dir == _SwapDir.trxToUsdt ? _trxBal : _usdtBal;
    var v = fromBal * p;
    if (_dir == _SwapDir.trxToUsdt) {
      final dust = 0.1;
      final fee = _feeAuto ? _kDefaultAutoFeeTrx : _feeLimitTrx;
      v = (v - fee - dust).clamp(0, fromBal);
    }
    _amountCtl.text = v <= 0 ? '' : v.toStringAsFixed(6);
  }

  void _suggestMinReceive() {
    if (!_useMinGuard) return;
    final amount = double.tryParse(_amountCtl.text.trim());
    if (amount == null || amount <= 0) {
      _minOutCtl.clear();
      return;
    }
    final minOut = amount * (1 - (_slippage / 100));
    _minOutCtl.text = minOut.toStringAsFixed(6);
  }

  void _onAmountChange() {
    if (_useMinGuard) _suggestMinReceive();
    setState(() {});
  }

  bool get _hasEnoughBalanceBasic {
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amount <= 0) return false;
    if (_dir == _SwapDir.trxToUsdt) {
      return amount <= _trxBal;
    } else {
      return amount <= _usdtBal;
    }
  }

  bool get _hasEnoughForFeesIfTRXOut {
    if (_dir != _SwapDir.trxToUsdt) return true;
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0.0;
    final dust = 0.1;
    final fee = _feeAuto ? _kDefaultAutoFeeTrx : _feeLimitTrx;
    return (amount + fee + dust) <= _trxBal + 1e-9;
  }

  bool get _hasEnoughBalance => _hasEnoughBalanceBasic && _hasEnoughForFeesIfTRXOut;

  int get _selectedFeeLimitSun =>
      (_feeAuto ? _kDefaultAutoFeeTrx : _feeLimitTrx).clamp(_minFeeTrx, _maxFeeTrx) * 1e6 ~/ 1;

  /* ---------------- Swap action ---------------- */
  Future<void> _doSwap() async {
    if (_privateKey == null || _userAddress == null) return;

    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amount <= 0) {
      showFloatingSnackBar(context, message: 'Enter a valid amount', type: SnackBarType.error);
      return;
    }
    if (!_hasEnoughBalance) {
      final msg = _dir == _SwapDir.trxToUsdt && !_hasEnoughForFeesIfTRXOut
          ? 'Not enough TRX to cover amount + fee limit'
          : 'Not enough balance';
      showFloatingSnackBar(context, message: msg, type: SnackBarType.error);
      return;
    }

    final minOutVal = _useMinGuard ? (double.tryParse(_minOutCtl.text.trim()) ?? 0.0) : 0.0;
    final from = _dir == _SwapDir.trxToUsdt ? 'TRX' : 'USDT';
    final to = _dir == _SwapDir.trxToUsdt ? 'USDT' : 'TRX';
    final feeTrx = _selectedFeeLimitSun / 1e6;

    final ok = await showConfirmActionSheet(
      context,
      title: 'Confirm Swap',
      message: 'You’re swapping ${_fmt.format(amount)} $from → $to\n'
          'Slippage tolerance: ${_slippage.toStringAsFixed(1)}%\n'
          'Min receive: ${_useMinGuard ? _fmt.format(minOutVal) : 'OFF'} $to\n'
          'Fee limit: ${_feeAuto ? 'Auto (5 TRX)' : '${feeTrx.toStringAsFixed(0)} TRX'}'
          '${_dir == _SwapDir.trxToUsdt ? '\nMax TRX spend: ${_fmt.format(amount + feeTrx)} TRX' : ''}',
      icon: LucideIcons.shuffle,
      confirmLabel: 'Swap',
    );
    if (!ok) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      String txid;
      if (_dir == _SwapDir.trxToUsdt) {
        txid = await _tron.swapTrxToUsdtViaRouter(
          privateKey: _privateKey!,
          amountTrx: amount,
          minUsdtOut: minOutVal,
          feeLimitSun: _selectedFeeLimitSun,
        );
      } else {
        txid = await _tron.swapUsdtToTrxViaRouter(
          privateKey: _privateKey!,
          amountUsdt: amount,
          minTrxOut: minOutVal,
          feeLimitSun: _selectedFeeLimitSun,
        );
      }

      if (!mounted) return;
      showFloatingSnackBar(
        context,
        type: SnackBarType.success,
        message: 'Swap sent! txid: ${txid.trim()}',
      );
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
    final feeTrx = _selectedFeeLimitSun / 1e6;

    final isTrxToUsdt = _dir == _SwapDir.trxToUsdt;
    final fromSymbol = isTrxToUsdt ? 'TRX' : 'USDT';
    final toSymbol = isTrxToUsdt ? 'USDT' : 'TRX';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Swap'), centerTitle: true),
      body: _loading && _userAddress == null
          ? const PageLoader()
          : _errorMsg != null
          ? ErrorStateCard(message: _errorMsg!)
          : RefreshIndicator(
        onRefresh: _refreshBalances,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WalletCard(trx: _trxBal, usdt: _usdtBal),
              const SizedBox(height: 16),
              DirectionPill(
                isTrxToUsdt: isTrxToUsdt,
                onTapTRXtoUSDT: () {
                  if (!isTrxToUsdt) _flipDirection();
                },
                onTapUSDTtoTRX: () {
                  if (isTrxToUsdt) _flipDirection();
                },
              ),
              const SizedBox(height: 10),
              SwapCard(
                fromSymbol: fromSymbol,
                toSymbol: toSymbol,
                amountCtl: _amountCtl,
                minOutCtl: _minOutCtl,
                slippage: _slippage,
                useMinGuard: _useMinGuard,
                fromBalance: isTrxToUsdt ? _trxBal : _usdtBal,
                hasEnoughBalance: _hasEnoughBalance,
                onToggleMinGuard: (v) {
                  setState(() {
                    _useMinGuard = v;
                    if (v) {
                      _suggestMinReceive();
                    } else {
                      _minOutCtl.clear();
                    }
                  });
                },
                onSlippageChanged: (v) {
                  setState(() => _slippage = v);
                  _suggestMinReceive();
                },
                onFlip: _flipDirection,
                onUseMax: _useMax,
                onQuickPercent: _quickPercent,
              ),
              const SizedBox(height: 14),

              // Fee guides only when switch is active (Custom)
              FeeSection(
                isTrxToUsdt: isTrxToUsdt,
                feeAuto: _feeAuto,
                feeLimitTrx: _feeLimitTrx,
                minFeeTrx: _minFeeTrx,
                maxFeeTrx: _maxFeeTrx,
                trxBalance: _trxBal,
                currentAmountTrx: amount,
                onModeChanged: (auto) => setState(() => _feeAuto = auto),
                onFeeChanged: (v) => setState(() => _feeLimitTrx = v),
                // conveys the auto default to the widget for its internal labels if needed
                autoDefaultTrx: _kDefaultAutoFeeTrx,
              ),
              const SizedBox(height: 12),

              SummaryTile(
                isTrxToUsdt: isTrxToUsdt,
                amount: amount,
                minOut: _useMinGuard ? (double.tryParse(_minOutCtl.text.trim()) ?? 0.0) : null,
                feeTrx: feeTrx,
                feeAuto: _feeAuto,
              ),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: (_loading || !_hasEnoughBalance) ? null : _doSwap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(LucideIcons.arrowRightLeft),
                label: Text(isTrxToUsdt ? 'Swap TRX ' : 'Swap USDT '),
              ),
              const SizedBox(height: 18),
              InfoTile(
                text:
                'SunSwap is used under the hood. Set slippage and an optional minimum receive. '
                    'Default fee limit is Auto (5 TRX). Turn ON “Custom” in Network Fee Limit to reveal guides and presets (5–60 TRX). '
                    'For TRX→USDT, ensure you have enough TRX to cover amount + fee limit.',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: RotationTransition(
        turns: Tween(begin: 0.0, end: 0.5)
            .animate(CurvedAnimation(parent: _swapSpin, curve: Curves.easeOut)),
        child: FloatingActionButton(
          heroTag: 'swap_flip_fab',
          onPressed: _flipDirection,
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Icon(LucideIcons.arrowUpDown, color: colors.primary),
        ),
      ),
    );
  }
}
