// lib/features/seed_phrase/view/widgets/word_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

/// Clean, minimal word count selector
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

    return Row(
      children: [
        _buildOption(colors, 12),
        const SizedBox(width: 8),
        _buildOption(colors, 18),
        const SizedBox(width: 8),
        _buildOption(colors, 24),
      ],
    );
  }

  Widget _buildOption(AppColor colors, int count) {
    final isSelected = current == count;
    final isEnabled = !loading;

    return Expanded(
      child: GestureDetector(
        onTap: isEnabled ? () {
          HapticFeedback.selectionClick();
          onPick(count);
        } : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.border.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Text(
            '$count words',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}