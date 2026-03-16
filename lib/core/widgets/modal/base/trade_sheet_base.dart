import 'package:flutter/material.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';

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
    final media = MediaQuery.of(context);
    return AppModalBase(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        (fullScroll ? media.viewInsets.bottom : media.padding.bottom) + 24,
      ),
      backgroundColor: colors.surface,
      borderColor: colors.border,
      child: child,
    );
  }
}
