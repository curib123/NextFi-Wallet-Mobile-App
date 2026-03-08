import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/features/settings/model/settings_model.dart';
import 'package:next_fi/common/components/drawer/appdrawer.dart';
import 'package:next_fi/features/settings/view/widgets/fiat_chip.dart';
import 'package:next_fi/features/settings/view/widgets/section_header.dart';
import 'package:next_fi/features/settings/view/widgets/settings_app_bar.dart';
import 'package:next_fi/features/settings/view/widgets/settings_card.dart';
import 'package:next_fi/features/settings/view_model/settings_vm.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<SettingsVM>().initDefaults();
      });
      _initialized = true;
    }
  }

  Future<void> _refresh() async {
    await context.read<SettingsVM>().initDefaults();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = context.watch<SettingsVM>();
    final sections = vm.sections.where((s) => s.items.isNotEmpty).toList();

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: c.surface,
      appBar: SettingsAppBar(colors: c),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: c.accent,
          backgroundColor: c.surface,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      if (it.action == SettingAction.fiatCurrency) {
                        return const FiatChip();
                      }

                      if (it.action == SettingAction.biometrics) {
                        // Switch enabled only when device supports biometrics.
                        final isSwitchEnabled = it.enabled && vm.biometricsSupported;
                        return Switch.adaptive(
                          value: vm.biometricsEnabled,
                          onChanged: isSwitchEnabled
                              ? (val) => vm.onToggleBiometrics(context, val)
                              : null,
                        );
                      }

                      // NEW: Appearance (Theme) toggle (Light <-> Dark)
                      if (it.action == SettingAction.themeMode) {
                        return Switch.adaptive(
                          value: vm.isDarkMode, // true = Dark, false = Light
                          onChanged: (val) => vm.onToggleDarkMode(context, val),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
