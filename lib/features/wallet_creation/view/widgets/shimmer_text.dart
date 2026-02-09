// lib/features/wallet_creation/view/widgets/shimmer_text.dart
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class ShimmerText extends StatefulWidget {
  const ShimmerText(
      this.text, {
        super.key,
        required this.baseColor,
        required this.highlightColor,
        this.fontSize = 32,
        this.fontWeight = FontWeight.w800,
        this.letterSpacing = 0.5,
      });

  final String text;
  final Color baseColor;
  final Color highlightColor;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final w = MediaQuery.of(context).size.width;
        final dx = (w * 2.5) * _ctrl.value - w * 1.25;

        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor.withOpacity(.98),
                widget.highlightColor,
                widget.highlightColor.withOpacity(.98),
                widget.baseColor,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              transform: _GradientTranslation(dx),
            ).createShader(rect);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: widget.fontWeight,
              letterSpacing: widget.letterSpacing,
              shadows: [
                Shadow(
                  color: widget.highlightColor.withOpacity(.3),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GradientTranslation extends GradientTransform {
  const _GradientTranslation(this.dx);
  final double dx;

  @override
  vm.Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return vm.Matrix4.translationValues(dx, 0, 0);
  }
}