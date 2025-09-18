import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class InfoRow extends StatelessWidget {
  final String label, value;
  const InfoRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        const Spacer(),
        Text(value, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
