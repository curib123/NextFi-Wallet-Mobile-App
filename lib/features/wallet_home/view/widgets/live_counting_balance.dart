// lib/features/wallet_home/view/widgets/live_counting_balance.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class LiveCountingBalance extends StatefulWidget {
  const LiveCountingBalance({
    super.key,
    required this.targetValue,
    required this.fmt,
    required this.baseColor,
    this.upColor = const Color(0xFF22C55E),
    this.downColor = const Color(0xFFEF4444),
    this.hidden = false,
    this.loading = false,
    this.pulse,
    this.animate = true, // ⬅️ NEW: disable to render instantly
  });

  final double targetValue;
  final NumberFormat fmt;
  final Color baseColor;
  final Color upColor;
  final Color downColor;
  final bool hidden;

  final bool loading;
  final AnimationController? pulse;

  /// When false, no counting/trending animation; value is shown directly.
  final bool animate;

  @override
  State<LiveCountingBalance> createState() => _LiveCountingBalanceState();
}

class _LiveCountingBalanceState extends State<LiveCountingBalance> {
  late double _display;
  int _dir = 0; // -1 down, 0 flat, 1 up
  Timer? _ticker;

  static const _tick = Duration(milliseconds: 250);
  static const _minStep = 0.01;

  @override
  void initState() {
    super.initState();
    _display = widget.targetValue.isFinite ? widget.targetValue : 0.0;
    if (widget.animate) _startTicker();
  }

  @override
  void didUpdateWidget(covariant LiveCountingBalance old) {
    super.didUpdateWidget(old);

    // Handle animate flag transitions
    if (old.animate != widget.animate) {
      if (widget.animate) {
        // switching ON: start ticker from current display towards target
        _startTicker();
      } else {
        // switching OFF: stop ticker and snap to target
        _ticker?.cancel();
        _dir = 0;
        _display = widget.targetValue.isFinite ? widget.targetValue : 0.0;
        setState(() {}); // reflect immediately
      }
      return;
    }

    // If not animating, always mirror the target instantly.
    if (!widget.animate) {
      final next = widget.targetValue.isFinite ? widget.targetValue : 0.0;
      if (next != _display) {
        _display = next;
        _dir = 0;
        setState(() {});
      }
      return;
    }

    // If animating and the target changed a lot, nudge sooner by restarting.
    if (old.targetValue != widget.targetValue && widget.animate) {
      _restartTicker();
    }
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

      // Dynamic easing: bigger gap -> bigger step
      final dynamicStep = (delta.abs() / 4).clamp(_minStep, double.infinity);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _dir == 0 ? widget.baseColor : (_dir > 0 ? widget.upColor : widget.downColor);

    return Row(
      children: [
        // Trending icon hidden when not animating or when steady
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: (!widget.animate || _dir == 0)
              ? const SizedBox(width: 0, key: ValueKey('eq'))
              : Icon(
            _dir > 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
            key: ValueKey(_dir > 0 ? 'up' : 'down'),
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          child: Text(widget.hidden ? '••••' : widget.fmt.format(_display)),
        ),
        if (widget.loading && widget.pulse != null) ...[
          const SizedBox(width: 8),
          ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.15).animate(widget.pulse!),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 1.0).animate(widget.pulse!),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
