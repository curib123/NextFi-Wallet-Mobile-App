import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class WordCountPicker extends StatelessWidget {
  final int current;
  final bool loading;
  final ValueChanged<int> onPick;

  const WordCountPicker({
    super.key,
    required this.current,
    required this.loading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final is12 = current == 12;
    final is18 = current == 18;
    final is24 = current == 24;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withOpacity(0.8),
            colors.surface.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.border.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CountChip(
            label: '12 words',
            selected: is12,
            loading: loading,
            onTap: loading ? null : () => onPick(12),
          ),
          const SizedBox(width: 6),
          _CountChip(
            label: '18 words',
            selected: is18,
            loading: loading,
            onTap: loading ? null : () => onPick(18),
          ),
          const SizedBox(width: 6),
          _CountChip(
            label: '24 words',
            selected: is24,
            loading: loading,
            onTap: loading ? null : () => onPick(24),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatefulWidget {
  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback? onTap;

  const _CountChip({
    required this.label,
    required this.selected,
    required this.loading,
    this.onTap,
  });

  @override
  State<_CountChip> createState() => _CountChipState();
}

class _CountChipState extends State<_CountChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      HapticFeedback.selectionClick();
      _controller.forward().then((_) => _controller.reverse());
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final isEnabled = widget.onTap != null;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: widget.selected
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary,
                  colors.primary.withOpacity(0.85),
                ],
              )
                  : null,
              color: widget.selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: widget.selected
                  ? null
                  : Border.all(
                color: colors.border.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: widget.selected
                  ? [
                BoxShadow(
                  color: colors.primary.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) {
                    return ScaleTransition(
                      scale: anim,
                      child: FadeTransition(
                        opacity: anim,
                        child: child,
                      ),
                    );
                  },
                  child: widget.selected
                      ? Padding(
                    key: const ValueKey('check'),
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      LucideIcons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: widget.selected
                        ? Colors.white
                        : isEnabled
                        ? colors.textPrimary
                        : colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: -0.1,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}