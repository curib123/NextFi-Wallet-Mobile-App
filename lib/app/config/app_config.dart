import 'package:flutter/foundation.dart';

import 'package:next_fi/app/env/app_env.dart';

class AppConfig {
  AppConfig._({
    required this.environment,
    required this.isTestnet,
    required this.backendBaseUrl,
    required this.federationDomain,
    required this.usdcIssuer,
    this.quickNodeUrlMainnet,
    this.quickNodeUrlTestnet,
    this.sorobanUrlMainnet,
    this.sorobanUrlTestnet,
  });

  final String environment;
  final bool isTestnet;
  final String backendBaseUrl;
  final String federationDomain;
  final String usdcIssuer;
  final String? quickNodeUrlMainnet;
  final String? quickNodeUrlTestnet;
  final String? sorobanUrlMainnet;
  final String? sorobanUrlTestnet;

  static AppConfig? _instance;

  static AppConfig get instance {
    final current = _instance;
    if (current == null) {
      throw StateError('AppConfig not initialized.');
    }
    return current;
  }

  static Future<void> bootstrap() async {
    await AppEnv.load();
    AppEnv.validate();
    _instance = AppConfig._(
      environment: AppEnv.environment,
      isTestnet: AppEnv.isTestnet,
      backendBaseUrl: AppEnv.backendBaseUrl,
      federationDomain: AppEnv.federationDomain,
      usdcIssuer: AppEnv.isTestnet
          ? AppEnv.usdcIssuerTestnet
          : AppEnv.usdcIssuerMainnet,
      quickNodeUrlMainnet: AppEnv.quickNodeUrlMainnet,
      quickNodeUrlTestnet: AppEnv.quickNodeUrlTestnet,
      sorobanUrlMainnet: AppEnv.sorobanUrlMainnet,
      sorobanUrlTestnet: AppEnv.sorobanUrlTestnet,
    );
    AppEnv.debugPrintSummary();
    if (kDebugMode) {
      debugPrint(
        '[AppConfig] issuer=${instance.usdcIssuer} '
        'testnet=${instance.isTestnet}',
      );
    }
  }
}
