import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';

class TradeSheetBase extends StatelessWidget {
  const TradeSheetBase({
    super.key,
    required this.child,
    required this.colors,
    this.fullScroll = false,
  });

  final Widget child;
  final AppColor colors;
  final bool fullScroll;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        (fullScroll
                ? MediaQuery.of(context).viewInsets.bottom
                : MediaQuery.of(context).padding.bottom) +
            24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

