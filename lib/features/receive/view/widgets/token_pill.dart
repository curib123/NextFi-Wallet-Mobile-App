// lib/features/receive/view/widgets/token_pill.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class TokenPill extends StatelessWidget {
  const TokenPill({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
      child: Text(token, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
    );
  }
}
