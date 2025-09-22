import 'package:flutter/material.dart';

class AppBarCompactSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const AppBarCompactSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value ? 'Compact layout' : 'Comfortable layout',
      child: Row(
        children: [
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.9,
            child: Switch.adaptive(value: value, onChanged: onChanged),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
