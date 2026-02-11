import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

Widget buildTabBar(AppColor colors) {
  return Container(
    padding: EdgeInsets.only(bottom: 10),
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