import 'package:flutter/material.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';
import 'package:next_fi/features/claimable/presentation/screens/claimable_create_screen.dart';

Future<void> showClaimableCreateModal(
  BuildContext context, {
  String initialAsset = 'XLM',
}) async {
  final colors = AppColor.of(context);
  await showAppModalBottomSheet<void>(
    context,
    builder: (_) => AppModalBase(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      showHandle: false,
      safeAreaTop: false,
      maxHeightFactor: 0.96,
      maxWidth: 960,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      backgroundColor: colors.surface,
      borderColor: colors.border.withValues(alpha: 0.16),
      child: ClaimableCreateScreen(
        initialAsset: initialAsset,
        useScaffold: false,
      ),
    ),
  );
}
