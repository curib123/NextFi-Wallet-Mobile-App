// lib/features/settings/view/widgets/setting_tile.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/features/settings/model/settings_model.dart';

class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.item,
    required this.onTap,
    this.trailing,
  });

  final SettingItem item;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    final leadingBg = (item.accentColor ?? c.primary).withOpacity(0.07);

    final Widget leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: leadingBg,
        borderRadius: BorderRadius.circular(50),
      ),
      alignment: Alignment.center,
      child: Icon(item.icon, color: item.accentColor ?? c.primary, size: 18),
    );

    final Widget effectiveTrailing = trailing ??
        Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: item.enabled ? c.textSecondary.withOpacity(0.9) : c.textSecondary.withOpacity(0.4),
        );

    final textPrimary = item.enabled ? c.textPrimary : c.textSecondary.withOpacity(0.6);

    return MergeSemantics(
      child: Semantics(
        button: item.enabled,
        enabled: item.enabled,
        label: item.title,
        hint: (item.subtitle ?? '').isNotEmpty ? item.subtitle : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.enabled ? onTap : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800)),
                            if ((item.subtitle ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      effectiveTrailing,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
