import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

Widget buildTabBar(AppColor colors) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: colors.border, width: 1),
    ),
    child: TabBar(
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorPadding: EdgeInsets.zero,
      indicator: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      labelColor: Colors.white,
      unselectedLabelColor: colors.textSecondary,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.0,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.0,
      ),
      tabs: const [
        Tab(text: 'Assets'),
        Tab(text: 'Recipients'),
      ],
    ),
  );
}
