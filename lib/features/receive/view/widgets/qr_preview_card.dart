// lib/features/receive/view/widgets/qr_preview_card.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrPreviewCard extends StatelessWidget {
  const QrPreviewCard({super.key, required this.address, required this.token, required this.onTap});
  final String address;
  final String token;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.primary.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Text('Scan to receive $token', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: c.onPrimary,
                child: QrImageView(data: address, version: QrVersions.auto, size: 220),
              ),
            ),
            const SizedBox(height: 10),
            Text('Tap to enlarge', style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
