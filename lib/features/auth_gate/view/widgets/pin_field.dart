// lib/features/auth_gate/view/widgets/pin_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/AppColor.dart';

class PinField extends StatelessWidget {
  const PinField({
    super.key,
    required this.maxWidth,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.obscure,
    required this.colors,
    required this.onSubmit,
    required this.onToggleObscure,
  });

  final double maxWidth;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool obscure;
  final AppColor colors;
  final VoidCallback onSubmit;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: TextField(
          focusNode: focusNode,
          controller: controller,
          enabled: enabled,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          obscureText: obscure,
          maxLength: 6,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          onChanged: (v) {
            if (v.length == 6) onSubmit();
          },
          style: TextStyle(
            fontSize: 20,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.primary.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
            hintText: "••••••",
            hintStyle: TextStyle(
              fontSize: 20,
              letterSpacing: 6,
              color: colors.textSecondary.withOpacity(0.4),
            ),
            prefixIcon: const SizedBox(width: 48),
            prefixIconConstraints: const BoxConstraints(minWidth: 48),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: colors.textSecondary,
              ),
              onPressed: onToggleObscure,
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 48),
          ),
        ),
      ),
    );
  }
}
