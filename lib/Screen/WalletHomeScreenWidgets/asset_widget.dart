// lib/Screen/WalletHomeScreenWidgets/asset_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:next_fi/Model/asset_model.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Screen/receive_screen.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/Components/AppAlert.dart';

enum PriceWindow { h24, d7, d30, y1 }

class AssetWidget extends StatelessWidget {
  const AssetWidget({
    super.key,
    required this.colors,
    required this.assets,
    required this.logos,
    required this.xlmBalance,
    required this.usdcBalance,
    required this.address, // used to open ReceiveScreen
    this.loading = false,
    this.onRefresh,
    this.window = PriceWindow.h24,
    this.onItemTap, // optional override
  });

  final AppColor colors;
  final List<AssetModel> assets;
  final Map<String, String> logos;
  final double xlmBalance;
  final double usdcBalance;
  final String address; // wallet public address
  final bool loading;
  final Future<void> Function()? onRefresh;
  final PriceWindow window;

  /// Optional override if you want to handle navigation yourself.
  /// Receives the token string ('XLM' or 'USDC') that was tapped.
  final void Function(String token)? onItemTap;

  double _balanceFor(AssetModel a) {
    switch (a.symbol.toUpperCase()) {
      case 'XLM':
        return xlmBalance;
      case 'USDC':
        return usdcBalance;
      default:
        return 0.0;
    }
  }

  double _fiatFor(BuildContext ctx, AssetModel a) {
    final cur = ctx.read<CurrencyProvider>();
    switch (a.symbol.toUpperCase()) {
      case 'XLM':
        return cur.xlmToFiat(xlmBalance);
      case 'USDC':
        return cur.usdcToFiat(usdcBalance);
      default:
        return 0.0;
    }
  }

  double _pctFor(AssetModel a) {
    switch (window) {
      case PriceWindow.h24:
        return a.priceChangePercent24h;
      case PriceWindow.d7:
        return a.priceChangePercent7d;
      case PriceWindow.d30:
        return a.priceChangePercent30d;
      case PriceWindow.y1:
        return a.priceChangePercent1y;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Formatting helpers
  // ────────────────────────────────────────────────────────────────────────────

  String formatTokenAmount(double v,
      {int bigMaxDecimals = 4, int smallMaxDecimals = 7, double tinyCutoff = 1e-7}) {
    if (v == 0 || v.isNaN) return '0';
    if (v.abs() < tinyCutoff) return '< 0.0000001';

    if (v.abs() >= 1.0) {
      final fmt = NumberFormat('#,##0.${'#' * bigMaxDecimals}');
      return _trimZeros(fmt.format(v));
    } else {
      final fmt = NumberFormat('0.${'#' * smallMaxDecimals}');
      return _trimZeros(fmt.format(v));
    }
  }

  String _trimZeros(String s) {
    if (!s.contains('.')) return s;
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  void _openReceive(BuildContext context, AssetModel a) {
    final t = a.symbol.toUpperCase();
    final token = (t == 'USDC') ? 'USDC' : 'XLM'; // default to XLM if unknown

    if (onItemTap != null) {
      onItemTap!(token);
      return;
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReceiveScreen(
        address: address,
        xlmBalance: xlmBalance,
        usdcBalance: usdcBalance,
        initialToken: token, // initial tab based on tapped tile
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final currencyCode = context.watch<CurrencyProvider>().fiat.toUpperCase();
    final money = NumberFormat.simpleCurrency(name: currencyCode);

    if (loading) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, __) => _shimmerTile(),
      );
    }

    final listView = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: assets.length + 1, // +1 for the footer
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        if (index < assets.length) {
          final a = assets[index];
          final bal = _balanceFor(a);
          final fiat = _fiatFor(context, a);
          final pct = _pctFor(a);
          final logoUrl = logos[a.id];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _openReceive(context, a),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      _logo(logoUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              "${formatTokenAmount(bal)} ${a.symbol}",
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(money.format(fiat),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary)),
                          const SizedBox(height: 2),
                          _pctBadge(pct),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // ---- Rate limit footer (single, after all tiles) ----
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _RateLimitFooter(colors: colors),
          );
        }
      },
    );

    return onRefresh != null
        ? RefreshIndicator(onRefresh: onRefresh!, color: colors.primary, child: listView)
        : listView;
  }

  // --- small UI helpers ---

  Widget _logo(String? url, {double size = 36}) {
    if (url == null || url.isEmpty) return _logoFallback(size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _logoFallback(size),
        loadingBuilder: (ctx, child, progress) => progress == null
            ? child
            : SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.border.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image_not_supported,
          size: size * 0.6, color: colors.textSecondary.withOpacity(0.6)),
    );
  }

