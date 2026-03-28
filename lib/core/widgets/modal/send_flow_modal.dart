import 'package:flutter/material.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/recipient_input/recipient_flow_controller.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';
import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/features/send/presentation/screens/send_screen.dart';

Future<void> showSendModal(
  BuildContext context, {
  required String address,
  required String assetId,
  required double balance,
  bool autoOpenScanner = false,
  String? prefillAddress,
  String? prefillName,
  RecipientAddressModel? prefillRecipient,
  RecipientInputMode? initialRecipientMode,
  Future<void> Function()? onTransactionCompleted,
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
      child: SendScreen(
        address: address,
        assetId: assetId,
        balance: balance,
        autoOpenScanner: autoOpenScanner,
        prefillAddress: prefillAddress,
        prefillName: prefillName,
        prefillRecipient: prefillRecipient,
        initialRecipientMode: initialRecipientMode,
        onTransactionCompleted: onTransactionCompleted,
        useScaffold: false,
      ),
    ),
  );
}
