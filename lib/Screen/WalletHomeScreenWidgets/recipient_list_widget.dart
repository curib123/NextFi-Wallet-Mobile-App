import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

/// Recipient list widget
class RecipientListWidget extends StatelessWidget {
  final AppColor colors;

  const RecipientListWidget({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10, // Can be dynamic
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        return RecipientTile(
          colors: colors,
          recipientName: 'Recipient #$index',
          address: '0xABCDEF12345$index',
          onTap: () {
            debugPrint('Tapped Recipient #$index');
          },
        );
      },
    );
  }
}

/// Recipient tile widget
class RecipientTile extends StatelessWidget {
  final AppColor colors;
  final String recipientName;
  final String address;
  final VoidCallback onTap;

  const RecipientTile({
    super.key,
    required this.colors,
    required this.recipientName,
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.primary.withOpacity(0.1),
          child: Icon(LucideIcons.user, color: colors.primary),
        ),
        title: Text(
          recipientName,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          address,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Icon(LucideIcons.chevronRight, color: colors.textSecondary),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
