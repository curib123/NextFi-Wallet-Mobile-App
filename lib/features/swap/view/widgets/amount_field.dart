import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/common/components/Input/modern_input.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class AmountField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const AmountField({super.key, required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$'))],
        decoration: modernInput(context, placeholder: '0.0'),
      ),
    ]);
  }
}
