// lib/features/claimable/view/widgets/claimable_empty.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class ClaimableEmpty extends StatelessWidget {
  final VoidCallback onCreate;
  final String? message;
  final String? description;
  final IconData? icon;

  const ClaimableEmpty({
    super.key,
    required this.onCreate,
    this.message,
    this.description,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? LucideIcons.inbox,
                size: 36,
                color: c.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message ?? 'No claimable balances',
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description ??
                  'When someone sends you a claimable balance, '
                      'it will appear here. You can also create one yourself.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(LucideIcons.plus, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Create Claimable Balance',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}