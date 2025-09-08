import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

enum _SwapDir { xlmToUsdc, usdcToXlm }

class _SwapScreenState extends State<SwapScreen> {
  static const double _kDustXlm = 1.0;
  static const double _EPS = 1e-6;
  static const double _slippage = 0.01; // 1%

  final _amountCtl = TextEditingController();
  final _fmt = NumberFormat('#,##0.######');

  _SwapDir _dir = _SwapDir.xlmToUsdc;
  bool _loading = true;
  String? _errorMsg;

  String? _secretSeed; // S...
  String? _accountId; // G...
  double _xlmBal = 0.0;
  double _usdcBal = 0.0;

  double? _estReceive; // quote result
  double? _feeXlm;     // estimated fee for this action
  bool _needsTrustline = false; // will a USDC trustline be created?

  StellarWalletService? _stellar;

  bool get _isXlmToUsdc => _dir == _SwapDir.xlmToUsdc;
  String get _fromSymbol => _isXlmToUsdc ? 'XLM' : 'USDC';
  String get _toSymbol => _isXlmToUsdc ? 'USDC' : 'XLM';

  double _floor6(double v) => (v * 1e6).floor() / 1e6;

  double get _availableFrom {
    if (_isXlmToUsdc) {
      final spendable = (_xlmBal - _kDustXlm).clamp(0, double.infinity);
      return _floor6(spendable.toDouble());
    }
    return _floor6(_usdcBal);
  }

