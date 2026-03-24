import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/services/secure_storage/security_storage.dart';
import 'package:next_fi/core/widgets/modal/show_fiat_picker_bottom_sheet.dart';
import 'package:next_fi/core/widgets/modal/show_pin_change_bottom_sheet.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/features/auth_gate/presentation/screens/auth_gate_screen.dart';
import 'package:next_fi/features/settings/data/models/settings_model.dart';
import 'package:next_fi/features/wallet_settings/presentation/screens/wallet_settings_screen.dart';

typedef ThemeApplier = FutureOr<void> Function(ThemeMode mode);

class ThemeBridge {
  static ThemeApplier? apply;
}

typedef ThemeStyleApplier = FutureOr<void> Function(int styleIndex);

class ThemeStyleBridge {
  static ThemeStyleApplier? apply;
}

class SettingsVM extends ChangeNotifier {
  SettingsVM();

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _kThemePrefKey = 'pref.theme_mode.v1';
  static const String _kThemeStylePrefKey = 'pref.theme_style_index.v1';
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  bool _bioSupported = false;
  bool _bioEnabled = false;
  bool get biometricsSupported => _bioSupported;
  bool get biometricsEnabled => _bioEnabled;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  int _themeStyleIndex = 1;
  int get themeStyleIndex => _themeStyleIndex;

  List<SettingSection> _sections = const [];
  List<SettingSection> get sections => _sections;

