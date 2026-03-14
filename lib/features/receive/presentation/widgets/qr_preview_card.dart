// lib/features/receive/view/widgets/qr_preview_card.dart
import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';
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
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border.withValues(alpha: 0.18)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.surface,
              c.surface.withValues(alpha: 0.98),
              c.primary.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$token QR',
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap to expand',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(18),
                color: c.onPrimary,
                child: QrImageView(data: address, version: QrVersions.auto, size: 210),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Share this code with the sender to receive $token on Stellar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

