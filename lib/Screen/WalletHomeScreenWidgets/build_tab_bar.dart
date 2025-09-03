import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

Widget buildTabBar(AppColor colors) {
  return Container(
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: TabBar(
      dividerColor: Colors.transparent,
      labelColor: colors.primary,
      unselectedLabelColor: colors.textSecondary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      tabs: const [
        Tab(text: 'Assets & Holdings'),
        Tab(text: 'Recipient Address'),
      ],
    ),
  );
}