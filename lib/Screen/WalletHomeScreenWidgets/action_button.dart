import 'package:flutter/material.dart';
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
              offset: const Offset(0, 5),
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
