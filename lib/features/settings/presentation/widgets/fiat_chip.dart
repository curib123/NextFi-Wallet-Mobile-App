// lib/features/settings/view/widgets/fiat_chip.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/config/app_providers.dart';

class FiatChip extends ConsumerWidget {
  const FiatChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColor.of(context);
    final fiat = ref.watch(currencyVmProvider).fiat.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.primary.withValues(alpha: 0.25)),
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

