import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron/tron_wallet_service.dart';

// Compact UI kit
import 'package:next_fi/Screen/SwapScreenWidgets/swap_widgets.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

enum _SwapDir { trxToUsdt, usdtToTrx }

class _SwapScreenState extends State<SwapScreen> with TickerProviderStateMixin {
  // Defaults
  static const double _kDefaultAutoFeeTrx = 5.0; // default even if fee toggle untouched
  static const double _kDustTrx = 0.1;

  // Controllers
  final _amountCtl = TextEditingController();
  final _minOutCtl = TextEditingController();

  // Format
  final _fmt = NumberFormat('#,##0.######');

  // State
  _SwapDir _dir = _SwapDir.trxToUsdt;
  bool _loading = true;
  String? _errorMsg;

  Uint8List? _privateKey;
  String? _userAddress;

  double _trxBal = 0;
  double _usdtBal = 0;

  double _slippage = 1.0; // %
  bool _useMinGuard = false;

  // Network fee (TRX) — default 5 TRX, swap enabled even if not toggled
  bool _feeAuto = true;                 // user toggles only to change it
  double _feeLimitTrx = _kDefaultAutoFeeTrx;
  final double _minFeeTrx = 5;
  final double _maxFeeTrx = 60;

  // Realtime
  StreamSubscription? _incomingSub;

  // Anim
  late final AnimationController _swapSpin =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  // Tron
  final TronWalletService _tron = TronWalletService(const TronClientConfig());

  // -------- Swap Cost Estimate (debounced) --------
  Timer? _debounceEst;
  bool _estLoading = false;
  int? _estEnergyUsed;     // units
  int? _estBandwidthUsed;  // bytes
  double? _estBurnTrx;     // TRX
  String? _estNote;

  /* ---------------- Getters ---------------- */
  bool get _isTrxToUsdt => _dir == _SwapDir.trxToUsdt;
  String get _fromSymbol => _isTrxToUsdt ? 'TRX' : 'USDT';
  String get _toSymbol   => _isTrxToUsdt ? 'USDT' : 'TRX';
  double get _effectiveFeeTrx => _feeAuto ? _kDefaultAutoFeeTrx : _feeLimitTrx;
  int get _feeLimitSun => (_effectiveFeeTrx.clamp(_minFeeTrx, _maxFeeTrx)) * 1e6 ~/ 1;

