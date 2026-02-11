import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/reusable_model/asset_model.dart';

class ModernAssetTile extends StatefulWidget {
  final AssetModel asset;
  final AppColor colors;
  final String? logoUrl;
  final double balance;
  final double pct;
  final double coinPriceNow;
  final double fiatNow;
  final double priceDelta;
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
    required this.money,
    required this.onTap,
    required this.formatTokenAmount,
    required this.formatSignedMoney,
    this.isNative = false,
  });

  @override
  State<ModernAssetTile> createState() => _ModernAssetTileState();
}

class _ModernAssetTileState extends State<ModernAssetTile> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hoverAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _hoverController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isUp = widget.priceDelta >= 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trendColor = isUp ? widget.colors.success : widget.colors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _hoverController.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _hoverController.reverse();
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isPressed || _isHovered
                      ? [
                    widget.colors.surface.withOpacity(0.5),
                    widget.colors.surface.withOpacity(0.3),
                  ]
                      : [
                    widget.colors.surface.withOpacity(0.4),
                    widget.colors.surface.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isPressed
                      ? trendColor.withOpacity(0.3)
                      : _isHovered
                      ? widget.colors.primary.withOpacity(0.2)
                      : widget.colors.primary.withOpacity(0.08),
                  width: _isPressed || _isHovered ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isPressed
                        ? trendColor.withOpacity(0.15)
                        : _isHovered
                        ? widget.colors.primary.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: _isPressed ? 12 : (_isHovered ? 16 : 8),
                    offset: Offset(0, _isPressed ? 2 : (_isHovered ? 4 : 2)),
                    spreadRadius: _isPressed ? 0 : (_isHovered ? 1 : 0),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildEnhancedLogo(widget.logoUrl, isDark, trendColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Balance amount - responsive sizing
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final balanceText = "${widget.formatTokenAmount(widget.balance)} ${widget.asset.symbol}";

                            // Calculate responsive font size based on text length
                            double fontSize = 16;
                            if (balanceText.length > 25) {
                              fontSize = 12;
                            } else if (balanceText.length > 20) {
                              fontSize = 13;
                            } else if (balanceText.length > 15) {
                              fontSize = 14.5;
                            }

                            return Text(
                              balanceText,
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w800,
                                color: widget.colors.textPrimary,
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        // Asset name
                        Text(
                          widget.asset.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.colors.textSecondary.withOpacity(0.9),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Price per coin with badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: widget.colors.textSecondary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${widget.money.format(widget.coinPriceNow)} / ${widget.asset.symbol}",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: widget.colors.textSecondary.withOpacity(0.8),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildAssetTypeBadge(isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Right side - Values (also made responsive)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Fiat value - responsive
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final fiatText = widget.money.format(widget.fiatNow);

                          // Calculate responsive font size for fiat value
                          double fontSize = 17;
                          if (fiatText.length > 12) {
                            fontSize = 13;
                          } else if (fiatText.length > 10) {
                            fontSize = 14.5;
                          } else if (fiatText.length > 8) {
                            fontSize = 15.5;
                          }

                          return Text(
                            fiatText,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w800,
                              color: widget.colors.textPrimary,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      // Percentage badge
                      _buildModernPctBadge(widget.pct, isDark, trendColor),
                      const SizedBox(height: 6),
                      // Price change
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: trendColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.formatSignedMoney(widget.money, widget.priceDelta),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: trendColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetTypeBadge(bool isDark) {
    final badgeColor = widget.isNative
        ? widget.colors.primary // Volatile (native)
        : widget.colors.success; // Stable

    final label = widget.isNative ? 'VOLATILE' : 'STABLE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: badgeColor,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildEnhancedLogo(String? url, bool isDark, Color trendColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (_isPressed || _isHovered ? trendColor : widget.colors.primary).withOpacity(0.15),
            (_isPressed || _isHovered ? trendColor : widget.colors.primary).withOpacity(0.05),
          ],
        ),

      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: url == null || url.isEmpty
            ? Container(
          child: Icon(
            LucideIcons.coins,
            size: 26,
            color: (_isPressed || _isHovered ? trendColor : widget.colors.primary).withOpacity(0.6),
          ),
        )
            : Hero(
          tag: 'asset_logo_${widget.asset.id}',
          child: Stack(
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                width: 52,
                height: 52,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.colors.primary.withOpacity(0.2),
                        widget.colors.primary.withOpacity(0.08),
                      ],
                    ),
                  ),
                  child: Icon(
                    LucideIcons.coins,
                    size: 26,
                    color: widget.colors.primary.withOpacity(0.6),
                  ),
                ),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: widget.colors.border.withOpacity(0.1),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: widget.colors.primary.withOpacity(0.4),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Subtle overlay on hover/press
              if (_isPressed || _isHovered)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        trendColor.withOpacity(_isPressed ? 0.15 : 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernPctBadge(double pct, bool isDark, Color trendColor) {
    final positive = pct >= 0;
    final icon = positive ? LucideIcons.trendingUp : LucideIcons.trendingDown;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            trendColor.withOpacity(_isPressed ? 0.2 : (_isHovered ? 0.18 : 0.15)),
            trendColor.withOpacity(_isPressed ? 0.15 : (_isHovered ? 0.12 : 0.1)),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: trendColor.withOpacity(_isPressed || _isHovered ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: trendColor),
          const SizedBox(width: 4),
          Text(
            "${pct.abs().toStringAsFixed(2)}%",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: trendColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}