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
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
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

  String get _volatilityLabel => widget.isNative ? 'Volatile' : 'Stable';

  String _priceLine(String symbol) {
    return '1 $symbol ~ ${widget.money.format(widget.coinPriceNow)}';
  }

  @override
  Widget build(BuildContext context) {
    final trendUp = widget.priceDelta >= 0;
    final trendColor = trendUp ? widget.colors.success : widget.colors.error;
    final pctColor = widget.pct >= 0
        ? widget.colors.success
        : widget.colors.error;
    final symbol = widget.asset.symbol.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: _isPressed
                  ? widget.colors.background
                  : widget.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.colors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColor.of(
                    context,
                  ).textPrimary.withValues(alpha: 0.045),
                  blurRadius: _isPressed ? 4 : 10,
                  offset: Offset(0, _isPressed ? 1 : 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AssetLogo(
                  url: widget.logoUrl,
                  colors: widget.colors,
                  assetId: widget.asset.id,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
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
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 48,
                  color: widget.colors.border.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 104,
                    maxWidth: 132,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.money.format(widget.fiatNow),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 15.2,
                          fontWeight: FontWeight.w800,
                          color: widget.colors.textPrimary,
                          letterSpacing: -0.25,
                          height: 1.05,
                          fontFamilyFallback: _kCurrencyFontFallback,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _MiniSparkline(
                            series: widget.miniSeries,
                            color: trendColor,
                          ),
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                trendUp
                                    ? LucideIcons.trendingUp
                                    : LucideIcons.trendingDown,
                                size: 12,
                                color: trendColor,
                              ),
                              const SizedBox(width: 4),
                              _PctBadge(pct: widget.pct, color: pctColor),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.formatSignedMoney(
                          widget.money,
                          widget.priceDelta,
                        ),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: trendColor,
                          letterSpacing: -0.05,
                          fontFamilyFallback: _kCurrencyFontFallback,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _TypeBadge(
                        label: _volatilityLabel,
                        color: widget.isNative
                            ? widget.colors.primary
                            : widget.colors.success,
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

class _AssetLogo extends StatelessWidget {
  const _AssetLogo({
    required this.url,
    required this.colors,
    required this.assetId,
  });

  final String? url;
  final AppColor colors;
  final String assetId;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Icon(LucideIcons.coins, size: 22, color: colors.primary),
    );

    return SizedBox(
      width: 40,
      height: 40,
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
                        border: Border.all(color: colors.border, width: 1),
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
    );
  }
}

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
        fontSize: 10.8,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.05,
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.series, required this.color});

  final List<double> series;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final valid = series.where((v) => v.isFinite).toList(growable: false);
    if (valid.length < 2) {
      return const SizedBox(width: 36, height: 22);
    }

    return SizedBox(
      width: 36,
      height: 22,
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
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
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
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
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
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.color != color;
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.2,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.15,
          height: 1.0,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

