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
  late AnimationController _shimmerController;
  late Animation<double> _shimmerPosition;
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

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _shimmerPosition = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
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
    _shimmerController.dispose();
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
    final trendColor = isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _isPressed
                        ? widget.colors.primary.withOpacity(isDark ? 0.2 : 0.12)
                        : _isHovered
                        ? widget.colors.primary.withOpacity(isDark ? 0.15 : 0.08)
                        : Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                    blurRadius: _isPressed ? 16 : (_isHovered ? 20 : 12),
                    offset: Offset(0, _isPressed ? 2 : (_isHovered ? 6 : 4)),
                    spreadRadius: _isPressed ? 0 : (_isHovered ? 2 : 0),
                  ),
                  if (_isHovered)
                    BoxShadow(
                      color: widget.colors.primary.withOpacity(0.05),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Gradient background based on trend
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isPressed || _isHovered
                              ? [
                            trendColor.withOpacity(isDark ? 0.08 : 0.04),
                            Theme.of(context).cardColor,
                          ]
                              : [
                            Theme.of(context).cardColor,
                            Theme.of(context).cardColor,
                          ],
                        ),
                      ),
                    ),
                    // Multi-layer shimmer effect
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shimmerPosition,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.transparent,
                                  (_isPressed || _isHovered
                                      ? trendColor
                                      : widget.colors.primary)
                                      .withOpacity(_isPressed ? 0.18 : (_isHovered ? 0.12 : 0.06)),
                                  Colors.transparent,
                                ],
                                stops: [
                                  (_shimmerPosition.value - 0.25).clamp(0.0, 1.0),
                                  _shimmerPosition.value.clamp(0.0, 1.0),
                                  (_shimmerPosition.value + 0.25).clamp(0.0, 1.0),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Border
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isPressed
                              ? trendColor.withOpacity(0.3)
                              : _isHovered
                              ? widget.colors.primary.withOpacity(0.25)
                              : widget.colors.border.withOpacity(isDark ? 0.12 : 0.08),
                          width: _isPressed || _isHovered ? 1.5 : 1,
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          _buildEnhancedLogo(widget.logoUrl, isDark, trendColor),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Balance amount - responsive sizing
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final balanceText = "${widget.formatTokenAmount(widget.balance)} ${widget.asset.symbol}";

                                    // Calculate responsive font size based on text length
                                    double fontSize = 17;
                                    if (balanceText.length > 25) {
                                      fontSize = 13;
                                    } else if (balanceText.length > 20) {
                                      fontSize = 14;
                                    } else if (balanceText.length > 15) {
                                      fontSize = 15.5;
                                    }

                                    return Text(
                                      balanceText,
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
                                const SizedBox(height: 8),
                                // Asset name
                                Text(
                                  widget.asset.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: widget.colors.textSecondary,
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: widget.colors.textSecondary.withOpacity(isDark ? 0.08 : 0.05),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "${widget.money.format(widget.coinPriceNow)} / ${widget.asset.symbol}",
                                        style: TextStyle(
                                          fontSize: 11,
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
                          const SizedBox(width: 16),
                          // Right side - Values (also made responsive)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Fiat value - responsive
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final fiatText = widget.money.format(widget.fiatNow);

                                  // Calculate responsive font size for fiat value
                                  double fontSize = 18;
                                  if (fiatText.length > 12) {
                                    fontSize = 14;
                                  } else if (fiatText.length > 10) {
                                    fontSize = 15.5;
                                  } else if (fiatText.length > 8) {
                                    fontSize = 16.5;
                                  }

                                  return Text(
                                    fiatText,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w800,
                                      color: widget.colors.textPrimary,
                                      letterSpacing: -0.5,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              // Percentage badge
                              _buildModernPctBadge(widget.pct, isDark, trendColor),
                              const SizedBox(height: 6),
                              // Price change
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: trendColor.withOpacity(isDark ? 0.12 : 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.formatSignedMoney(widget.money, widget.priceDelta),
                                  style: TextStyle(
                                    fontSize: 12,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetTypeBadge(bool isDark) {
    final badgeColor = widget.isNative
        ? AppColor.of(context).primary   // Volatile (native XLM)
        : AppColor.of(context).primary; // Stable (USDC, etc.)

    final label = widget.isNative ? 'VOLATILE' : 'STABLE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: badgeColor,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: Colors.white, // White text
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEnhancedLogo(String? url, bool isDark, Color trendColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isPressed || _isHovered ? trendColor : widget.colors.primary)
                .withOpacity(_isPressed ? 0.25 : (_isHovered ? 0.15 : 0.08)),
            blurRadius: _isPressed ? 12 : (_isHovered ? 16 : 8),
            offset: Offset(0, _isPressed ? 2 : (_isHovered ? 4 : 2)),
            spreadRadius: _isPressed ? 0 : (_isHovered ? 1 : 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: url == null || url.isEmpty
            ? Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (_isPressed || _isHovered ? trendColor : widget.colors.primary)
                    .withOpacity(0.2),
                (_isPressed || _isHovered ? trendColor : widget.colors.primary)
                    .withOpacity(0.08),
              ],
            ),
          ),
          child: Icon(
            LucideIcons.coins,
            size: 28,
            color: (_isPressed || _isHovered ? trendColor : widget.colors.primary)
                .withOpacity(0.6),
          ),
        )
            : Hero(
          tag: 'asset_logo_${widget.asset.id}',
          child: Stack(
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                width: 56,
                height: 56,
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
                    size: 28,
                    color: widget.colors.primary.withOpacity(0.6),
                  ),
                ),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: widget.colors.border.withOpacity(0.1),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: widget.colors.primary.withOpacity(0.4),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Gradient overlay on hover/press
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            trendColor.withOpacity(_isPressed ? 0.25 : (_isHovered ? 0.2 : (isDark ? 0.18 : 0.15))),
            trendColor.withOpacity(_isPressed ? 0.18 : (_isHovered ? 0.15 : (isDark ? 0.12 : 0.1))),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: trendColor.withOpacity(_isPressed || _isHovered ? 0.3 : 0.2),
          width: 1,
        ),
        boxShadow: _isPressed || _isHovered
            ? [
          BoxShadow(
            color: trendColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: trendColor),
          const SizedBox(width: 5),
          Text(
            "${pct.abs().toStringAsFixed(2)}%",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: trendColor,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}