  Widget _pctBadge(double pct) {
    final positive = pct >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          positive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          color: positive ? Colors.green : Colors.red,
          size: 18,
        ),
        Text(
          "${pct.abs().toStringAsFixed(2)}%",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: positive ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _shimmerTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Shimmer.fromColors(
        baseColor: colors.border.withOpacity(0.30),
        highlightColor: colors.border.withOpacity(0.12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 140, height: 14, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(width: 90, height: 12, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 72, height: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Rate Limit Footer (single banner shown once at the very bottom)
// ──────────────────────────────────────────────────────────────────────────────

class _RateLimitFooter extends StatefulWidget {
  const _RateLimitFooter({required this.colors});
  final AppColor colors;

  @override
  State<_RateLimitFooter> createState() => _RateLimitFooterState();
}

class _RateLimitFooterState extends State<_RateLimitFooter> {
  late StellarWalletService _svc;
  StreamSubscription<RateLimitInfo>? _sub;
  Timer? _ticker;
  RateLimitInfo? _info;

  // Alert control: show once per window
  AppAlertController? _alertCtl;
  String? _windowKeyShown; // key tied to resetAt to avoid duplicates

  static const int _nearZeroThreshold = 25; // trigger "near zero" warning

  @override
  void initState() {
    super.initState();
    try {
      _svc = context.read<StellarWalletService>();
    } catch (_) {
      _svc = StellarWalletService(); // default (PUBLIC)
    }
    _sub = _svc.rateLimitStream().listen((rl) {
      setState(() {
        _info = rl;
        _maybeShowAlert(rl);
      });
    });
    _svc.fetchRateLimitInfo().then((rl) {
      if (!mounted) return;
      setState(() {
        _info = rl ?? _info;
        if (rl != null) _maybeShowAlert(rl);
      });
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {}); // refresh countdown text
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    _alertCtl?.close();
    _alertCtl = null;
    super.dispose();
  }

  void _maybeShowAlert(RateLimitInfo rl) {
    final remaining = rl.remaining;
    if (remaining == null) return;

    // Build a "window key" that changes whenever the reset time changes.
    final key = rl.resetAt?.toIso8601String() ?? 'no-reset-${rl.limitPerWindow}-${remaining}';
    final alreadyShown = (_windowKeyShown == key);

    // Only alert once per window unless we escalate to 0 (error).
    if (remaining > 0 && alreadyShown) return;

    final resetIn = rl.resetIn;
    final resetTxt = _fmtReset(resetIn);
    final isZero = remaining == 0;
    final isNear = remaining > 0 && remaining <= _nearZeroThreshold;

    if (isZero) {
      _windowKeyShown = key;
      _alertCtl?.close();
      _alertCtl = showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'Out of Horizon requests',
        subtitle:
        'You have 0 remaining API requests for this window.\n\n'
            'Resets in $resetTxt.\n\nTips:\n'
            '• Wait for the reset\n'
            '• Reduce polling and prefer streaming\n'
            '• Switch to another Horizon endpoint (if configured)',
        primaryText: 'OK',
        barrierDismissible: true,
      );
    } else if (isNear && !alreadyShown) {
      _windowKeyShown = key;
      _alertCtl?.close();
      _alertCtl = showAppAlert(
        context,
        type: AppAlertType.warning,
        title: 'Almost out of requests',
        subtitle:
        'Only $remaining request(s) left in this window.\n'
            'Resets in $resetTxt.\n\nTo avoid interruptions, reduce polling or use streaming.',
        primaryText: 'Got it',
        barrierDismissible: true,
      );
    }
  }

  String _fmtReset(Duration? d) {
    if (d == null) return '—';
    if (d.isNegative) return '0s';
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    if (m > 0) return '$m:${r.toString().padLeft(2, '0')}';
    return '${s}s';
  }

  Color _pillColor(int? remaining) {
    final c = widget.colors;
    if (remaining == null) return c.textSecondary.withOpacity(0.25);
    if (remaining == 0) return Colors.red.withOpacity(0.18);
    if (remaining < 100) return Colors.red.withOpacity(0.15);
    if (remaining < 500) return Colors.orange.withOpacity(0.18);
    return Colors.green.withOpacity(0.15);
  }

  Color _pillText(int? remaining) {
    if (remaining == null) return Colors.grey.shade600;
    if (remaining == 0) return Colors.red.shade700;
    if (remaining < 100) return Colors.red.shade700;
    if (remaining < 500) return Colors.orange.shade800;
    return Colors.green.shade800;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final rl = _info;

    final remaining = rl?.remaining;
    final limit = rl?.limitPerWindow;
    final resetIn = rl?.resetIn;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withOpacity(0.6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.speed, size: 18, color: c.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Horizon rate limit',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          _ChipLabel(
            bg: _pillColor(remaining),
            fg: _pillText(remaining),
            label: remaining == null
                ? 'Unknown'
                : (limit == null ? '$remaining left' : '$remaining / $limit left'),
          ),
          const SizedBox(width: 8),
          _ChipLabel(
            bg: c.border.withOpacity(0.18),
            fg: c.textSecondary,
            label: 'Resets in ${_fmtReset(resetIn)}',
          ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.bg, required this.fg, required this.label});
  final Color bg;
  final Color fg;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
