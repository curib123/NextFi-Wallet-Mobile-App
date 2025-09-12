// lib/features/auth_gate/view/widgets/top_bar.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, required this.colors});
  final AppColor colors;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: colors.background,
      elevation: 0,
      centerTitle: true,
      title: Text(
        "Security",
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      leading: Navigator.canPop(context)
          ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: colors.textPrimary,
        onPressed: () => Navigator.pop(context),
      )
          : null,
    );
  }
}
