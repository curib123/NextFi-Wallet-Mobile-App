import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class FormStyles {
  static InputDecoration inputDecoration(
      BuildContext context, {
        String? label,
        String? hint,
        double radius = 12,
        EdgeInsets contentPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      }) {
    final c = AppColor.of(context);
    return InputDecoration(
      isDense: true,
      labelText: label,
      hintText: hint,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: c.border.withOpacity(.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: c.border.withOpacity(.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: c.primary, width: 1.2),
      ),
    );
  }
}
