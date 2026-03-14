// lib/features/settings/view/widgets/settings_card.dart
import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/features/settings/data/models/settings_model.dart';
import 'setting_tile.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.items,
    required this.onTapItem,
    this.trailingBuilder,
  });

  final List<SettingItem> items;
  final void Function(SettingItem item) onTapItem;
  final Widget Function(SettingItem item)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: c.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: c.primary.withValues(alpha: 0.08),
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (ctx, i) {
          final it = items[i];
          return SettingTile(
            item: it,
            trailing: trailingBuilder?.call(it),
            onTap: () => onTapItem(it),
          );
        },
      ),
    );
  }
}

