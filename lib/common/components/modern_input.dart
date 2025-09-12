// Replace your existing _modernInput with this version
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

InputDecoration modernInput(
    BuildContext context, {
      String? placeholder,          // ← hint / placeholder only
      Widget? prefix,
      Widget? suffix,
    }) {
  final c = AppColor.of(context);
  return InputDecoration(
    hintText: placeholder,
    hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.9)),
    floatingLabelBehavior: FloatingLabelBehavior.never, // ensure no label floats
    filled: true,
    fillColor: c.primary.withOpacity(0.05),
    prefixIcon: prefix,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none, // flat at rest
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: c.primary.withOpacity(0.35), // subtle focus ring
        width: 1.15,
      ),
    ),
  );
}
