import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'live_counting_balance.dart';
import 'dart:ui';

class HeaderSection extends StatefulWidget {
  const HeaderSection({
    super.key,
    required this.colors,
    required this.currencyFmt,
    required this.loadingBalances,
    required this.totalFiat,
    required this.lastBalancesAt,
    required this.onSwap,
    required this.onSend,
    required this.onReceive,
    required this.livePulse,
    required this.incomingStrip,
    this.animateTotal = false,
  });

  final AppColor colors;
  final NumberFormat currencyFmt;
  final bool loadingBalances;
  final double totalFiat;
  final DateTime? lastBalancesAt;
  final VoidCallback onSwap;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final AnimationController livePulse;
  final Widget incomingStrip;
  final bool animateTotal;

  @override
  State<HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<HeaderSection> with TickerProviderStateMixin {
  bool _hideBalance = false;
  double? _lastTotal;
  double? _deltaFiat;
  static const double _epsilon = 0.0001;

  late AnimationController _cardAnimController;
  late AnimationController _glowController;
  late Animation<double> _cardScale;
  late Animation<double> _glowPulse;

  Color get _upColor => widget.colors.success;
  Color get _downColor => widget.colors.error;

  void _onPulseStatus(AnimationStatus status) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _lastTotal = _safe(widget.totalFiat);
    _deltaFiat = null;
    widget.livePulse.addStatusListener(_onPulseStatus);

    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _cardScale = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutCubic),
    );

    _glowPulse = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant HeaderSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.livePulse != widget.livePulse) {
      oldWidget.livePulse.removeStatusListener(_onPulseStatus);
      widget.livePulse.addStatusListener(_onPulseStatus);
    }

    final current = _safe(widget.totalFiat);
    if (_lastTotal == null) {
      _lastTotal = current;
      _deltaFiat = null;
      return;
    }
    final d = current - _lastTotal!;
    if (d.abs() > _epsilon) {
      _deltaFiat = d;
      _lastTotal = current;
      _cardAnimController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.livePulse.removeStatusListener(_onPulseStatus);
    _cardAnimController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  double _safe(double v) => v.isFinite ? v : 0.0;

  bool _shouldColorize() {
    if (_hideBalance) return false;
    if (_deltaFiat == null || _deltaFiat!.abs() <= _epsilon) return false;
    return true;
  }

  Color _balanceColor() {
    if (!_shouldColorize()) return widget.colors.textPrimary;
    return _deltaFiat! >= 0 ? _upColor : _downColor;
  }

  Widget _trendIconForDelta() {
    if (!_shouldColorize()) return const SizedBox.shrink();
    final up = _deltaFiat! >= 0;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Transform.rotate(
            angle: (1 - value) * 0.5,
            child: Icon(
              up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              size: 20,
              color: up ? _upColor : _downColor,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _safe(widget.totalFiat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Balance Card with glassmorphism
        ScaleTransition(
          scale: _cardScale,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _shouldColorize()
                      ? (_deltaFiat! >= 0 ? _upColor : _downColor).withOpacity(0.2)
                      : Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.colors.surface,
                        widget.colors.surface.withOpacity(0.9),
                        if (_shouldColorize())
                          (_deltaFiat! >= 0 ? _upColor : _downColor).withOpacity(0.08),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      // Animated glow effect when balance changes
                      if (_shouldColorize())
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _glowPulse,
                            builder: (context, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.topRight,
                                    radius: 1.5,
                                    colors: [
                                      (_deltaFiat! >= 0 ? _upColor : _downColor)
                                          .withOpacity(_glowPulse.value * 0.15),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left: Balance & meta
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Label + eye
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Total Balance',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: widget.colors.textSecondary.withOpacity(0.8),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => setState(() => _hideBalance = !_hideBalance),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 200),
                                              child: Icon(
                                                _hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                                                key: ValueKey(_hideBalance),
                                                color: widget.colors.textSecondary.withOpacity(0.7),
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Balance row
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      _trendIconForDelta(),
                                      if (_shouldColorize()) const SizedBox(width: 8),
                                      Flexible(
                                        child: LiveCountingBalance(
                                          animate: widget.animateTotal,
                                          hidden: _hideBalance,
                                          targetValue: total,
                                          fmt: widget.currencyFmt,
                                          baseColor: _balanceColor(),
                                          upColor: _upColor,
                                          downColor: _downColor,
                                          loading: widget.loadingBalances,
                                          pulse: widget.livePulse,
                                          showTrendIcon: false,
                                          forceBaseColor: true,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // Delta pill
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, anim) => FadeTransition(
                                        opacity: anim,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.3),
                                            end: Offset.zero,
                                          ).animate(anim),
                                          child: child,
                                        ),
                                      ),
                                      child: (_deltaFiat != null && !_hideBalance)
                                          ? _DeltaChipFiat(
                                        key: ValueKey('${_deltaFiat!.sign}_${_lastTotal?.toStringAsFixed(2)}'),
                                        amount: _deltaFiat!,
                                        fmt: widget.currencyFmt,
                                        upColor: _upColor,
                                        downColor: _downColor,
                                        active: true,
                                        neutralColor: widget.colors.textSecondary,
                                      )
                                          : const SizedBox.shrink(key: ValueKey('empty')),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Right: primary action with enhanced style
                            _SwapButton(
                              colors: widget.colors,
                              onPressed: widget.onSwap,
                              shouldColorize: _shouldColorize(),
                              deltaColor: _deltaFiat != null && _deltaFiat! >= 0 ? _upColor : _downColor,
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

        const SizedBox(height: 8),

        // Quick actions with modern design
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.send,
                label: 'Send',
                onTap: widget.onSend,
                gradient: [widget.colors.primary.withOpacity(0.1), widget.colors.primary.withOpacity(0.05)],
              ),
              _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.download,
                label: 'Receive',
                onTap: widget.onReceive,
                gradient: [widget.colors.success.withOpacity(0.1), widget.colors.success.withOpacity(0.05)],
              ),
              _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.wallet,
                label: 'Deposit',
                onTap: () => debugPrint('Deposit'),
                gradient: [widget.colors.primary.withOpacity(0.1), widget.colors.primary.withOpacity(0.05)],
              ),
              _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.upload,
                label: 'Withdraw',
                onTap: () => debugPrint('Withdraw'),
                gradient: [widget.colors.error.withOpacity(0.1), widget.colors.error.withOpacity(0.05)],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        widget.incomingStrip,
      ],
    );
  }
}

// ────────────────── Enhanced Swap Button ──────────────────
class _SwapButton extends StatefulWidget {
  const _SwapButton({
    required this.colors,
    required this.onPressed,
    required this.shouldColorize,
    required this.deltaColor,
  });

  final AppColor colors;
  final VoidCallback onPressed;
  final bool shouldColorize;
  final Color deltaColor;

  @override
  State<_SwapButton> createState() => _SwapButtonState();
}

class _SwapButtonState extends State<_SwapButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.shouldColorize ? widget.deltaColor : widget.colors.primary;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - (_controller.value * 0.05),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    buttonColor,
                    buttonColor.withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.shuffle,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Swap',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────── Modern Action Tile ──────────────────
class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.gradient,
  });

  final AppColor colors;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final List<Color> gradient;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 - (_controller.value * 0.08),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.gradient,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.colors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: _isPressed
                        ? []
                        : [
                      BoxShadow(
                        color: widget.colors.primary.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.colors.primary,
                    size: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            widget.label,
            style: TextStyle(
              color: widget.colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────── Enhanced Delta Chip ──────────────────
class _DeltaChipFiat extends StatelessWidget {
  const _DeltaChipFiat({
    super.key,
    required this.amount,
    required this.fmt,
    required this.upColor,
    required this.downColor,
    required this.active,
    required this.neutralColor,
  });

  final double amount;
  final NumberFormat fmt;
  final Color upColor;
  final Color downColor;
  final bool active;
  final Color neutralColor;

  @override
  Widget build(BuildContext context) {
    final up = amount >= 0;
    final color = active ? (up ? upColor : downColor) : neutralColor;
    final icon = up ? LucideIcons.trendingUp : LucideIcons.trendingDown;
    final sign = up ? '+' : '−';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$sign${fmt.format(amount.abs())}',
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}