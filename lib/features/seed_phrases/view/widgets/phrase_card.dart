// lib/features/seed_phrase/view/widgets/phrase_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

/// Enhanced phrase card with modern glassmorphism and smooth animations
class PhraseCard extends StatefulWidget {
  const PhraseCard({
    super.key,
    required this.words,
    required this.obscured,
    required this.isTwentyFour,
    this.onTapObscured,
  });

  final List<String> words;
  final bool obscured;
  final bool isTwentyFour;
  final VoidCallback? onTapObscured;

  @override
  State<PhraseCard> createState() => _PhraseCardState();
}

class _PhraseCardState extends State<PhraseCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void didUpdateWidget(PhraseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscured != widget.obscured) {
      if (widget.obscured) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Determine grid layout based on word count
  int get _crossAxisCount {
    final count = widget.words.length;
    if (count == 24) return 3;
    if (count == 18) return 3;
    return 3; // 12 words also use 3 columns
  }

  double get _mainAxisSpacing {
    final count = widget.words.length;
    if (count == 24) return 12;
    if (count == 18) return 13;
    return 14; // 12 words
  }

  double get _childAspectRatio {
    final count = widget.words.length;
    if (count == 24) return 2.5;
    if (count == 18) return 2.6;
    return 2.5; // 12 words
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surface.withOpacity(0.92),
                  colors.surface.withOpacity(0.75),
                ],
              ),
              border: Border.all(
                color: colors.border.withOpacity(0.12),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                // Subtle gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: RadialGradient(
                        center: Alignment.topLeft,
                        radius: 1.8,
                        colors: [
                          colors.primary.withOpacity(0.035),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.94, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: widget.obscured
                        ? _buildBlurredPlaceholder(colors)
                        : _buildGrid(colors),
                  ),
                ),

                // Warning watermark
                if (!widget.obscured)
                  Positioned(
                    right: 16,
                    bottom: 14,
                    child: Opacity(
                      opacity: 0.08,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.shieldAlert,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Keep secure",
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
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

  Widget _buildGrid(AppColor colors) {
    return GridView.builder(
      key: const ValueKey('grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,        // ✅ 2 GRID HERE
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 3.2,   // Wider for 2-column layout
      ),
      itemCount: widget.words.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          key: ValueKey('word_$index'),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 500 + (index * 30)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _WordChip(
            index: index + 1,
            word: widget.words[index],
            colors: colors,
          ),
        );
      },
    );
  }


  Widget _buildBlurredPlaceholder(AppColor colors) {
    return GestureDetector(
      key: const ValueKey('placeholder'),
      onTap: widget.onTapObscured,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.background.withOpacity(0.6),
              colors.background.withOpacity(0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.border.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary.withOpacity(0.15),
                    colors.primary.withOpacity(0.08),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                LucideIcons.eye,
                size: 32,
                color: colors.primary,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "Tap to reveal your recovery phrase",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.4,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.warning.withOpacity(0.12),
                    colors.warning.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colors.warning.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    size: 16,
                    color: colors.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Ensure privacy before viewing",
                    style: TextStyle(
                      color: colors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual word chip with modern styling
class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.index,
    required this.word,
    required this.colors,
  });

  final int index;
  final String word;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.background.withOpacity(0.95),
            colors.background.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.border.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary.withOpacity(0.12),
                  colors.primary.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              word,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.1,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}