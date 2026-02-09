// lib/features/seed_phrase/view/widgets/confirm_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class ConfirmTile extends StatefulWidget {
  const ConfirmTile({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  State<ConfirmTile> createState() => _ConfirmTileState();
}

class _ConfirmTileState extends State<ConfirmTile>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _controller.forward().then((_) => _controller.reverse());
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final bgOn = widget.accent.withOpacity(0.08);
    final borderOn = widget.accent.withOpacity(0.25);

    return Semantics(
      button: true,
      toggled: widget.value,
      label: widget.title,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: widget.value
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  bgOn,
                  bgOn.withOpacity(0.5),
                ],
              )
                  : null,
              color: widget.value ? null : colors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.value
                    ? borderOn
                    : colors.border.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: widget.value
                  ? [
                BoxShadow(
                  color: widget.accent.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Accent bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: 5,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: widget.value
                        ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.accent,
                        widget.accent.withOpacity(0.6),
                      ],
                    )
                        : null,
                    color: widget.value ? null : Colors.transparent,
                  ),
                ),
                const SizedBox(width: 14),
                // Icon container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: widget.value
                        ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.accent.withOpacity(0.18),
                        widget.accent.withOpacity(0.12),
                      ],
                    )
                        : null,
                    color: widget.value ? null : colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.value
                          ? borderOn
                          : colors.border.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: widget.value ? widget.accent : colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                // Title
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      height: 1.3,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Checkmark
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
                  child: widget.value
                      ? Container(
                    key: const ValueKey('on'),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.accent,
                          widget.accent.withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  )
                      : Container(
                    key: const ValueKey('off'),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.border.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}