  @override
  void initState() {
    super.initState();
    _loadWalletAndData();
    _amountCtl.addListener(_onAmountInput);
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _debounceEst?.cancel();
    _amountCtl.removeListener(_onAmountInput);
    _amountCtl.dispose();
    _minOutCtl.dispose();
    _swapSpin.dispose();
    _tron.dispose();
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
      final priv = TronWalletService.derivePrivateKey(mn);
      final addr = TronWalletService.tronAddressFromMnemonic(mn);
      setState(() {
        _privateKey = priv;
        _userAddress = addr;
      });

      await _refreshBalances();

      _incomingSub = _tron
          .watchIncoming(addr, interval: const Duration(seconds: 20))
          .listen((_) => _refreshBalances(), onError: (_) {});

      if (mounted) setState(() => _loading = false);
      _scheduleEstimate(); // first estimate after load
    } catch (_) {
      setState(() {
        _loading = false;
        _errorMsg = 'Failed to load wallet.';
      });
    }
  }

  Future<void> _refreshBalances() async {
    final addr = _userAddress;
    if (addr == null) return;
    try {
      final res = await Future.wait([
        _tron.getTrxBalance(addr),                            // sun
        _tron.getTrc20BalanceViaHolders(walletBase58: addr), // USDT
      ]);
      if (!mounted) return;
      setState(() {
        _trxBal = (res[0]).toDouble() / 1e6;
        _usdtBal = (res[1]).toDouble();
      });
    } catch (_) {/* keep previous balances */}
  }

  /* ---------------- Helpers ---------------- */
  void _flipDirection() {
    HapticFeedback.lightImpact();
    _swapSpin.forward(from: 0);
    setState(() {
      _dir = _isTrxToUsdt ? _SwapDir.usdtToTrx : _SwapDir.trxToUsdt;
    });
    _suggestMinReceive();
    _scheduleEstimate();
  }

  void _useMax() {
    if (_isTrxToUsdt) {
      final fee = _effectiveFeeTrx;
      final max = (_trxBal - fee - _kDustTrx).clamp(0, double.infinity);
      _amountCtl.text = max <= 0 ? '' : max.toStringAsFixed(6);
    } else {
      _amountCtl.text = _usdtBal <= 0 ? '' : _usdtBal.toStringAsFixed(6);
    }
  }

  void _quickPercent(double p) {
    final bal = _isTrxToUsdt ? _trxBal : _usdtBal;
    var v = bal * p;
    if (_isTrxToUsdt) {
      v = (v - _effectiveFeeTrx - _kDustTrx).clamp(0, bal);
    }
    _amountCtl.text = v <= 0 ? '' : v.toStringAsFixed(6);
  }

  void _onAmountInput() {
    if (_useMinGuard) _suggestMinReceive();
    _scheduleEstimate();
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
    if (_isTrxToUsdt) {
      return (amount + _effectiveFeeTrx + _kDustTrx) <= _trxBal + 1e-9;
    } else {
      return amount <= _usdtBal + 1e-9;
    }
  }

  /* ---------------- Estimate (best-effort via service) ---------------- */
  void _scheduleEstimate() {
    _debounceEst?.cancel();
    _debounceEst = Timer(const Duration(milliseconds: 320), _estimateSwapCosts);
  }

  Future<void> _estimateSwapCosts() async {
    final addr = _userAddress;
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0.0;
    if (!mounted || addr == null || amount <= 0) {
      setState(() {
        _estLoading = false;
        _estEnergyUsed = null;
        _estBandwidthUsed = null;
        _estBurnTrx = null;
        _estNote = null;
      });
      return;
    }

    setState(() {
      _estLoading = true;
      _estEnergyUsed = null;
      _estBandwidthUsed = null;
      _estBurnTrx = null;
      _estNote = null;
    });

    try {
      final res = await _tron.estimateSwapCosts(
        from: _fromSymbol,
        to: _toSymbol,
        amount: amount,
        feeLimitSun: _feeLimitSun,
        address: addr,
        slippage: _slippage,
      );

      int _asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      double _asTrx(dynamic sun) => (_asInt(sun)) / 1e6;

      final energy = _asInt(res['energy_used'] ?? res['energyRequired'] ?? res['energy']);
      final net    = _asInt(res['bandwidth_used'] ?? res['net_used'] ?? res['bandwidth'] ?? res['net']);
      final burn   = _asTrx(res['trx_burn_sun'] ?? res['burn_sun'] ?? res['fee_burn_sun'] ?? 0);
      final note   = (res['message'] ?? res['note'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        _estLoading = false;
        _estEnergyUsed = energy > 0 ? energy : null;
        _estBandwidthUsed = net > 0 ? net : null;
        _estBurnTrx = burn > 0 ? burn : null;
        _estNote = note.isEmpty ? null : note;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estLoading = false; // silent; modal row shows "—"
      });
    }
  }

  /* ---------------- Confirm → Execute ---------------- */
  Future<void> _openConfirmSheet() async {
    if (_privateKey == null || _userAddress == null) {
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

    // Ensure estimate is reasonably fresh
    await _estimateSwapCosts();

    final minOut = _useMinGuard ? (double.tryParse(_minOutCtl.text.trim()) ?? 0.0) : null;
    final feeText = _feeAuto ? 'Auto (5 TRX)' : '${(_feeLimitSun / 1e6).toStringAsFixed(0)} TRX';
    final colors = AppColor.of(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) {
        String estRow() {
          if (_estLoading) return 'Estimating…';
          final parts = <String>[];
          if (_estEnergyUsed != null) parts.add('Energy ~$_estEnergyUsed');
          if (_estBandwidthUsed != null) parts.add('Bandwidth ~$_estBandwidthUsed');
          if (_estBurnTrx != null) parts.add('TRX burn ~${_estBurnTrx!.toStringAsFixed(3)}');
          return parts.isEmpty ? '—' : parts.join('  •  ');
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 8),
              Text('Confirm Swap', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
              const SizedBox(height: 8),
              SummaryRow(label: 'Route',    value: '$_fromSymbol → $_toSymbol'),
              SummaryRow(label: 'Amount',   value: '${_fmt.format(amount)} $_fromSymbol'),
              if (minOut != null) SummaryRow(label: 'Min receive', value: '${_fmt.format(minOut)} $_toSymbol'),
              SummaryRow(label: 'Slippage', value: '${_slippage.toStringAsFixed(1)}%'),
              SummaryRow(label: 'Fee limit', value: feeText),
              SummaryRow(label: 'Est. costs', value: estRow()),
              if (_estNote != null && _estNote!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(_estNote!, style: TextStyle(color: colors.textSecondary, fontSize: 11.5)),
                  ),
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
                        await _executeSwap(amount: amount, minOut: minOut ?? 0);
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

  Future<void> _executeSwap({required double amount, required double minOut}) async {
    if (_privateKey == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final txid = _isTrxToUsdt
          ? await _tron.swapTrxToUsdtViaRouter(
        privateKey: _privateKey!,
        amountTrx: amount,
        minUsdtOut: minOut,
        feeLimitSun: _feeLimitSun,
      )
          : await _tron.swapUsdtToTrxViaRouter(
        privateKey: _privateKey!,
        amountUsdt: amount,
        minTrxOut: minOut,
        feeLimitSun: _feeLimitSun,
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
    final feeTrx = _effectiveFeeTrx;

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
      body: _loading && _userAddress == null
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
              BalanceRow(trx: _trxBal, usdt: _usdtBal),

              const SizedBox(height: 10),
              DirectionSegmented(
                isTrxToUsdt: _isTrxToUsdt,
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
                  _scheduleEstimate();
                },
                onSlippage: (v) {
                  setState(() => _slippage = v);
                  _suggestMinReceive();
                  _scheduleEstimate();
                },
                toSymbol: _toSymbol,
                colors: colors,
              ),

              const SizedBox(height: 8),
              FeeRow(
                auto: _feeAuto,
                feeTrx: feeTrx,
                min: _minFeeTrx,
                max: _maxFeeTrx,
                onMode: (isAuto) {
                  setState(() => _feeAuto = isAuto);
                  _scheduleEstimate();
                },
                onChange: (v) {
                  setState(() => _feeLimitTrx = v);
                  _scheduleEstimate();
                },
                colors: colors,
              ),

              const SizedBox(height: 10),
              SummaryCard(
                from: _fromSymbol,
                to: _toSymbol,
                amount: amount,
                minOut: _useMinGuard ? (double.tryParse(_minOutCtl.text.trim()) ?? 0.0) : null,
                feeText: _feeAuto ? 'Auto (5 TRX)' : '${feeTrx.toStringAsFixed(0)} TRX',
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
                label: Text(_isTrxToUsdt ? 'Review TRX → USDT' : 'Review USDT → TRX'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
