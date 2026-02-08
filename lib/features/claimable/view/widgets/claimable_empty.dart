// lib/features/claimable/view/widgets/claimable_empty.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

/// Empty state widget shown when there are no claimable balances.
///
/// Displays an informative message and a button to create a new
/// claimable balance. Can be customized for different contexts.
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
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? LucideIcons.inbox,
                size: 36,
                color: c.primary.withValues(alpha: 0.5),
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              message ?? 'No claimable balances',
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 6),

            // Description
            Text(
              description ??
                  'When someone sends you a claimable balance, '
                      'it will appear here. You can also create one yourself.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            // Create button
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(
                LucideIcons.plus,
                size: 16,
                color: Colors.white,
              ),
              label: const Text(
                'Create Claimable Balance',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}