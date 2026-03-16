// lib/features/settings/view/widgets/settings_app_bar.dart
import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/drawer/app_drawer_button.dart';

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
      leadingWidth: 60,
      leading: Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.only(left: 12),
          child: AppDrawerButton(
            colors: colors,
            onTap: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      centerTitle: false,
      title: Text(
        'Settings',
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
