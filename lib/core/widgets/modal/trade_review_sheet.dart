import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/modal/trade_sheet_base.dart';
import 'package:next_fi/app/theme/app_fonts.dart';

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
  static const List<String> _defaultComments = <String>[
    'Smooth and reliable trade',
    'Fast payment and clear communication',
    'Everything completed as expected',
  ];

  int _rating = 5;
  int _selectedCommentIndex = 0;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.text = _defaultComments[_selectedCommentIndex];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _applyCommentChip(int index) {
    setState(() {
      _selectedCommentIndex = index;
      _ctrl.text = _defaultComments[index];
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
  }

  void _handleCommentChanged(String value) {
    final trimmed = value.trim();
    final index = _defaultComments.indexOf(trimmed);
    if (index >= 0 && index != _selectedCommentIndex) {
      setState(() => _selectedCommentIndex = index);
      return;
    }
    if (index < 0 && _selectedCommentIndex != -1) {
      setState(() => _selectedCommentIndex = -1);
    }
  }

  void _submitAndClose() {
    Navigator.pop(
      context,
      TradeReviewResult(rating: _rating, comment: _ctrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return PopScope<TradeReviewResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _submitAndClose();
      },
      child: TradeSheetBase(
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quick comment',
                style: AppFonts.sora(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_defaultComments.length, (index) {
                final selected = _selectedCommentIndex == index;
                return ChoiceChip(
                  label: Text(
                    _defaultComments[index],
                    style: AppFonts.sora(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColor.of(context).onPrimary
                          : colors.textPrimary,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => _applyCommentChip(index),
                  selectedColor: colors.primary,
                  backgroundColor: colors.background,
                  side: BorderSide(
                    color: selected ? colors.primary : colors.border,
                  ),
                  showCheckmark: false,
                );
              }),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              onChanged: _handleCommentChanged,
              style: AppFonts.sora(fontSize: 14, color: colors.textPrimary),
              cursorColor: colors.primary,
              decoration: InputDecoration(
                hintText: 'Leave a comment (optional)...',
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
              onTap: _submitAndClose,
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
      ),
    );
  }
}

