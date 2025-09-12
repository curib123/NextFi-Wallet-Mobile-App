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
  });

  final double targetValue;
  final NumberFormat fmt;
  final Color baseColor;
  final Color upColor;
  final Color downColor;
  final bool hidden;

  final bool loading;
  final AnimationController? pulse;

  @override
  State<LiveCountingBalance> createState() => _LiveCountingBalanceState();
}

class _LiveCountingBalanceState extends State<LiveCountingBalance> {
  late double _display;
  int _dir = 0;
  Timer? _ticker;

  static const _tick = Duration(seconds: 1);
  static const _minStep = 0.01;

  @override
  void initState() {
    super.initState();
    _display = widget.targetValue.isFinite ? widget.targetValue : 0.0;
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) {
      if (!mounted) return;

      if (!widget.targetValue.isFinite) { setState(() => _dir = 0); return; }
      final delta = widget.targetValue - _display;

      if (delta.abs() <= _minStep) {
        setState(() { _display = widget.targetValue; _dir = 0; });
        return;
      }
      final dynamicStep = (delta.abs() / 4).clamp(_minStep, double.infinity);
      final step = delta.isNegative ? -dynamicStep : dynamicStep;

      setState(() {
        _display = double.parse((_display + step).toStringAsFixed(4));
        _dir = step > 0 ? 1 : -1;
      });
    });
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: _dir == 0
              ? const SizedBox(width: 0, key: ValueKey('eq'))
              : Icon(_dir > 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              key: ValueKey(_dir > 0 ? 'up' : 'down'), size: 18, color: color),
        ),
        const SizedBox(width: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          child: Text(widget.hidden ? '••••' : widget.fmt.format(_display)),
        ),
        if (widget.loading && widget.pulse != null) ...[
          const SizedBox(width: 8),
          ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.15).animate(widget.pulse!),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 1.0).animate(widget.pulse!),
              child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color.withOpacity(0.85), shape: BoxShape.circle)),
            ),
          ),
        ],
      ],
    );
  }
}
