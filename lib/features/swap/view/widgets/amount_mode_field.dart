import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/features/swap/model/swap_mode.dart';
import 'package:next_fi/features/swap/view/widgets/form_style.dart';

class AmountModeField extends StatelessWidget {
  final AmountMode value;
  final ValueChanged<AmountMode> onChanged;
  final double radius;
  final EdgeInsets contentPad;

  const AmountModeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.radius = 12,
    this.contentPad = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return DropdownButtonFormField<AmountMode>(
      value: value,
      isExpanded: true,
      decoration: FormStyles.inputDecoration(
        context,
        label: 'Amount input',
        radius: radius,
        contentPadding: contentPad,
      ),
      icon: Icon(LucideIcons.chevronDown, size: 18, color: c.textSecondary),
      onChanged: (v) => v != null ? onChanged(v) : null,
      items: const [
        DropdownMenuItem(
          value: AmountMode.from,
          child: _DDItem(icon: LucideIcons.send, label: 'Based on send'), // UX-friendly
        ),
        DropdownMenuItem(
          value: AmountMode.to,
          child: _DDItem(icon: LucideIcons.inbox, label: 'Based on receive'),
        ),
      ],
    );
  }
}

class _DDItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DDItem({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: c.textPrimary),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
