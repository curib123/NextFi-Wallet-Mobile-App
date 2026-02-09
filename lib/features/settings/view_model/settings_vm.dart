import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:next_fi/features/auth_gate/view/auth_gate_screen.dart';
import 'package:next_fi/features/settings/model/settings_model.dart';
import 'package:next_fi/features/wallet_settings/view/wallet_screen_settings.dart';
import 'package:next_fi/common/components/modal/showFiatPickerBottomSheet.dart';
import 'package:next_fi/common/components/modal/showPinChangeBottomSheet.dart';
import 'package:next_fi/services/secure_storage/security_storage.dart';

/// Optional bridge the app can hook to actually apply ThemeMode at root.
/// In your app bootstrap (near MaterialApp), set once:
///   ThemeBridge.apply = (mode) { myThemeController.setMode(mode); };
typedef ThemeApplier = FutureOr<void> Function(ThemeMode mode);
class ThemeBridge { static ThemeApplier? apply; }

class SettingsVM extends ChangeNotifier {
  SettingsVM();

  final LocalAuthentication _localAuth = LocalAuthentication();

  // -------------------------
  // Secure storage (for theme)
  // -------------------------
  static const String _kThemePrefKey = 'pref.theme_mode.v1'; // 'light' | 'dark' | 'system'
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // -------------------------
  // Biometrics UI state
  // -------------------------
  bool _bioSupported = false;
  bool _bioEnabled = false;
  bool get biometricsSupported => _bioSupported;
  bool get biometricsEnabled => _bioEnabled;

  // -------------------------
  // Theme state
  // -------------------------
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // -------------------------
  // Sections data
  // -------------------------
  List<SettingSection> _sections = const [];
  List<SettingSection> get sections => _sections;

  /// Call once (we also call this from reusable_view_model registration in main).
  Future<void> initDefaults() async {
    // Ensure platform keystores are ready (your SecurityStorage helper already does a probe)
    await SecurityStorage.ensureReady();

    await Future.wait([
      _loadBiometricState(),
      _loadThemeMode(),
    ]);

    _sections = [
      // 1) Account
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

      // 2) Security
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
            subtitle: _subtitleForBiometricStatic, // temporary; recalculated post-load
            icon: LucideIcons.fingerprint,
            action: SettingAction.biometrics,
            enabled: true, // row visible; switch enable is gated in the UI
          ),
        ],
      ),

      // 3) Preferences
      SettingSection(
        header: 'Preferences',
        items: [
          const SettingItem(
            title: 'Fiat Currency',
            subtitle: 'Change display currency (PHP, USD, etc.)',
            icon: LucideIcons.banknote,
            action: SettingAction.fiatCurrency,
          ),
          // Appearance (Theme) uses secure storage now
          SettingItem(
            title: 'Appearance (Theme)',
            subtitle: _themeSubtitle(),
            icon: LucideIcons.moon,
            action: SettingAction.themeMode,
          ),
        ],
      ),
    ];

    // Patch dynamic subtitles now that state is known
    _sections = _sections.map((sec) {
      final items = sec.items.map((it) {
        if (it.action == SettingAction.biometrics) {
          return it.copyWith(
            subtitle: _subtitleForBiometric(),
            enabled: biometricsSupported,
          );
        }
        if (it.action == SettingAction.themeMode) {
          return it.copyWith(subtitle: _themeSubtitle());
        }
        return it;
      }).toList();
      return sec.copyWith(items: items);
    }).toList();

    notifyListeners();
  }

  // ===========================================================================
  // THEME MODE (Flutter Secure Storage)
  // ===========================================================================
  String _themeSubtitle() {
    switch (_themeMode) {
      case ThemeMode.light: return 'Light';
      case ThemeMode.dark: return 'Dark';
      case ThemeMode.system: return 'System';
    }
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

  Future<void> _persistThemeMode(ThemeMode mode) async {
    try {
      final raw = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await _secure.write(key: _kThemePrefKey, value: raw);
    } catch (_) {/* ignore */}
  }

  /// Switch.adaptive handler: true = Dark, false = Light
  Future<void> onToggleDarkMode(BuildContext context, bool dark) async {
    HapticFeedback.selectionClick();
    final newMode = dark ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(context, newMode);
  }

  /// Public setter (useful if you later add a bottom sheet with 3 choices).
  Future<void> setThemeMode(BuildContext context, ThemeMode mode) async {
    _themeMode = mode;
    await _persistThemeMode(mode);

    // Update subtitle in sections immediately
    _sections = _sections.map((sec) {
      final items = sec.items.map((it) {
        if (it.action == SettingAction.themeMode) {
          return it.copyWith(subtitle: _themeSubtitle());
        }
        return it;
      }).toList();
      return sec.copyWith(items: items);
    }).toList();

    notifyListeners();

    // Ask host app to apply real theme at MaterialApp level.
    try { await ThemeBridge.apply?.call(mode); } catch (_) {/* ignore */}
  }

  // ===========================================================================
  // BIOMETRICS
  // ===========================================================================
  static String get _subtitleForBiometricStatic =>
      'Use fingerprint/face to unlock';

  String _subtitleForBiometric() =>
      biometricsSupported ? 'Use fingerprint/face to unlock' : 'Not available on this device';

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

  /// Enabling → navigate to AuthGateScreen to confirm (PIN/Biometric) then enable.
  /// Disabling → flip off immediately.
  Future<void> onToggleBiometrics(BuildContext context, bool value) async {
    HapticFeedback.selectionClick();
    await _loadBiometricState();

    if (!biometricsSupported) {
      _showSnack(context, 'Biometric unlock is not available on this device.');
      notifyListeners();
      return;
    }

    if (value) {
      final hasPin = await SecurityStorage.hasPin();
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
              _bioEnabled = true;
              notifyListeners();
              _showSnack(context, 'Biometric unlock enabled.');
              Navigator.of(context).pop(true);
            },
          ),
        ),
      );

      if (success != true) {
        // user cancelled / failed → keep previous state
        notifyListeners();
      }
    } else {
      await SecurityStorage.setBiometricsEnabled(false);
      _bioEnabled = false;
      notifyListeners();
      _showSnack(context, 'Biometric unlock disabled.');
    }
  }

  // ===========================================================================
  // Sections + actions
  // ===========================================================================
  void setSections(List<SettingSection> sections) {
    _sections = sections.where((s) => s.items.isNotEmpty).toList(growable: false);
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

      case SettingAction.biometrics:
      // No-op; the trailing switch drives toggling.
        break;

      case SettingAction.themeMode:
      // Optional: later, show a bottom-sheet to pick Light/Dark/System.
      // For now, the switch directly toggles Light <-> Dark.
        break;
    }
  }

  void _showSnack(BuildContext context, String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }
}
