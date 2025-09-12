// lib/features/seed_phrase/view/widgets/phrase_card.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

class PhraseCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: obscured ? _blurredPlaceholder(colors) : _grid(colors),
            ),
          ),
          if (!obscured)
            IgnorePointer(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 8),
                  child: Opacity(
                    opacity: 0.14,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.shieldAlert, size: 16, color: colors.textSecondary),
                      const SizedBox(width: 6),
                      Text("Do not share", style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _grid(AppColor colors) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: isTwentyFour ? 10 : 12,
        crossAxisSpacing: 8,
        childAspectRatio: 2.45,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final idx = index + 1;
        final word = words[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('$idx.', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    letterSpacing: .2,
                  ),
                  child: Text(word, softWrap: true, overflow: TextOverflow.visible),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blurredPlaceholder(AppColor colors) {
    return GestureDetector(
      onTap: onTapObscured,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
        decoration: BoxDecoration(
          color: colors.background.withOpacity(.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withOpacity(.25)),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.eye, size: 26, color: colors.textSecondary),
            const SizedBox(height: 12),
            Text("Tap to reveal your recovery phrase",
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, height: 1.35)),
            const SizedBox(height: 8),
            Text("Make sure no one is looking at your screen.",
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary.withOpacity(.8), fontSize: 12.5)),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
