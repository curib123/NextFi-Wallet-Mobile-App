import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/features/settings/data/models/settings_model.dart';
import 'package:next_fi/core/widgets/drawer/app_drawer.dart';
import 'package:next_fi/features/settings/presentation/widgets/fiat_chip.dart';
import 'package:next_fi/features/settings/presentation/widgets/section_header.dart';
import 'package:next_fi/features/settings/presentation/widgets/settings_app_bar.dart';
import 'package:next_fi/features/settings/presentation/widgets/settings_card.dart';
import 'package:next_fi/app/theme/app_color.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(settingsVmProvider).initDefaults();
      });
      _initialized = true;
    }
  }

  Future<void> _refresh() async {
    await ref.read(settingsVmProvider).initDefaults();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = ref.watch(settingsVmProvider);
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