  Future<void> initDefaults() async {
    await SecurityStorage.ensureReady();

    await Future.wait([
      _loadBiometricState(),
      _loadThemeMode(),
      _loadThemeStyle(),
    ]);

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
        ],
      ),
      SettingSection(
        header: 'Security',
        items: [
          const SettingItem(
            title: 'PIN code',
            subtitle: 'Change or set your 6-digit PIN',
            icon: LucideIcons.shield,
            action: SettingAction.changePin,
          ),
          SettingItem(
            title: 'Biometric unlock',
            subtitle: _subtitleForBiometric(),
            icon: LucideIcons.fingerprint,
            action: SettingAction.biometrics,
            enabled: _bioSupported,
          ),
        ],
      ),
      SettingSection(
        header: 'Preferences',
        items: [
          const SettingItem(
            title: 'Fiat currency',
            subtitle: 'Change display currency (PHP, USD, etc.)',
            icon: LucideIcons.banknote,
            action: SettingAction.fiatCurrency,
          ),
          SettingItem(
            title: 'Appearance',
            subtitle: _appearanceSubtitle(),
            icon: LucideIcons.palette,
            action: SettingAction.themeMode,
          ),
        ],
      ),
    ];

    notifyListeners();
  }

  String _themeSubtitle() {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  String _appearanceSubtitle() {
    return '${_themeSubtitle()} · ${AppColor.themeStyleLabel(_themeStyleIndex)}';
  }

  String _subtitleForBiometric() {
    return _bioSupported
        ? 'Use fingerprint/face to unlock'
        : 'Not available on this device';
  }

  Future<void> _loadThemeMode() async {
    try {
      final raw = await _secure.read(key: _kThemePrefKey) ?? 'system';
      _themeMode = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      _themeMode = ThemeMode.system;
    }
  }

  Future<void> _loadThemeStyle() async {
    try {
      final raw = await _secure.read(key: _kThemeStylePrefKey);
      final parsed = int.tryParse(raw ?? '');
      _themeStyleIndex = AppColor.normalizeThemeStyleIndex(parsed ?? 1);
    } catch (_) {
      _themeStyleIndex = 1;
    }
  }

  Future<void> _persistThemeMode(ThemeMode mode) async {
    try {
      final raw = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await _secure.write(key: _kThemePrefKey, value: raw);
    } catch (_) {}
  }

  Future<void> _persistThemeStyle(int styleIndex) async {
    try {
      await _secure.write(
        key: _kThemeStylePrefKey,
        value: styleIndex.toString(),
      );
    } catch (_) {}
  }

  void _syncAppearanceSubtitle() {
    _sections = _sections.map((section) {
      final items = section.items.map((item) {
        if (item.action == SettingAction.biometrics) {
          return item.copyWith(
            subtitle: _subtitleForBiometric(),
            enabled: _bioSupported,
          );
        }
        if (item.action == SettingAction.themeMode) {
          return item.copyWith(subtitle: _appearanceSubtitle());
        }
        return item;
      }).toList();
      return section.copyWith(items: items);
    }).toList();
  }

  Future<void> setThemeMode(BuildContext context, ThemeMode mode) async {
    _themeMode = mode;
    await _persistThemeMode(mode);
    _syncAppearanceSubtitle();
    notifyListeners();

    try {
      await ThemeBridge.apply?.call(mode);
    } catch (_) {}
  }

  Future<void> setThemeStyle(BuildContext context, int styleIndex) async {
    _themeStyleIndex = AppColor.normalizeThemeStyleIndex(styleIndex);
    await _persistThemeStyle(_themeStyleIndex);
    _syncAppearanceSubtitle();
    notifyListeners();

    try {
      await ThemeStyleBridge.apply?.call(_themeStyleIndex);
    } catch (_) {}
  }

  Future<void> _loadBiometricState() async {
    bool supported = false;
    bool enabled = false;

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();
      supported = (canCheck || isSupported) && available.isNotEmpty;
    } catch (_) {
      supported = false;
    }

    try {
      enabled = await SecurityStorage.isBiometricsEnabled();
    } catch (_) {
      enabled = false;
    }

    _bioSupported = supported;
    _bioEnabled = enabled;
  }

  Future<void> onToggleBiometrics(BuildContext context, bool value) async {
    HapticFeedback.selectionClick();
    await _loadBiometricState();
    if (!context.mounted) return;

    if (!_bioSupported) {
      _showSnack(context, 'Biometric unlock is not available on this device.');
      notifyListeners();
      return;
    }

    if (value) {
      final hasPin = await SecurityStorage.hasPin();
      if (!context.mounted) return;
      if (!hasPin) {
        _showSnack(context, 'Set a 6-digit PIN first in Security.');
        notifyListeners();
        return;
      }

      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AuthGateScreen(
            goNext: () async {
              await SecurityStorage.setBiometricsEnabled(true);
              if (!context.mounted) return;
              _bioEnabled = true;
              _syncAppearanceSubtitle();
              notifyListeners();
              _showSnack(context, 'Biometric unlock enabled.');
              Navigator.of(context).pop(true);
            },
          ),
        ),
      );

      if (success != true) {
        notifyListeners();
      }
    } else {
      await SecurityStorage.setBiometricsEnabled(false);
      if (!context.mounted) return;
      _bioEnabled = false;
      _syncAppearanceSubtitle();
      notifyListeners();
      _showSnack(context, 'Biometric unlock disabled.');
    }
  }

  void setSections(List<SettingSection> sections) {
    _sections = sections
        .where((s) => s.items.isNotEmpty)
        .toList(growable: false);
    notifyListeners();
  }

  void clear() {
    _sections = const [];
    notifyListeners();
  }

  Future<void> handleAction(BuildContext context, SettingAction action) async {
    HapticFeedback.selectionClick();
    switch (action) {
      case SettingAction.wallet:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const WalletScreenSettings()));
        break;
      case SettingAction.changePin:
        await showPinChangeBottomSheet(context);
        break;
      case SettingAction.fiatCurrency:
        await showFiatPickerBottomSheet(context);
        break;
      case SettingAction.biometrics:
        break;
      case SettingAction.themeMode:
        await showAppearanceSheet(context);
        break;
    }
  }

  Future<void> showAppearanceSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = AppColor.of(sheetContext);
        final textTheme = Theme.of(sheetContext).textTheme;
        final selectedMode = _themeMode;
        final selectedStyle = _themeStyleIndex;

        Widget modeCard(
          ThemeMode mode,
          IconData icon,
          String title,
          String subtitle,
        ) {
          final selected = selectedMode == mode;
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await setThemeMode(context, mode);
            },
            child: Ink(
              decoration: BoxDecoration(
                color: selected ? colors.surfaceRaised : colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? colors.primary : colors.border,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary.withValues(alpha: 0.14)
                            : colors.surfaceOverlay,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: 18,
                        color: selected ? colors.primary : colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleMedium?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        final mediaQuery = MediaQuery.of(sheetContext);
        final maxHeight = mediaQuery.size.height * 0.88;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colors.border),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Appearance',
                      style: textTheme.titleLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Theme controls live here only, with blue accent variants tuned for clear contrast and consistent branding.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Theme mode',
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    modeCard(
                      ThemeMode.system,
                      LucideIcons.smartphone,
                      'System',
                      'Follow the device appearance.',
                    ),
                    const SizedBox(height: 10),
                    modeCard(
                      ThemeMode.light,
                      LucideIcons.sun,
                      'Light',
                      'Bright surfaces with strong text contrast.',
                    ),
                    const SizedBox(height: 10),
                    modeCard(
                      ThemeMode.dark,
                      LucideIcons.moon,
                      'Dark',
                      'Low-glare surfaces with readable text.',
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Blue theme',
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: AppColor.themeStyleCount,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 2.15,
                          ),
                      itemBuilder: (gridContext, index) {
                        final normalized = AppColor.normalizeThemeStyleIndex(
                          index,
                        );
                        final selected =
                            normalized ==
                            AppColor.normalizeThemeStyleIndex(selectedStyle);
                        final preview = AppColor.themeStylePreview(
                          index,
                          Theme.of(sheetContext).brightness,
                        );

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await setThemeStyle(context, index);
                          },
                          child: Ink(
                            decoration: BoxDecoration(
                              color: selected
                                  ? colors.surfaceRaised
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected ? preview : colors.border,
                                width: selected ? 1.4 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: preview,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      AppColor.themeStyleLabel(normalized),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.titleSmall?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: preview,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnack(BuildContext context, String text) {
    showFloatingSnackBar(context, message: text, type: SnackBarType.info);
  }
}
