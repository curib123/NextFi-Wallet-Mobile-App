import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:next_fi/app/theme/app_color.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAGE LOADER  — same constructor signature, refreshed visuals
// ─────────────────────────────────────────────────────────────────────────────

class PageLoader extends StatelessWidget {
  const PageLoader({
    super.key,
    this.label,
    this.size  = 25,
    this.speed = const Duration(milliseconds: 1400),
    this.color,
  });

  final String?  label;
  final double   size;
  final Duration speed;
  final Color?   color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final c = color ?? colors.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WavingDotsLoader(color: c, dotSize: size, speed: speed),
            if (label != null) ...[
              const SizedBox(height: 20),
              Text(
                label!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WAVING DOTS LOADER
// Morphing bars — each bar stretches tall at its wave crest and squishes
// flat at the trough, creating a fluid "equalizer" feel.
// Same constructor as before, fully drop-in.
// ─────────────────────────────────────────────────────────────────────────────

class WavingDotsLoader extends StatefulWidget {
  const WavingDotsLoader({
    super.key,
    required this.color,
    this.dotCount   = 5,
    this.dotSize    = 10,
    this.waveHeight = 14,
    this.speed      = const Duration(milliseconds: 1200),
  });

  final Color    color;
  final int      dotCount;
  final double   dotSize;
  final double   waveHeight;
  final Duration speed;

  @override
  State<WavingDotsLoader> createState() => _WavingDotsLoaderState();
}

class _WavingDotsLoaderState extends State<WavingDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.speed)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r   = widget.dotSize;        // bar half-width
    final gap = r * 0.9;
    final maxH = r * 2 + widget.waveHeight * 2;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;

          return SizedBox(
            width:  widget.dotCount * (r * 2) + (widget.dotCount - 1) * gap,
            height: maxH,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(widget.dotCount, (i) {
                final stagger = i / (widget.dotCount - 1);
                final phase   = (t - stagger * 0.32) * math.pi * 2;
                final sin     = math.sin(phase);           // -1 → +1

                // Height: tall at crest, short at trough
                final barHeight = r * 2 + sin.abs() * widget.waveHeight * 1.6;
                // Radius: more circular when short, pill-shaped when tall
                final radius    = r * (1.0 - sin.abs() * 0.3);
                // Opacity: bright at crest, dim at trough
                final alpha     = 0.28 + sin.abs() * 0.72;
                // Slight horizontal squeeze at peak for a "breathing" feel
                final scaleX    = 1.0 - sin.abs() * 0.15;

                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                  child: Transform.scale(
                    scaleX: scaleX,
                    child: AnimatedContainer(
                      duration: Duration.zero,
                      width:  r * 2,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: alpha),
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: sin.abs() > 0.5
                            ? [
                          BoxShadow(
                            color:      widget.color.withValues(alpha: alpha * 0.35),
                            blurRadius: r * 2.5,
                            spreadRadius: 0,
                          ),
                        ]
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODERN FINTECH LOADER
// Two counter-rotating arcs that breathe in and out — works at any size,
// especially crisp at small badge sizes (16–26 px).
// Same constructor signature as before.
// ─────────────────────────────────────────────────────────────────────────────

class ModernFintechLoader extends StatefulWidget {
  const ModernFintechLoader({
    super.key,
    this.size  = 48,
    this.speed = const Duration(milliseconds: 1400),
    required this.color,
  });

  final double   size;
  final Duration speed;
  final Color    color;

  @override
  State<ModernFintechLoader> createState() => _ModernFintechLoaderState();
}

class _ModernFintechLoaderState extends State<ModernFintechLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.speed)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _DualArcPainter(
            progress: _ctrl.value,
            color:    widget.color,
          ),
        ),
      ),
    );
  }
}

class _DualArcPainter extends CustomPainter {
  _DualArcPainter({required this.progress, required this.color});

  final double progress;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final outerR = size.width  / 2;
    final stroke = math.max(outerR * 0.13, 1.5);

    // ── Track (outer faint ring) ──────────────────────────
    final trackPaint = Paint()
      ..color  = color.withValues(alpha: 0.12)
      ..style  = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap   = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), outerR - stroke / 2, trackPaint);

    // ── Outer arc — clockwise, sweep shrinks/grows ────────
    final t1     = progress * math.pi * 2;              // full rotation
    final sweep1 = (math.sin(t1 * 0.5) * 0.5 + 0.5)   // 0 → 1 pulsing
        * math.pi * 1.6 + 0.3;                          // min arc = 0.3 rad
    final startAngle1 = t1 - math.pi / 2;

    final outerPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle1,
        endAngle:   startAngle1 + sweep1,
        colors:     [color.withValues(alpha: 0.0), color],
        tileMode:   TileMode.clamp,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: outerR))
      ..style       = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap   = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: outerR - stroke / 2),
      startAngle1,
      sweep1,
      false,
      outerPaint,
    );

    // ── Inner arc — counter-clockwise, offset phase ───────
    final innerR  = outerR * 0.58;
    final t2      = -progress * math.pi * 2 * 1.3;     // faster, reversed
    final sweep2  = (math.cos(t2 * 0.5) * 0.4 + 0.6)
        * math.pi * 1.0 + 0.2;
    final startAngle2 = t2 + math.pi / 4;

    final innerPaint = Paint()
      ..color       = color.withValues(alpha: 0.55)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.75
      ..strokeCap   = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
      startAngle2,
      sweep2,
      false,
      innerPaint,
    );

    // ── Centre dot ────────────────────────────────────────
    final dotR  = stroke * 0.9;
    final pulse = math.sin(progress * math.pi * 4) * 0.25 + 0.75;
    canvas.drawCircle(
      Offset(cx, cy),
      dotR * pulse,
      Paint()..color = color.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_DualArcPainter old) =>
      old.progress != progress || old.color != color;
}
