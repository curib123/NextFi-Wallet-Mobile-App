import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class LiveCountingBalance extends StatefulWidget {
  LiveCountingBalance({
    super.key,
    required this.targetValue,
    required this.fmt,
    required this.baseColor,
    this.upColor,
    this.downColor,
    this.hidden = false,
    this.loading = false,
    this.pulse,
    this.animate = true,
    this.showTrendIcon = true,
    this.forceBaseColor = false,
    this.fontSize = 22,
    this.enableGlow = true,
    this.enableHaptic = false,
  });

  final double targetValue;
  final NumberFormat fmt;
  final Color baseColor;
  final Color? upColor;
  final Color? downColor;
  final bool hidden;
  final bool loading;
  final AnimationController? pulse;
  final bool animate;
  final bool showTrendIcon;
  final bool forceBaseColor;
  final double fontSize;
  final bool enableGlow;
  final bool enableHaptic;

  @override
  State<LiveCountingBalance> createState() => _LiveCountingBalanceState();
}

class _LiveCountingBalanceState extends State<LiveCountingBalance>
    with TickerProviderStateMixin {
  late double _display;
  int _dir = 0;
  Timer? _ticker;

  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _iconBounceController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _iconBounceAnimation;

  static const _tick = Duration(milliseconds: 150);
  static const _minStep = 0.01;

  @override
  void initState() {
    super.initState();
    _display = widget.targetValue.isFinite ? widget.targetValue : 0.0;

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_scaleController);

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _iconBounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _iconBounceAnimation = CurvedAnimation(
      parent: _iconBounceController,
      curve: Curves.elasticOut,
    );

    if (widget.animate) _startTicker();
  }

  @override
  void didUpdateWidget(covariant LiveCountingBalance old) {
    super.didUpdateWidget(old);

    if (old.animate != widget.animate) {
      if (widget.animate) {
        _startTicker();
      } else {
        _ticker?.cancel();
        _dir = 0;
        _display = widget.targetValue.isFinite ? widget.targetValue : 0.0;
        setState(() {});
      }
      return;
    }

    if (!widget.animate) {
      final next = widget.targetValue.isFinite ? widget.targetValue : 0.0;
      if (next != _display) {
        _display = next;
        _dir = 0;
        setState(() {});
      }
      return;
    }

    if (old.targetValue != widget.targetValue && widget.animate) {
      _restartTicker();
      _triggerAnimations();
    }
  }

  void _triggerAnimations() {
    _scaleController.forward(from: 0.0);

    if (widget.enableGlow) {
      _glowController.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _glowController.stop();
          _glowController.value = 0.0;
        }
      });
    }

    _iconBounceController.forward(from: 0.0);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) {
      if (!mounted) return;

      if (!widget.animate) {
        _ticker?.cancel();
        return;
      }

      if (!widget.targetValue.isFinite) {
        setState(() => _dir = 0);
        return;
      }

      final delta = widget.targetValue - _display;

      if (delta.abs() <= _minStep) {
        setState(() {
          _display = widget.targetValue;
          _dir = 0;
        });
        return;
      }

      final progress = 1 - (delta.abs() / (widget.targetValue.abs() + 1));
      final easing = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
      final dynamicStep = (delta.abs() / 3.5).clamp(_minStep, double.infinity) * (1 - easing * 0.7);
      final step = delta.isNegative ? -dynamicStep : dynamicStep;

      setState(() {
        _display = double.parse((_display + step).toStringAsFixed(4));
        _dir = step > 0 ? 1 : -1;
      });
    });
  }

  void _restartTicker() {
    if (!widget.animate) return;
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scaleController.dispose();
    _glowController.dispose();
    _iconBounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final upColor = widget.upColor ?? colors.success;
    final downColor = widget.downColor ?? colors.error;
    final color = widget.forceBaseColor
        ? widget.baseColor
        : (_dir == 0
            ? widget.baseColor
            : (_dir > 0 ? upColor : downColor));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.showTrendIcon)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInBack,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  ),
                );
              },
              child: (!widget.animate || _dir == 0)
                  ? const SizedBox(width: 0, key: ValueKey('eq'))
                  : ScaleTransition(
                scale: _iconBounceAnimation,
                child: Icon(
                  _dir > 0
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                  key: ValueKey(_dir > 0 ? 'up' : 'down'),
                  size: 20,
                  color: color,
                ),
              ),
            ),
          if (widget.showTrendIcon && _dir != 0) const SizedBox(width: 8),

          Flexible(
            fit: FlexFit.loose,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: widget.enableGlow && _dir != 0
                    ? BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3 * _glowAnimation.value),
                      blurRadius: 16 * _glowAnimation.value,
                      spreadRadius: 2 * _glowAnimation.value,
                    ),
                  ],
                )
                    : null,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: Text(
                      widget.hidden ? '••••' : widget.fmt.format(_display),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (widget.loading && widget.pulse != null) ...[
            const SizedBox(width: 10),
            ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.2).animate(
                CurvedAnimation(
                  parent: widget.pulse!,
                  curve: Curves.easeInOut,
                ),
              ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
                  CurvedAnimation(
                    parent: widget.pulse!,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
