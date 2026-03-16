import 'package:flutter/material.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';

Future<void> showPaymentProofViewModal(
  BuildContext context, {
  required AppColor colors,
  required String imageUrl,
  String? title,
}) {
  return showAppModalBottomSheet<void>(
    context,
    builder: (_) => PaymentProofViewModal(
      imageUrl: imageUrl,
      title: title ?? 'Payment Proof',
      colors: colors,
    ),
  );
}

class PaymentProofViewModal extends StatelessWidget {
  const PaymentProofViewModal({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.colors,
  });

  final String imageUrl;
  final String title;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AppModalBase(
      maxHeightFactor: 0.9,
      padding: EdgeInsets.fromLTRB(14, 10, 14, media.padding.bottom + 12),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      backgroundColor: colors.surface,
      borderColor: colors.border,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'Image cannot be previewed.',
                          textAlign: TextAlign.center,
                          style: AppFonts.sora(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
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
