// lib/features/settings/view/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:next_fi/features/settings/model/settings_model.dart';
import 'package:next_fi/features/settings/view/widgets/fiat_chip.dart';
import 'package:next_fi/features/settings/view/widgets/section_header.dart';
import 'package:next_fi/features/settings/view/widgets/settings_app_bar.dart';
import 'package:next_fi/features/settings/view/widgets/settings_card.dart';
import 'package:next_fi/features/settings/view_model/settings_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'widgets/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = context.watch<SettingsVM>();
    final sections = vm.sections.where((s) => s.items.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: c.surface,
      appBar: SettingsAppBar(colors: c),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: sections.length,
          itemBuilder: (ctx, i) {
            final section = sections[i];
            final hasHeader = (section.header ?? '').trim().isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasHeader) SectionHeader(text: section.header!, colors: c),
                SettingsCard(
                  items: section.items,
                  onTapItem: (it) => vm.handleAction(context, it.action),
                  trailingBuilder: (it) {
                    if (it.action == SettingAction.fiatCurrency) return const FiatChip();
                    return const SizedBox.shrink(); // non-null fallback
                  },

                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}
