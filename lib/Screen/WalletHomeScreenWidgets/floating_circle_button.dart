import 'dart:ui';

import 'package:flutter/material.dart';

Widget floatingCircleButton({
  required VoidCallback onTap,
  required IconData icon,
  Color color = Colors.blue,
  double size = 30,
  double padding = 13,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: size,
      ),
    ),
  );
}