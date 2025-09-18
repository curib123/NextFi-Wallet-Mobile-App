// lib/features/settings/view/widgets/settings_app_bar.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SettingsAppBar({super.key, required this.colors});

  final AppColor colors;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: colors.surface,
      centerTitle: true,
      title: Text(
        'Settings',
        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
      ),
    );
  }
}
