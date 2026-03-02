import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

Widget buildTabBar(AppColor colors) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: TabBar(
      dividerColor: colors.surface.withValues(alpha: 0),
      indicator: const BoxDecoration(),
      labelColor: colors.primary,
      unselectedLabelColor: colors.textSecondary,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 0.0,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        letterSpacing: 0.0,
      ),
      tabs: const [
        Tab(text: 'Assets'),
        Tab(text: 'Recipients'),
      ],
    ),
  );
}
