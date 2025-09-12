import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

class RecipientLoadingLine extends StatelessWidget {
  const RecipientLoadingLine({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(height: 18, decoration: BoxDecoration(color: c.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(8)));
  }
}
