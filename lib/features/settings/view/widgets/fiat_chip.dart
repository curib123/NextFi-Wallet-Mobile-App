// lib/features/settings/view/widgets/fiat_chip.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/currency_vm.dart';

class FiatChip extends StatelessWidget {
  const FiatChip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final fiat = context.select<CurrencyProvider, String>((p) => p.fiat).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.primary.withOpacity(0.25)),
      ),
      child: Text(
        fiat,
        style: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
