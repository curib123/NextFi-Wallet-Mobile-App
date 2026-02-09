// lib/features/wallet_creation/view/widgets/conic_ring_avatar.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConicRingAvatar extends StatelessWidget {
  const ConicRingAvatar({
    super.key,
    required this.size,
    required this.ringWidth,
    required this.asset,
    required this.imageSize,
    required this.baseColor,
    this.rotationTurns = 0.0,
  });

  final double size;
  final double ringWidth;
  final String asset;
  final double imageSize;
  final Color baseColor;
  final double rotationTurns;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Large outer glow
          Container(
            width: size + 40,
            height: size + 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  baseColor.withOpacity(.18),
                  baseColor.withOpacity(.0),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),

          // Outer ring - rotates clockwise
          Transform.rotate(
            angle: rotationTurns * math.pi * 2,
            child: _MultiColorRing(
              size: size,
              strokeWidth: ringWidth * 1.2,
              colors: [
                baseColor.withOpacity(.9),
                baseColor.withOpacity(.6),
                baseColor.withOpacity(.3),
                baseColor.withOpacity(.6),
                baseColor.withOpacity(.9),
              ],
            ),
          ),

          // Middle ring - rotates counter-clockwise
          Transform.rotate(
            angle: -rotationTurns * math.pi * 1.5,
            child: _MultiColorRing(
              size: size - 8,
              strokeWidth: ringWidth * 0.6,
              colors: [
                baseColor.withOpacity(.7),
                baseColor.withOpacity(.4),
                baseColor.withOpacity(.2),
                baseColor.withOpacity(.4),
                baseColor.withOpacity(.7),
              ],
            ),
          ),

          // Inner decorative ring - static
          Container(
            width: size - (ringWidth * 2) - 4,
            height: size - (ringWidth * 2) - 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: baseColor.withOpacity(.2),
                width: 1.5,
              ),
            ),
          ),

          // Orbital particles - 8 particles rotating
          for (int i = 0; i < 8; i++)
            Transform.rotate(
              angle: (rotationTurns * math.pi * 2) + (i * math.pi / 4),
              child: Transform.translate(
                offset: Offset(0, -size / 2 + ringWidth / 2),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseColor.withOpacity(.8),
                    boxShadow: [
                      BoxShadow(
                        color: baseColor.withOpacity(.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Shadow container for image
          Container(
            width: imageSize + 10,
            height: imageSize + 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),

          // Logo container with premium border
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(.12),
                  Colors.white.withOpacity(.08),
                ],
              ),
              border: Border.all(
                width: 2,
                color: baseColor.withOpacity(.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withOpacity(.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                asset,
                width: imageSize,
                height: imageSize,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          baseColor.withOpacity(.15),
                          baseColor.withOpacity(.08),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: imageSize * 0.5,
                      color: baseColor.withOpacity(.8),
                    ),
                  );
                },
              ),
            ),
          ),

          // Corner accent marks (4 corners)
          for (int i = 0; i < 4; i++)
            Transform.rotate(
              angle: (i * math.pi / 2) + (rotationTurns * math.pi * 0.5),
              child: Transform.translate(
                offset: Offset(size / 2 - ringWidth, -size / 2 + ringWidth),
                child: Container(
                  width: 3,
                  height: 8,
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Multi-color gradient ring using Container
class _MultiColorRing extends StatelessWidget {
  const _MultiColorRing({
    required this.size,
    required this.strokeWidth,
    required this.colors,
  });

  final double size;
  final double strokeWidth;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer circle with gradient
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: colors,
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        ),
        // Inner circle to create ring effect
        Container(
          width: size - (strokeWidth * 2),
          height: size - (strokeWidth * 2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }
}