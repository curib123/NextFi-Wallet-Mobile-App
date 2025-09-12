// lib/features/settings/viewmodel/settings_vm.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/showFiatPickerBottomSheet.dart';
import 'package:next_fi/common/components/showPinChangeBottomSheet.dart';
import 'package:next_fi/features/settings/model/settings_model.dart';
import 'package:next_fi/features/wallet_settings/view/wallet_screen_settings.dart';


class SettingsVM extends ChangeNotifier {
  SettingsVM();

  List<SettingSection> _sections = const [];
  List<SettingSection> get sections => _sections;

  /// Call once (we also call this from Provider registration in main).
  void initDefaults() {
    _sections = [
      SettingSection(
        header: 'Account',
        items: const [
          SettingItem(
            title: 'Wallet',
            subtitle: 'View recovery phrases securely',
            icon: LucideIcons.wallet2,
            action: SettingAction.wallet,
          ),
          SettingItem(
            title: 'Security',
            subtitle: 'Change pin code',
            icon: LucideIcons.shield,
            action: SettingAction.changePin,
          ),
        ],
      ),
      SettingSection(
        header: 'Preferences',
        items: const [
          SettingItem(
            title: 'Fiat Currency',
            subtitle: 'Change display currency (PHP, USD, etc.)',
            icon: LucideIcons.banknote,
            action: SettingAction.fiatCurrency,
          ),
        ],
      ),
    ];
    notifyListeners();
  }

  /// Optional public APIs to modify sections at runtime.
  void setSections(List<SettingSection> sections) {
    _sections = sections.where((s) => s.items.isNotEmpty).toList(growable: false);
    notifyListeners();
  }

  void clear() {
    _sections = const [];
    notifyListeners();
  }

  /// Handle taps (navigation & sheets). Keep navigation here for simplicity.
  Future<void> handleAction(BuildContext context, SettingAction action) async {
    HapticFeedback.selectionClick();

    switch (action) {
      case SettingAction.wallet:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WalletScreenSettings()),
        );
        break;

      case SettingAction.changePin:
        await showPinChangeBottomSheet(context);
        break;

      case SettingAction.fiatCurrency:
        await showFiatPickerBottomSheet(context);
        break;
    }
  }
}
