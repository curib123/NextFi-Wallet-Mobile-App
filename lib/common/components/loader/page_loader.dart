import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../helper/colors/AppColor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAGE LOADER  — drop-in replacement, same constructor signature
// ─────────────────────────────────────────────────────────────────────────────

class PageLoader extends StatelessWidget {
  const PageLoader({
    super.key,
    this.label,
    this.size = 25,
    this.speed = const Duration(milliseconds: 1400),
    this.color,
  });

  final String? label;
  final double  size;
  final Duration speed;
  final Color?  color;

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
            WavingDotsLoader(color: c, dotSize: size),
            if (label != null) ...[
              const SizedBox(height: 18),
              Text(
                label!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
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
// 5 circles that sine-wave top→bottom, each offset left→right by phase.
// ─────────────────────────────────────────────────────────────────────────────

class WavingDotsLoader extends StatefulWidget {
  const WavingDotsLoader({
    super.key,
    required this.color,
    this.dotCount  = 5,
    this.dotSize   = 10,
    this.waveHeight = 14,
    this.speed     = const Duration(milliseconds: 1200),
  });

  final Color   color;
  final int     dotCount;
  final double  dotSize;
  final double  waveHeight;
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
    final dotR   = widget.dotSize;
    final gap    = dotR * 1.1;
    final width  = widget.dotCount * (dotR * 2) + (widget.dotCount - 1) * gap;
    final height = dotR * 2 + widget.waveHeight * 2;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value; // 0 → 1 repeating

          return SizedBox(
            width: width,
            height: height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(widget.dotCount, (i) {
                if (i > 0) SizedBox(width: gap);

                // Each dot gets a staggered phase: leftmost leads, rightmost trails
                final stagger = i / (widget.dotCount - 1); // 0.0 → 1.0
                final phase   = (t - stagger * 0.35) * math.pi * 2;

                // Vertical offset: sine wave, centered
                final dy   = math.sin(phase) * widget.waveHeight;
                // Scale: slightly bigger at wave peak
                final scale = 0.75 + math.sin(phase).abs() * 0.25;
                // Opacity: dimmer at trough, brighter at crest
                final alpha = 0.3 + math.sin(phase).abs() * 0.7;

                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width:  dotR * 2,
                        height: dotR * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withOpacity(alpha),
                          boxShadow: [
                            BoxShadow(
                              color:      widget.color.withOpacity(alpha * 0.4),
                              blurRadius: dotR * scale * 1.5,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
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
// LEGACY ALIASES — kept so nothing else in the codebase breaks
// ─────────────────────────────────────────────────────────────────────────────

class ModernFintechLoader extends StatelessWidget {
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
  Widget build(BuildContext context) =>
      WavingDotsLoader(color: color, dotSize: size * 0.38, speed: speed);
}

class RubiksCubeLoader extends StatelessWidget {
  const RubiksCubeLoader({
    super.key,
    this.size  = 48,
    this.speed = const Duration(milliseconds: 1400),
    required this.color,
  });

  final double   size;
  final Duration speed;
  final Color    color;

  @override
  Widget build(BuildContext context) =>
      WavingDotsLoader(color: color, dotSize: size * 0.38, speed: speed);
}