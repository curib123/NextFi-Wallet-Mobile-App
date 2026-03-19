import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/models/asset_model.dart';

const List<String> _kCurrencyFontFallback = <String>[
  'Noto Sans',
  'Noto Sans Symbols 2',
  'Roboto',
];

class ModernAssetTile extends StatefulWidget {
  final AssetModel asset;
  final AppColor colors;
  final String? logoUrl;
  final double balance;
  final double pct;
  final double coinPriceNow;
  final double fiatNow;
  final double priceDelta;
  final List<double> miniSeries;
  final NumberFormat money;
  final VoidCallback onTap;
  final String Function(double) formatTokenAmount;
  final String Function(NumberFormat, double) formatSignedMoney;
  final bool isNative;

  const ModernAssetTile({
    super.key,
    required this.asset,
    required this.colors,
    required this.logoUrl,
    required this.balance,
    required this.pct,
    required this.coinPriceNow,
    required this.fiatNow,
    required this.priceDelta,
    required this.miniSeries,
    required this.money,
    required this.onTap,
    required this.formatTokenAmount,
    required this.formatSignedMoney,
    this.isNative = false,
  });

  @override
  State<ModernAssetTile> createState() => _ModernAssetTileState();
}

class _ModernAssetTileState extends State<ModernAssetTile>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.986,
    ).animate(
        CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  _BadgeSpec? get _primaryBadge {
    final normalized = widget.asset.badges.map((badge) => badge.trim().toUpperCase()).toList();

    if (normalized.contains('EARN')) {
      return _BadgeSpec(
        label: 'Earn',
        color: widget.colors.warning,
        icon: LucideIcons.coins,
      );
    }

    if (normalized.contains('STABLE')) {
      return _BadgeSpec(
        label: 'Stable',
        color: widget.colors.success,
        icon: LucideIcons.shieldCheck,
      );
    }

    if (normalized.contains('VOLATILE')) {
      return _BadgeSpec(
        label: 'Volatile',
        color: widget.colors.primary,
        icon: LucideIcons.activity,
      );
    }

    return null;
  }

  String _priceLine(String symbol) {
    return '1 $symbol ~ ${widget.money.format(widget.coinPriceNow)}';
  }

  @override
  Widget build(BuildContext context) {
    final trendUp = widget.priceDelta >= 0;
    final trendColor =
    trendUp ? widget.colors.success : widget.colors.error;
    final pctColor =
    widget.pct >= 0 ? widget.colors.success : widget.colors.error;
    final symbol = widget.asset.symbol.toUpperCase();
    final primaryBadge = _primaryBadge;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            decoration: BoxDecoration(
              color: _isPressed
                  ? widget.colors.background
                  : widget.colors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColor.of(context)
                      .textPrimary
                      .withValues(alpha: _isPressed ? 0.03 : 0.06),
                  blurRadius: _isPressed ? 8 : 18,
                  spreadRadius: _isPressed ? 0 : 0.5,
                  offset: Offset(0, _isPressed ? 2 : 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Logo (fixed width, never shrinks) ──────────────────
                _AssetLogo(
                  url: widget.logoUrl,
                  colors: widget.colors,
                  assetId: widget.asset.id,
                  badgeLabel: primaryBadge?.label,
                  badgeColor: primaryBadge?.color,
                  badgeIcon: primaryBadge?.icon,
                ),
                const SizedBox(width: 8),

                // ── Left info column (takes all remaining space) ────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Token amount + symbol – single line, ellipsis
                      Text(
                        '${widget.formatTokenAmount(widget.balance)} $symbol',
                        style: TextStyle(
                          fontSize: 14.8,
                          fontWeight: FontWeight.w800,
                          color: widget.colors.textPrimary,
                          letterSpacing: -0.2,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Asset name
                      Text(
                        widget.asset.name,
                        style: TextStyle(
                          fontSize: 13.1,
                          fontWeight: FontWeight.w700,
                          color: widget.colors.textSecondary,
                          letterSpacing: -0.05,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Price line
                      Text(
                        _priceLine(symbol),
                        style: TextStyle(
                          fontSize: 11.1,
                          fontWeight: FontWeight.w600,
                          color: widget.colors.textSecondary,
                          letterSpacing: -0.05,
                          fontFamilyFallback: _kCurrencyFontFallback,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Divider (fixed, never flexible) ────────────────────
                Container(
                  width: 1,
                  height: 42,
                  color: widget.colors.border.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),

                // ── Right value column (intrinsic, bounded) ─────────────
                //
                // Using IntrinsicWidth so the column is only as wide as its
                // widest child, but we cap it with ConstrainedBox so it
                // never overflows on narrow screens.
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 72,
                    maxWidth: 118,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fiat value
                      Text(
                        widget.money.format(widget.fiatNow),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14.6,
                          fontWeight: FontWeight.w800,
                          color: widget.colors.textPrimary,
                          letterSpacing: -0.25,
                          height: 1.05,
                          fontFamilyFallback: _kCurrencyFontFallback,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Sparkline + trend badge row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sparkline: fixed size, never flexible
                          _MiniSparkline(
                            series: widget.miniSeries,
                            color: trendColor,
                          ),
                          const SizedBox(width: 4),
                          // Trend icon + pct badge: shrinks via FittedBox
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    trendUp
                                        ? LucideIcons.trendingUp
                                        : LucideIcons.trendingDown,
                                    size: 12,
                                    color: trendColor,
                                  ),
                                  const SizedBox(width: 3),
                                  _PctBadge(
                                    pct: widget.pct,
                                    color: pctColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Signed price delta
                      Text(
                        widget.formatSignedMoney(
                          widget.money,
                          widget.priceDelta,
                        ),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: trendColor,
                          letterSpacing: -0.05,
                          fontFamilyFallback: _kCurrencyFontFallback,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AssetLogo
// ─────────────────────────────────────────────────────────────────────────────

class _AssetLogo extends StatelessWidget {
  const _AssetLogo({
    required this.url,
    required this.colors,
    required this.assetId,
    required this.badgeLabel,
    required this.badgeColor,
    required this.badgeIcon,
  });

  final String? url;
  final AppColor colors;
  final String assetId;
  final String? badgeLabel;
  final Color? badgeColor;
  final IconData? badgeIcon;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Center(
        child: Icon(LucideIcons.coins, size: 22, color: colors.primary),
      ),
    );

    return SizedBox(
      width: 46,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Logo image – fixed 36×36 slot
          Positioned(
            top: 0,
            left: 5,
            child: SizedBox(
              width: 36,
              height: 36,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: (url == null || url!.isEmpty)
                    ? fallback
                    : Hero(
                  tag: 'asset_logo_$assetId',
                  child: Image.network(
                    url!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => fallback,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        decoration: BoxDecoration(
                          color: colors.background,
                          border: Border.all(
                            color: colors.border,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Badge – anchored to the bottom, constrained so it never spills
          if (badgeLabel != null && badgeColor != null && badgeIcon != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 50),
                  child: _TypeBadge(
                    label: badgeLabel!,
                    color: badgeColor!,
                    icon: badgeIcon!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeSpec {
  const _BadgeSpec({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

// ─────────────────────────────────────────────────────────────────────────────
// _PctBadge
// ─────────────────────────────────────────────────────────────────────────────

class _PctBadge extends StatelessWidget {
  const _PctBadge({required this.pct, required this.color});

  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    return Text(
      '${up ? '+' : '-'}${pct.abs().toStringAsFixed(2)}%',
      style: TextStyle(
        fontSize: 10.2,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.05,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MiniSparkline
// ─────────────────────────────────────────────────────────────────────────────

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.series, required this.color});

  final List<double> series;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final valid = series.where((v) => v.isFinite).toList(growable: false);
    if (valid.length < 2) {
      // Reserve space so the row doesn't collapse
      return const SizedBox(width: 30, height: 20);
    }

    return SizedBox(
      width: 30,
      height: 20,
      child: CustomPaint(
        painter: _MiniSparklinePainter(series: valid, color: color),
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  const _MiniSparklinePainter({required this.series, required this.color});

  final List<double> series;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;

    var min = series.first;
    var max = series.first;
    for (final value in series) {
      if (value < min) min = value;
      if (value > max) max = value;
    }

    final span = (max - min).abs() < 0.0001 ? 1.0 : (max - min);
    final points = <Offset>[];
    for (var i = 0; i < series.length; i++) {
      final x = size.width * i / (series.length - 1);
      final y = size.height - (((series[i] - min) / span) * size.height);
      points.add(Offset(x, y.clamp(0.0, size.height)));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX, previous.dy,
        controlX, current.dy,
        current.dx, current.dy,
      );
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// _TypeBadge
// ─────────────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppColor.of(context);
    final isStable = label.toLowerCase() == 'stable';
    final accent = isStable ? color : const Color(0xFFE28A2B);
    final bgTop = isStable
        ? accent.withValues(alpha: 0.16)
        : accent.withValues(alpha: 0.20);
    final bgBottom =
    isStable ? palette.surface : accent.withValues(alpha: 0.08);

    return Container(
      // Horizontal padding only; vertical padding is fixed so the badge
      // height is predictable and never causes layout surprises.
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgTop, bgBottom],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon dot
          SizedBox(
            width: 10,
            height: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isStable ? 0.16 : 0.18),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 6, color: accent),
              ),
            ),
          ),
          const SizedBox(width: 3),
          // Label – FittedBox prevents text overflow inside the pill
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 7.1,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 0.15,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
