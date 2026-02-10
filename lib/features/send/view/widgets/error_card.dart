// lib/features/send/view/widgets/error_card.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorCard({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.error.withValues(alpha: 0.07),
              c.error.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.error.withValues(alpha: 0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: c.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(LucideIcons.alertTriangle,
                  size: 13, color: c.error.withValues(alpha: 0.75)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: c.error.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRetry,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: c.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.refreshCw,
                        size: 13, color: c.error.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}