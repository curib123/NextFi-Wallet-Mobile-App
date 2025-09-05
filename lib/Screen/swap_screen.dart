import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Components/confirm_action_sheet.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron/tron_wallet_service.dart';
import 'package:next_fi/Provider/AssetProvider.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

enum _SwapDir { trxToUsdt, usdtToTrx }

class _SwapScreenState extends State<SwapScreen> with TickerProviderStateMixin {
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
    _suggestMinReceive(); // keep min receive relevant to direction
  }

  void _useMax() {
    final dust = 0.1; // keep dust for network fees
    if (_dir == _SwapDir.trxToUsdt) {
      final max = (_trxBal - dust).clamp(0, double.infinity);
      _amountCtl.text = max <= 0 ? '' : max.toStringAsFixed(6);
    } else {
      _amountCtl.text = _usdtBal <= 0 ? '' : _usdtBal.toStringAsFixed(6);
    }
  }

  void _quickPercent(double p) {
    final fromBal = _dir == _SwapDir.trxToUsdt ? _trxBal : _usdtBal;
    var v = fromBal * p;
    if (_dir == _SwapDir.trxToUsdt) v = (v - 0.1).clamp(0, fromBal); // dust on TRX
    _amountCtl.text = v <= 0 ? '' : v.toStringAsFixed(6);
  }

  // Suggest min receive when guard is ON (simple, conservative: amount * (1 - slippage%))
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
    setState(() {}); // refresh validation state
  }

  bool get _hasEnoughBalance {
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amount <= 0) return false;
    if (_dir == _SwapDir.trxToUsdt) {
      return amount <= (_trxBal - 0.1); // keep dust for fees
    } else {
      return amount <= _usdtBal;
    }
  }

  /* ---------------- Swap action ---------------- */
  Future<void> _doSwap() async {
    final colors = AppColor.of(context);
    if (_privateKey == null || _userAddress == null) return;

    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amount <= 0) {
      showFloatingSnackBar(context, message: 'Enter a valid amount', type: SnackBarType.error);
      return;
    }
    if (!_hasEnoughBalance) {
      showFloatingSnackBar(context, message: 'Not enough balance', type: SnackBarType.error);
      return;
    }

    final minOutVal = _useMinGuard ? (double.tryParse(_minOutCtl.text.trim()) ?? 0.0) : 0.0;
    final from = _dir == _SwapDir.trxToUsdt ? 'TRX' : 'USDT';
    final to = _dir == _SwapDir.trxToUsdt ? 'USDT' : 'TRX';

    final ok = await showConfirmActionSheet(
      context,
      title: 'Confirm Swap',
      message: 'You’re swapping ${_fmt.format(amount)} $from → $to\n'
          'Slippage tolerance: ${_slippage.toStringAsFixed(1)}%\n'
          'Min receive: ${_useMinGuard ? _fmt.format(minOutVal) : 'OFF'} $to\n'
          'Fee limit: up to 30 TRX (actual may be lower)',
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
          feeLimitSun: 30_000_000,
        );
      } else {
        txid = await _tron.swapUsdtToTrxViaRouter(
          privateKey: _privateKey!,
          amountUsdt: amount,
          minTrxOut: minOutVal,
          feeLimitSun: 30_000_000,
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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Swap'), centerTitle: true),
      body: _loading && _userAddress == null
          ? const _PageLoader()
          : _errorMsg != null
          ? _ErrorState(message: _errorMsg!)
          : RefreshIndicator(
        onRefresh: _refreshBalances,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WalletCard(trx: _trxBal, usdt: _usdtBal),
              const SizedBox(height: 16),
              _DirectionPill(
                dir: _dir,
                onTapTRXtoUSDT: () {
                  if (_dir != _SwapDir.trxToUsdt) _flipDirection();
                },
                onTapUSDTtoTRX: () {
                  if (_dir != _SwapDir.usdtToTrx) _flipDirection();
                },
              ),
              const SizedBox(height: 10),
              _SwapCard(
                dir: _dir,
                amountCtl: _amountCtl,
                minOutCtl: _minOutCtl,
                slippage: _slippage,
                useMinGuard: _useMinGuard,
                fromBalance: _dir == _SwapDir.trxToUsdt ? _trxBal : _usdtBal,
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
                label: Text(_dir == _SwapDir.trxToUsdt ? 'Swap TRX ' : 'Swap USDT '),
              ),
              const SizedBox(height: 18),
              _InfoTile(colors: colors),
            ],
          ),
        ),
      ),
      floatingActionButton: RotationTransition(
        turns: Tween(begin: 0.0, end: 0.5).animate(CurvedAnimation(parent: _swapSpin, curve: Curves.easeOut)),
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

/* ===================== Widgets ===================== */

class _PageLoader extends StatelessWidget {
  const _PageLoader();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.alertTriangle, size: 42, color: colors.warning),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: colors.textPrimary)),
        ]),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.trx, required this.usdt});
  final double trx;
  final double usdt;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final fmt = NumberFormat('#,##0.######');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(child: _BalanceTile(label: 'TRX', value: fmt.format(trx), assetKey: 'tron')),
          const SizedBox(width: 10),
          Expanded(child: _BalanceTile(label: 'USDT', value: fmt.format(usdt), assetKey: 'tether_trc20')),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.label, required this.value, required this.assetKey});
  final String label;
  final String value;
  final String assetKey;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          _AssetLogo(assetKey: assetKey, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionPill extends StatelessWidget {
  const _DirectionPill({
    required this.dir,
    required this.onTapTRXtoUSDT,
    required this.onTapUSDTtoTRX,
  });

  final _SwapDir dir;
  final VoidCallback onTapTRXtoUSDT;
  final VoidCallback onTapUSDTtoTRX;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final selectedA = dir == _SwapDir.trxToUsdt;
    final selectedB = dir == _SwapDir.usdtToTrx;

    Widget pill({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? colors.primary : colors.surface,
                border: Border.all(color: selected ? colors.primary : colors.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(
          label: 'Swap to USDT',
          selected: selectedA,
          onTap: onTapTRXtoUSDT,
        ),
        const SizedBox(width: 10),
        pill(
          label: 'Swap to TRX',
          selected: selectedB,
          onTap: onTapUSDTtoTRX,
        ),
      ],
    );
  }
}

class _SwapCard extends StatelessWidget {
  const _SwapCard({
    required this.dir,
    required this.amountCtl,
    required this.minOutCtl,
    required this.slippage,
    required this.useMinGuard,
    required this.fromBalance,
    required this.hasEnoughBalance,
    required this.onToggleMinGuard,
    required this.onSlippageChanged,
    required this.onFlip,
    required this.onUseMax,
    required this.onQuickPercent,
  });

  final _SwapDir dir;
  final TextEditingController amountCtl;
  final TextEditingController minOutCtl;
  final double slippage;
  final bool useMinGuard;
  final double fromBalance;
  final bool hasEnoughBalance;
  final ValueChanged<bool> onToggleMinGuard;
  final ValueChanged<double> onSlippageChanged;
  final VoidCallback onFlip;
  final VoidCallback onUseMax;
  final void Function(double p) onQuickPercent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final from = dir == _SwapDir.trxToUsdt ? 'TRX' : 'USDT';
    final to = dir == _SwapDir.trxToUsdt ? 'USDT' : 'TRX';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          // From amount
          _LabeledField(
            label: 'You pay ($from)',
            hint: '0.0',
            icon: LucideIcons.keyboard,
            controller: amountCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            trailing: TextButton(onPressed: onUseMax, child: const Text('MAX')),
            validatorHint: _buildValidatorHint(context, hasEnoughBalance, from),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}$')),
            ],
          ),

          // Quick chips
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _QuickChip(percent: 0.25, onTap: () => onQuickPercent(0.25)),
                _QuickChip(percent: 0.50, onTap: () => onQuickPercent(0.50)),
                _QuickChip(percent: 0.75, onTap: () => onQuickPercent(0.75)),
                _QuickChip(label: 'MAX', onTap: onUseMax),
              ],
            ),
          ),

          // Available & swap button
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Available: ${fromBalance.toStringAsFixed(6)} $from',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ),
              InkWell(
                onTap: onFlip,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.primary.withOpacity(0.25)),
                  ),
                  child: Icon(LucideIcons.arrowUpDown, size: 18, color: colors.primary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Toggle: Slippage guard (Min receive)
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 18, color: colors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Slippage guard (Min receive)',
                    style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
              ),
              Switch(value: useMinGuard, onChanged: onToggleMinGuard),
            ],
          ),

          if (useMinGuard) ...[
            const SizedBox(height: 8),
            _LabeledField(
              label: 'Min receive ($to)',
              hint: '0.0',
              icon: LucideIcons.checkCircle2,
              controller: minOutCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}$')),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Slippage slider
          _SlippageSection(value: slippage, onChanged: onSlippageChanged),
        ],
      ),
    );
  }

  Widget? _buildValidatorHint(BuildContext context, bool ok, String from) {
    final colors = AppColor.of(context);
    if (ok) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle, size: 14, color: colors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              from == 'TRX'
                  ? 'Not enough TRX. Leave a small amount for fees.'
                  : 'Not enough $from balance.',
              style: TextStyle(color: colors.warning, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.trailing,
    this.validatorHint,
    this.inputFormatters,
  });
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final Widget? validatorHint;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hint,
            filled: true,
            fillColor: colors.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        if (validatorHint != null) validatorHint!,
      ],
    );
  }
}

