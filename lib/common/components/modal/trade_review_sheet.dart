import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/theme/app_fonts.dart';
import 'package:next_fi/common/components/modal/trade_sheet_base.dart';

class TradeReviewResult {
  const TradeReviewResult({required this.rating, required this.comment});

  final int rating;
  final String comment;
}

class TradeReviewSheet extends StatefulWidget {
  const TradeReviewSheet({
    super.key,
    required this.tradeId,
    required this.colors,
  });

  final String tradeId;
  final AppColor colors;

  @override
  State<TradeReviewSheet> createState() => _TradeReviewSheetState();
}

class _TradeReviewSheetState extends State<TradeReviewSheet> {
  int _rating = 5;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return TradeSheetBase(
      colors: colors,
      fullScroll: true,
      child: Column(
        children: [
          Text(
            'Rate Your Experience',
            style: AppFonts.sora(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'How was the trade?',
            style: AppFonts.sora(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    star <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: star <= _rating
                        ? AppColor.of(context).warning
                        : colors.textSecondary,
                    size: star <= _rating ? 40 : 34,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            style: AppFonts.sora(fontSize: 14, color: colors.textPrimary),
            cursorColor: colors.primary,
            decoration: InputDecoration(
              hintText: 'Leave a comment (optional)…',
              hintStyle: AppFonts.sora(
                fontSize: 13.5,
                color: colors.textSecondary,
              ),
              filled: true,
              fillColor: colors.background,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => Navigator.pop(
              context,
              TradeReviewResult(rating: _rating, comment: _ctrl.text.trim()),
            ),
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  'Submit Review',
                  style: AppFonts.sora(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColor.of(context).onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