  bool get _hasEnough {
    final a = double.tryParse(_amountCtl.text.trim()) ?? 0;
    return a > 0 && a <= _availableFrom + _EPS;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _amountCtl.addListener(() {
      setState(() {});
      _updateQuote();
      // fee does not depend on amount; no need to update here
    });
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
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
      final wallet = await StellarWalletService.walletFromMnemonic(mn);
      final kp = await StellarWalletService.getKeyPair(wallet, index: 0);

      // MAINNET service
      _stellar = StellarWalletService(profitAddress: kp.accountId, testnet: false);

      setState(() {
        _secretSeed = kp.secretSeed;
        _accountId = kp.accountId;
      });

      await _refreshBalances();

      // Auto-refresh balances when payments stream in.
      _stellar!.streamPayments(kp.accountId, (_) => _refreshBalances());

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _loading = false;
        _errorMsg = 'Failed to load Stellar wallet (is the account funded on mainnet?).';
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
      _clampToAvailable();
      await _updateQuote();
      await _updateFeeEstimate(); // <- update fee when balances (and trustline state) are known
    } catch (_) {
      // keep last balances/fee
    }
  }

  Future<void> _updateFeeEstimate() async {
    final svc = _stellar;
    final aid = _accountId;
    if (svc == null || aid == null) return;

    // One op for the swap itself
    int opCount = 1;

    // If swapping XLM→USDC to self and no USDC trustline, include a ChangeTrust op
    bool needsTl = false;
    if (_isXlmToUsdc) {
      try {
        needsTl = !(await svc.hasUsdcTrustline(aid));
      } catch (_) {
        needsTl = false;
      }
      if (needsTl) opCount += 1;
    }

    double? fee;
    try {
      fee = await svc.estimateNetworkFeeXlm(opCount: opCount, percentile: 95);
    } catch (_) {
      fee = null;
    }

    if (!mounted) return;
    setState(() {
      _needsTrustline = needsTl;
      _feeXlm = fee;
    });
  }

  void _flipDir() async {
    HapticFeedback.lightImpact();
    setState(() => _dir = _isXlmToUsdc ? _SwapDir.usdcToXlm : _SwapDir.xlmToUsdc);
    _clampToAvailable();
    await _updateQuote();
    await _updateFeeEstimate();
  }

  void _useMax() {
    final max = _availableFrom;
    _amountCtl.text = max <= 0 ? '' : max.toStringAsFixed(6);
  }

  void _clampToAvailable() {
    final a = double.tryParse(_amountCtl.text.trim());
    if (a == null) return;
    final cap = _availableFrom;
    if (a > cap && cap > 0) {
      _amountCtl.text = cap.toStringAsFixed(6);
    }
  }

  Future<void> _updateQuote() async {
    final amt = double.tryParse(_amountCtl.text.trim());
    final svc = _stellar;
    if (svc == null || amt == null || amt <= 0) {
      if (_estReceive != null) setState(() => _estReceive = null);
      return;
    }
    try {
      final q = _isXlmToUsdc
          ? await svc.quoteXlmToUsdc(amt)
          : await svc.quoteUsdcToXlm(amt);
      if (!mounted) return;
      setState(() => _estReceive = q);
    } catch (_) {
      // ignore transient errors; keep last estimate
    }
  }

  Future<void> _confirmAndSwap() async {
    final svc = _stellar;
    final seed = _secretSeed;
    if (svc == null || seed == null) {
      showFloatingSnackBar(context, message: 'Wallet not ready', type: SnackBarType.error);
      return;
    }

    _clampToAvailable();
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amount <= 0) {
      showFloatingSnackBar(context, message: 'Enter amount', type: SnackBarType.error);
      return;
    }
    if (!_hasEnough) {
      showFloatingSnackBar(context, message: 'Insufficient balance', type: SnackBarType.error);
      return;
    }

    // Ensure a fresh-ish fee estimate before confirm
    await _updateFeeEstimate();

    // Require a current quote to compute minOut with slippage.
    double? est = _estReceive;
    est ??= _isXlmToUsdc ? await svc.quoteXlmToUsdc(amount) : await svc.quoteUsdcToXlm(amount);
    if (est == null) {
      showFloatingSnackBar(
        context,
        message: 'No price quote available on mainnet. Try a slightly different amount.',
        type: SnackBarType.error,
      );
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
            const SizedBox(height: 10),
            Text('Confirm Swap',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
            const SizedBox(height: 12),
            _InfoRow('From', '${_fmt.format(amount)} $_fromSymbol'),
            _InfoRow('To (est.)', '${_fmt.format(est)} $_toSymbol'),
            _InfoRow('Slippage', '1%'),
            _InfoRow('Min receive', '${_fmt.format(minOut)} $_toSymbol'),
            _InfoRow(
              'Network fee',
              _feeXlm == null
                  ? '—'
                  : '≈ ${_fmt.format(_feeXlm!)} XLM${_needsTrustline ? ' (incl. trustline)' : ''}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.primary.withOpacity(0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _doSwap(amount, minOut);
                    },
                    icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
                    label: const Text('Swap now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doSwap(double amount, double minOut) async {
    final svc = _stellar!;
    final seed = _secretSeed!;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final txid = _isXlmToUsdc
          ? await svc.swapXlmToUsdc(secretSeed: seed, sendAmountXlm: amount, minUsdcOut: minOut)
          : await svc.swapUsdcToXlm(secretSeed: seed, sendAmountUsdc: amount, minXlmOut: minOut);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showFloatingSnackBar(context, type: SnackBarType.success, message: 'Swap submitted\n$txid');
      _amountCtl.clear();
      await _refreshBalances();
    } catch (e) {
      if (!mounted) return;
      showFloatingSnackBar(context, message: 'Swap failed: $e', type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Swap'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _refreshBalances,
          ),
        ],
      ),
      body: _loading && _accountId == null
          ? const _PageLoader()
          : _errorMsg != null
          ? _ErrorCard(message: _errorMsg!)
          : Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BalanceRow(xlm: _xlmBal, usdc: _usdcBal),
            const SizedBox(height: 10),
            _DirectionSwitcher(isXlmToUsdc: _isXlmToUsdc, onFlip: _flipDir),
            const SizedBox(height: 10),
            _AmountField(label: 'You send ($_fromSymbol)', controller: _amountCtl, onUseMax: _useMax),
            if (_isXlmToUsdc) ...[
              const SizedBox(height: 6),
              const _HintBox(
                text: 'We keep 1 XLM for fees & account reserve. “MAX” uses only your spendable amount.',
              ),
            ],
            const SizedBox(height: 10),
            _TinyInfoRow(
              icon: LucideIcons.badgeDollarSign,
              text: _estReceive == null
                  ? 'Estimating receive on mainnet…'
                  : 'Est. receive: ${_fmt.format(_estReceive!)} $_toSymbol · Slippage: 1%'
                  '${_feeXlm == null ? '' : ' · Fee≈ ${_fmt.format(_feeXlm!)} XLM${_needsTrustline ? ' (incl. trustline)' : ''}'}',
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: (_loading || !_hasEnough) ? null : _confirmAndSwap,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(LucideIcons.arrowRightLeft),
              label: Text(_isXlmToUsdc ? 'Swap XLM → USDC' : 'Swap USDC → XLM'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- Small UI bits ---------------- */

class _PageLoader extends StatelessWidget {
  const _PageLoader();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.only(top: 60),
      child: SizedBox(height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.error.withOpacity(0.2)),
        ),
        child: Text(message, style: TextStyle(color: c.error)),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final double xlm, usdc;
  const _BalanceRow({required this.xlm, required this.usdc});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    String _num(double v) => v.toStringAsFixed(v >= 100 ? 2 : 4);

    Widget chip(String assetKey, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(assetKey == 'XLM' ? LucideIcons.star : LucideIcons.coins, size: 16, color: c.textSecondary),
          const SizedBox(width: 6),
          Text('$assetKey: ', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          Text(value, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        ],
      ),
    );

    return Row(
      children: [
        Expanded(child: chip('XLM', _num(xlm))),
        const SizedBox(width: 8),
        Expanded(child: chip('USDC', _num(usdc))),
      ],
    );
  }
}

class _DirectionSwitcher extends StatelessWidget {
  final bool isXlmToUsdc;
  final VoidCallback onFlip;
  const _DirectionSwitcher({required this.isXlmToUsdc, required this.onFlip});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegBtn(
              active: isXlmToUsdc,
              label: 'XLM → USDC',
              onTap: () {
                if (!isXlmToUsdc) onFlip();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegBtn(
              active: !isXlmToUsdc,
              label: 'USDC → XLM',
              onTap: () {
                if (isXlmToUsdc) onFlip();
              },
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onFlip,
            icon: Icon(LucideIcons.arrowUpDown, color: c.primary),
            tooltip: 'Flip',
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;
  const _SegBtn({required this.active, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: active ? Colors.white : c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onUseMax;
  const _AmountField({required this.label, required this.controller, required this.onUseMax});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$'))],
                decoration: InputDecoration(
                  hintText: '0.0',
                  filled: true,
                  fillColor: c.primary.withOpacity(0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.primary.withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.primary, width: 1.2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onUseMax,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.primary.withOpacity(0.35)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                minimumSize: const Size(52, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('MAX', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ],
    );
  }
}

class _TinyInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TinyInfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: c.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          const Spacer(),
          Text(value, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  final String text;
  const _HintBox({required this.text});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.info, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: c.textSecondary))),
        ],
      ),
    );
  }
}
