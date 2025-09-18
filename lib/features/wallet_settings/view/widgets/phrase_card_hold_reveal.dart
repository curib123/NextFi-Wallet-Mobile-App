// lib/features/wallet_settings/view/widgets/phrase_card_hold_reveal.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class PhraseCardHoldReveal extends StatelessWidget {
  const PhraseCardHoldReveal({
    super.key,
    required this.words,
    required this.obscured,
    required this.onRevealHold,
  });

  final List<String> words;
  final bool obscured;
  final VoidCallback onRevealHold;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withOpacity(0.22)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: obscured
            ? _blurredPlaceholder(colors)
            : Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: _seedGrid(colors),
        ),
      ),
    );
  }

  Widget _blurredPlaceholder(AppColor colors) {
    return InkWell(
      onLongPress: onRevealHold,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
        decoration: BoxDecoration(
          color: colors.background.withOpacity(.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border.withOpacity(.25)),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.eye, size: 24, color: colors.textSecondary),
            const SizedBox(height: 10),
            Text("Press & hold to reveal your recovery phrase",
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14, height: 1.35)),
            const SizedBox(height: 6),
            Text("Authentication required",
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary.withOpacity(.85), fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _seedGrid(AppColor colors) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.6,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final idx = index + 1;
        final word = words[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('$idx.', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  word,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: .2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