class _SlippageSection extends StatelessWidget {
  const _SlippageSection({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Slippage tolerance', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Slider(
                value: value,
                min: 0.1,
                max: 5.0,
                divisions: 49,
                label: '${value.toStringAsFixed(1)}%',
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '${value.toStringAsFixed(1)}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final p in const [0.1, 0.5, 1.0, 2.0])
                _QuickChip(
                  percent: p,
                  onTap: () => onChanged(p),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tip: Keep slippage low for safety. If your swap keeps failing, raise it slightly.',
            style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({this.percent, this.label, required this.onTap});
  final double? percent;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final text = label ?? '${percent!.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}${percent != null ? (percent! <= 1 ? 'x' : '') : ''}';
    // For percent chips, we display 25%, 50%, 75%. For slippage preset we pass numbers like 0.1, 0.5, 1.0.
    final display = label ?? '${(percent! * 100).toStringAsFixed(0)}%';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label != null ? label! : display,
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.colors});
  final AppColor colors;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.info.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(LucideIcons.info, color: colors.info),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'SunSwap is used under the hood. Use the slider for tolerance. '
                'Turn ON “Slippage guard” to set a hard minimum receive. Fee limit is set to 30 TRX; actual consumed may be lower depending on energy.',
            style: TextStyle(color: colors.textSecondary, height: 1.25),
          ),
        ),
      ]),
    );
  }
}

