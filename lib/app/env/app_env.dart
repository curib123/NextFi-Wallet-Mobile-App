import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  AppEnv._();

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    await dotenv.load(fileName: '.env');
    _loaded = true;
  }

  static String _read(String key, {String fallback = ''}) {
    final value = dotenv.maybeGet(key)?.trim();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  static String get environment => _read('NEXTFI_ENV', fallback: 'production');

  static bool get isTestnet =>
      _read('NEXTFI_NETWORK', fallback: 'public').toLowerCase() == 'testnet';

  static String get backendBaseUrl {
    final current = _read('NEXTFI_API_BASE_URL');
    if (current.isNotEmpty) return current;
    return _read('NEXTFI_BACKEND_BASE_URL');
  }
  static String get federationDomain =>
      _read('NEXTFI_FEDERATION_DOMAIN', fallback: 'nextfi.app');
  static String get usdcIssuerMainnet => _read('NEXTFI_USDC_ISSUER_MAINNET');
  static String get usdcIssuerTestnet => _read('NEXTFI_USDC_ISSUER_TESTNET');
  static String? get fixerApiKey {
    final value = _read('NEXTFI_FIXER_API_KEY');
    return value.isEmpty ? null : value;
  }

  static String? get openExchangeRatesAppId {
    final value = _read('NEXTFI_OPEN_EXCHANGE_RATES_APP_ID');
    return value.isEmpty ? null : value;
  }

  static String? get quickNodeUrlMainnet {
    final value = _read('NEXTFI_QUICKNODE_URL_MAINNET');
    return value.isEmpty ? null : value;
  }

  static String? get quickNodeUrlTestnet {
    final value = _read('NEXTFI_QUICKNODE_URL_TESTNET');
    return value.isEmpty ? null : value;
  }

  static String? get sorobanUrlMainnet {
    final value = _read('NEXTFI_SOROBAN_URL_MAINNET');
    return value.isEmpty ? null : value;
  }

  static String? get sorobanUrlTestnet {
    final value = _read('NEXTFI_SOROBAN_URL_TESTNET');
    return value.isEmpty ? null : value;
  }

  static void validate() {
    final missing = <String>[];
    if (backendBaseUrl.isEmpty) {
      missing.add('NEXTFI_API_BASE_URL (or NEXTFI_BACKEND_BASE_URL)');
    }
    if (usdcIssuerMainnet.isEmpty) missing.add('NEXTFI_USDC_ISSUER_MAINNET');
    if (usdcIssuerTestnet.isEmpty) missing.add('NEXTFI_USDC_ISSUER_TESTNET');
    if (missing.isEmpty) return;
    throw StateError('Missing required .env values: ${missing.join(', ')}');
  }

  static void debugPrintSummary() {
    if (!kDebugMode) return;
    debugPrint(
      '[AppEnv] env=$environment network=${isTestnet ? 'testnet' : 'public'} '
      'backend=$backendBaseUrl federation=$federationDomain',
    );
  }
}
