// lib/features/auth_gate/view/widgets/primary_action.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/common/components/CustomButton.dart';

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.maxWidth,
    required this.colors,
    required this.text,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final double maxWidth;
  final AppColor colors;
  final String text;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: text,
            icon: icon,
            type: ButtonType.filled,
            onPressed: (){
              enabled ? onPressed : null;
            },
          ),
        ),
      ),
    );
  }
}