/* ===================== Logo helpers (AssetProvider) ===================== */

class _AssetLogo extends StatefulWidget {
  const _AssetLogo({required this.assetKey, this.size = 24, this.invert = false});
  final String assetKey; // 'tron' or 'tether_trc20'
  final double size;
  final bool invert; // when pill is selected (white text), keep logo visible
  @override
  State<_AssetLogo> createState() => _AssetLogoState();
}

class _AssetLogoState extends State<_AssetLogo> {
  int _idx = 0;
  late List<String> _urls;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logos = context.read<AssetProvider>();
    final first = logos.logoFor(widget.assetKey);
    final isUsdt = widget.assetKey.toLowerCase().contains('usdt') ||
        widget.assetKey.toLowerCase().contains('tether');
    _urls = [
      first,
      if (isUsdt) ...AssetProvider.usdtLogoFallbacks,
    ];
    _idx = 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final size = widget.size;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        color: widget.invert ? Colors.white.withOpacity(0.9) : Colors.transparent,
        child: Image.network(
          _urls[_idx],
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          frameBuilder: (ctx, child, frame, _) {
            if (frame == null) {
              return Center(
                child: SizedBox(
                  width: size * .5,
                  height: size * .5,
                  child: const CircularProgressIndicator(strokeWidth: 1.6),
                ),
              );
            }
            return child;
          },
          errorBuilder: (ctx, err, stack) {
            if (_idx + 1 < _urls.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _idx++));
              return const SizedBox.shrink();
            }
            // ultimate fallback: colored circle with first letter
            final letter = widget.assetKey.toUpperCase().startsWith('T') ? 'T' : 'U';
            return Container(
              color: widget.invert ? Colors.white : colors.primary.withOpacity(0.12),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  color: widget.invert ? colors.primary : colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: size * .5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
