import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/AssetProvider.dart';
import 'package:next_fi/Services/seed_storage.dart';

// Compact UI kit (XLM/USDC variants)
import 'package:next_fi/Screen/SwapScreenWidgets/swap_widgets.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';



class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

enum _SwapDir { xlmToUsdc, usdcToXlm }

class _SwapScreenState extends State<SwapScreen> with TickerProviderStateMixin {
  // Keep at least this much XLM to cover base reserve/fees.
  static const double _kDustXlm = 1.0;
  static const double _EPS = 1e-6; // use 6-decimal epsilon (matches UI precision)

  // Controllers
  final _amountCtl = TextEditingController();

  // Format (UI only)
  final _fmt = NumberFormat('#,##0.######');

  // State
  _SwapDir _dir = _SwapDir.xlmToUsdc;
  bool _loading = true;
  String? _errorMsg;

  String? _secretSeed; // Stellar secret seed (S...)
  String? _accountId;  // Stellar account id (G...)

  double _xlmBal = 0.0;
  double _usdcBal = 0.0;

  // Anim
  late final AnimationController _swapSpin =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  // Stellar
  StellarWalletService? _stellar;

  /* ---------------- Helpers ---------------- */
  double _floor6(double v) => (v * 1e6).floor() / 1e6;

  bool get _isXlmToUsdc => _dir == _SwapDir.xlmToUsdc;
  String get _fromSymbol => _isXlmToUsdc ? 'XLM' : 'USDC';
  String get _toSymbol => _isXlmToUsdc ? 'USDC' : 'XLM';

  String get _fromKey => _fromSymbol; // used by TokenLogo
  String get _toKey => _toSymbol;

  /// Available balance from the selected "from" side (dust-aware for XLM).
  double get _availableFrom {
    if (_isXlmToUsdc) {
      final spendable = (_xlmBal - _kDustXlm).clamp(0, double.infinity);
      return _floor6(spendable.toDouble()); // floor to avoid rounding above cap
    }
    return _floor6(_usdcBal);
  }

