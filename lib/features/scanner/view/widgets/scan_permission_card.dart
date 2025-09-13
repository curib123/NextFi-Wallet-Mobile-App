import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ScanPermissionCard extends StatelessWidget {
  const ScanPermissionCard({super.key, required this.onTryAgain});

  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.surface.withOpacity(.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shieldAlert, size: 40, color: c.primary),
            const SizedBox(height: 12),
            Text(
              'Camera Permission Needed',
              style: TextStyle(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please grant camera access to scan QR codes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onTryAgain,
              icon: const Icon(LucideIcons.refreshCcw),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
