import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';

class AppDrawerButton extends StatefulWidget {
  const AppDrawerButton({super.key, required this.colors, required this.onTap});

  final AppColor colors;
  final VoidCallback onTap;

  @override
  State<AppDrawerButton> createState() => _AppDrawerButtonState();
}

class _AppDrawerButtonState extends State<AppDrawerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isPressed
                ? widget.colors.border.withValues(alpha: isDark ? 0.15 : 0.12)
                : widget.colors.border.withValues(alpha: isDark ? 0.08 : 0.05),
          ),
          child: Icon(
            Icons.widgets_outlined,
            size: 24,
            color: widget.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
