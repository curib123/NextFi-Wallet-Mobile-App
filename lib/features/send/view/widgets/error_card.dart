import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

class ErrorCard extends StatelessWidget {
  final String message;
  const ErrorCard({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.error.withOpacity(0.2)),
        ),
        child: Text(message, style: TextStyle(color: c.error)),
      ),
    );
  }
}
