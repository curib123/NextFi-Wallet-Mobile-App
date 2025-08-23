import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

Widget actionButton(AppColor colors, IconData icon, String label, {bool gradient = false}) {
  return Column(
    children: [
      Container(
        decoration: BoxDecoration(
          gradient: gradient
              ? LinearGradient(
            colors: [colors.primary, colors.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: gradient ? null : colors.primary.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16), // Circle radius
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}



Widget recipientList(AppColor colors) {
  return ListView.builder(
    itemCount: 10,
    itemBuilder: (context, index) {
      return recipientTile(
        colors: colors,
        recipientName: 'Recipient #$index',
        address: '0xABCDEF12345$index',
        onTap: () {
          // Handle tap event
        },
      );
    },
  );
}

Widget recipientTile({
  required AppColor colors,
  required String recipientName,
  required String address,
  required VoidCallback onTap,
}) {
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