  /// True when the typed amount is positive and <= available balance (with epsilon).
  bool get _hasEnoughBalance {
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0.0;
    return amount > 0 && amount <= _availableFrom + _EPS;
  }

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
        _secretSeed = _seedStringFromKeyPair(kp);
        _accountId = kp.accountId;
      });

      await _refreshBalances();

      // Start listening for incoming payments to refresh balances (fire-and-forget).
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
      _sanityClampToAvailable(); // keep field legal if balances changed
    } catch (_) {
      // Keep previous on errors
    }
  }

  /* ---------------- UI/logic helpers ---------------- */
  void _flipDirection() {
    HapticFeedback.lightImpact();
    _swapSpin.forward(from: 0);
    setState(() {
      _dir = _isXlmToUsdc ? _SwapDir.usdcToXlm : _SwapDir.xlmToUsdc;
    });
    _sanityClampToAvailable();
  }

  // Set to the true maximum spendable (auto leaves 1 XLM on XLM→USDC).
  void _useMax() {
    final max = _availableFrom;
    _amountCtl.text = max <= 0 ? '' : max.toStringAsFixed(6);
  }

  void _quickPercent(double p) {
    final base = _availableFrom;
    var v = _floor6(base * p);       // floor to 6 to prevent rounding above cap
    v = v.clamp(0, base);
    _amountCtl.text = v <= 0 ? '' : v.toStringAsFixed(6);
  }

  void _onAmountInput() {
    _sanityClampToAvailable();
    setState(() {}); // re-eval button enable state
  }

  // ✅ Works whether KeyPair.secretSeed is a String or bytes.
  String _seedStringFromKeyPair(KeyPair kp) {
    final dynamic ss = kp.secretSeed;
    if (ss == null) throw Exception('KeyPair has no secret seed');
    if (ss is String) return ss;
    if (ss is Iterable<int>) return String.fromCharCodes(ss);
    throw Exception('Unsupported secretSeed type: ${ss.runtimeType}');
  }

  // Clamp typed amount to available (no snackbars).
  void _sanityClampToAvailable() {
    final raw = _amountCtl.text.trim();
    final a = double.tryParse(raw);
    if (a == null) return;
    final cap = _availableFrom;
    if (a > cap && cap > 0) {
      _amountCtl.text = cap.toStringAsFixed(6);
    }
  }

  /* ---------------- Confirm → Execute ---------------- */
  Future<void> _openConfirmSheet() async {
    if (_secretSeed == null || _accountId == null || _stellar == null) {
      showFloatingSnackBar(context, message: 'Wallet not ready', type: SnackBarType.error);
      return;
    }

    // Final guard: never allow spending above the allowed cap.
    _sanityClampToAvailable();

    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amount <= 0) {
      showFloatingSnackBar(context, message: 'Enter amount', type: SnackBarType.error);
      return;
    }
    if (!_hasEnoughBalance) {
      showFloatingSnackBar(context, message: 'Insufficient balance', type: SnackBarType.error);
      return;
    }

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
              Text(
                'Confirm Swap',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary),
              ),
              const SizedBox(height: 10),

              // ✅ Logo route pill inside confirm
              _RoutePill(fromKey: _fromKey, toKey: _toKey, colors: colors),

              const SizedBox(height: 8),
              SummaryRow(label: 'Route', value: '$_fromSymbol → $_toSymbol'),
              SummaryRow(label: 'Amount', value: '${_fmt.format(amount)} $_fromSymbol'),
              const SummaryRow(label: 'Network fee', value: '≈ 0.0000100 XLM per op'),
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
                        await _executeSwap(amount: amount);
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

  Future<void> _executeSwap({required double amount}) async {
    final svc = _stellar;
    final seed = _secretSeed;
    if (svc == null || seed == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      // UI has no “min receive” now — pass 0 to disable slippage guard at service level.
      final txid = _isXlmToUsdc
          ? await svc.swapXlmToUsdc(secretSeed: seed, sendAmountXlm: amount, minUsdcOut: 0)
          : await svc.swapUsdcToXlm(secretSeed: seed, sendAmountUsdc: amount, minXlmOut: 0);

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

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0.0;

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
              BalanceRow(xlm: _xlmBal, usdc: _usdcBal),

              const SizedBox(height: 10),
              // Reuse segmented control; pass our direction bool.
              DirectionSegmented(
                isXlmToUsdc: _isXlmToUsdc, // bool only controls left/right selection
                onFlip: _flipDirection,
                controller: _swapSpin,
              ),

              const SizedBox(height: 10),

              // ✅ Logo route pill under the segmented control
              _RoutePill(fromKey: _fromKey, toKey: _toKey, colors: colors),

              const SizedBox(height: 10),
              AmountField(
                label: 'You send ($_fromSymbol)',
                controller: _amountCtl,
                onUseMax: _useMax,
                onPct: _quickPercent,
                colors: colors,
              ),

              // Tiny inline guide when doing XLM → USDC.
              if (_isXlmToUsdc) ...[
                const SizedBox(height: 6),
                _DustGuide(colors: colors),
              ],

              const SizedBox(height: 10),
              SummaryCard(
                from: _fromSymbol,
                to: _toSymbol,
                amount: amount,
                feeText: 'Auto (base fee)',
                colors: colors,
                fmt: _fmt,
              ),

              const SizedBox(height: 10),
              _TipsCard(colors: colors),

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

/* ---------- Small inline “dust” guide ---------- */
class _DustGuide extends StatelessWidget {
  final AppColor colors;
  const _DustGuide({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.info, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'We keep 1 XLM in your wallet for network fees & account reserve. '
                  'Using “Max” or “100%” won’t empty your last XLM.',
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------- “Other needs” compact tips ---------- */
class _TipsCard extends StatelessWidget {
  final AppColor colors;
  const _TipsCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12.5, color: colors.textSecondary, height: 1.35);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Swap tips', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colors.textPrimary)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  '),
            Expanded(child: Text('100% uses your spendable amount (we leave 1 XLM for reserve & fees).', style: style)),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  '),
            Expanded(child: Text('Network fee is tiny (base fee per operation).', style: style)),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  '),
            Expanded(child: Text('USDC may require a trustline on first use.', style: style)),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  '),
            Expanded(child: Text('Tap Refresh to update balances if funds arrive mid-swap.', style: style)),
          ]),
        ],
      ),
    );
  }
}

/* ---------- Logo route pill (no overflow) ---------- */
class _RoutePill extends StatelessWidget {
  final String fromKey;
  final String toKey;
  final AppColor colors; // keep consistent with AppColor.of(context)
  const _RoutePill({
    required this.fromKey,
    required this.toKey,
    required this.colors,
  });

  String _norm(String k) {
    final t = k.trim().toUpperCase();
    if (t.contains('XLM') || t.contains('STELLAR')) return 'XLM';
    return 'USDC';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AssetProvider>(
      builder: (context, assets, _) {
        final from = _norm(fromKey);
        final to = _norm(toKey);

        // Pull logo URLs from provider
        final fromUrl = assets.logoFor(from);
        final toUrl = assets.logoFor(to);

        final titleStyle = TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: colors.textPrimary,
        );
        final subStyle = TextStyle(
          fontSize: 11.5,
          color: colors.textSecondary,
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary.withOpacity(0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PillLogo(url: fromUrl, size: 22),               // FROM logo
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(from, style: titleStyle),
                      const SizedBox(width: 6),
                      Icon(LucideIcons.arrowRight, size: 14, color: colors.textSecondary),
                      const SizedBox(width: 6),
                      Text(to, style: titleStyle),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Swap route', style: subStyle),
                ],
              ),
              const SizedBox(width: 8),
              _PillLogo(url: toUrl, size: 22),                 // TO logo
            ],
          ),
        );
      },
    );
  }
}

/* ---------- Tiny overflow-proof network logo ---------- */
class _PillLogo extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  const _PillLogo({
    required this.url,
    this.size = 22,
    this.radius = 999, // circle
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.all(2),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Image.network(
              url,
              cacheWidth: (size * 3).round(),     // keep memory small & crisp
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) {
                // Keep layout stable on error
                return Icon(LucideIcons.circle, size: size * 0.6, color: Colors.black12);
              },
            ),
          ),
        ),
      ),
    );
  }

}
