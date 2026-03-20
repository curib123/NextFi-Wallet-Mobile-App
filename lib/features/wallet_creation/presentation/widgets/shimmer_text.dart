import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class ShimmerText extends StatefulWidget {
  const ShimmerText(
    this.text, {
    super.key,
    required this.baseColor,
    required this.highlightColor,
  });

  final String text;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
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
        final dx = (w * 2) * _ctrl.value - w;
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor.withValues(alpha: .95),
                widget.baseColor,
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _GradientTranslation(dx),
            ).createShader(rect);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
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
