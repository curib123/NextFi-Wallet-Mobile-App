import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:next_fi/app/config/app_config.dart';
import 'package:next_fi/core/services/network_monitor.dart';
import 'package:next_fi/features/claimable/presentation/viewmodels/claimable_vm.dart';
import 'package:next_fi/features/import_wallet/presentation/viewmodels/import_wallet_vm.dart';
import 'package:next_fi/features/price_chart/presentation/viewmodels/price_chart_vm.dart';
import 'package:next_fi/features/portfolio/presentation/viewmodels/portfolio_vm.dart';
import 'package:next_fi/features/seed_phrases/presentation/viewmodels/seed_phrase_vm.dart';
import 'package:next_fi/features/settings/presentation/viewmodels/settings_vm.dart';
import 'package:next_fi/features/swap/presentation/viewmodels/swap_vm.dart';
import 'package:next_fi/features/transactions/presentation/viewmodels/transactions_vm.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_vm.dart';
import 'package:next_fi/features/wallet_settings/presentation/viewmodels/wallet_settings_vm.dart';
import 'package:next_fi/app/viewmodels/asset_vm.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/app/viewmodels/seed_keypair_vm.dart';
import 'package:next_fi/core/services/app_cover/app_cover_service.dart';
import 'package:next_fi/core/services/assets/asset_catalog_service.dart';
import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:next_fi/core/services/stellar/stellar_wallet_services.dart';

const String _kOnboardingSeenKey = 'pref.onboarding_seen.v1';
const String _kFirstTimeKey = 'first_time';
const FlutterSecureStorage _appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

class AppShellState {
  const AppShellState({
    this.showSplash = true,
    this.loading = true,
    this.hasMnemonic = false,
    this.isAuthenticated = false,
    this.showOnboarding = false,
  });

  final bool showSplash;
  final bool loading;
  final bool hasMnemonic;
  final bool isAuthenticated;
  final bool showOnboarding;

  AppShellState copyWith({
    bool? showSplash,
    bool? loading,
    bool? hasMnemonic,
    bool? isAuthenticated,
    bool? showOnboarding,
  }) {
    return AppShellState(
      showSplash: showSplash ?? this.showSplash,
      loading: loading ?? this.loading,
      hasMnemonic: hasMnemonic ?? this.hasMnemonic,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      showOnboarding: showOnboarding ?? this.showOnboarding,
    );
  }
}

class AppShellController extends Notifier<AppShellState> {
  @override
  AppShellState build() {
    Future.microtask(boot);
    return const AppShellState();
  }

  Future<void> boot() async {
    final splash = Future<void>.delayed(const Duration(seconds: 2));
    final check = _checkWallet();
    await Future.wait([splash, check]);
    if (!ref.mounted) return;
    state = state.copyWith(showSplash: false);
  }

  Future<void> _checkWallet() async {
    final storedMnemonic = await SeedStorage.getSeed();
    final onboardingSeen =
        await _appSecureStorage.read(key: _kOnboardingSeenKey) == '1';

    if (!ref.mounted) return;
    if (storedMnemonic != null && storedMnemonic.isNotEmpty) {
      state = state.copyWith(
        hasMnemonic: true,
        showOnboarding: false,
        loading: false,
      );
      return;
    }

    state = state.copyWith(
      hasMnemonic: false,
      showOnboarding: !onboardingSeen,
      loading: false,
    );
  }

  Future<void> completeOnboarding() async {
    await _appSecureStorage.write(key: _kOnboardingSeenKey, value: '1');
    if (!ref.mounted) return;
    state = state.copyWith(showOnboarding: false);
  }

  void setAuthenticated(bool value) {
    state = state.copyWith(isAuthenticated: value);
  }

  void completeWalletSetup({bool authenticated = true}) {
    state = state.copyWith(
      showSplash: false,
      loading: false,
      hasMnemonic: true,
      isAuthenticated: authenticated,
      showOnboarding: false,
    );
  }
}

class AppTabState {
  const AppTabState({this.currentIndex = 0, this.isFirstTime = false});

  final int currentIndex;
  final bool isFirstTime;

  AppTabState copyWith({int? currentIndex, bool? isFirstTime}) {
    return AppTabState(
      currentIndex: currentIndex ?? this.currentIndex,
      isFirstTime: isFirstTime ?? this.isFirstTime,
    );
  }
}

class AppTabController extends Notifier<AppTabState> {
  @override
  AppTabState build() {
    Future.microtask(_loadFirstTimeStatus);
    return const AppTabState();
  }

  void setTab(int index) {
    if (index < 0 || index > 4 || state.currentIndex == index) return;
    state = state.copyWith(currentIndex: index);
  }

  Future<void> _loadFirstTimeStatus() async {
    final value = await _appSecureStorage.read(key: _kFirstTimeKey);
    if (!ref.mounted) return;
    state = state.copyWith(
      isFirstTime: value == null ? true : value.toLowerCase() == 'true',
    );
  }

  Future<void> setFirstTimeFlag(bool value) async {
    await _appSecureStorage.write(key: _kFirstTimeKey, value: value.toString());
    if (!ref.mounted) return;
    state = state.copyWith(isFirstTime: value);
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.instance);

final appCoverServiceProvider = Provider<AppCoverService>((ref) {
  final service = AppCoverService();
  ref.onDispose(service.dispose);
  return service;
});

final assetCatalogServiceProvider = Provider<AssetCatalogService>((ref) {
  return AssetCatalogService();
});

final stellarWalletServiceProvider = Provider<StellarWalletServices>((ref) {
  final config = ref.watch(appConfigProvider);
  return StellarWalletServices(
    usdcIssuer: config.usdcIssuer,
    testnet: config.isTestnet,
    quickNodeUrlMainnet: config.quickNodeUrlMainnet,
    quickNodeUrlTestnet: config.quickNodeUrlTestnet,
    sorobanUrlMainnet: config.sorobanUrlMainnet,
    sorobanUrlTestnet: config.sorobanUrlTestnet,
  );
});

final networkMonitorProvider = ChangeNotifierProvider<NetworkMonitor>((ref) {
  return NetworkMonitor();
});

final seedKeypairProvider = ChangeNotifierProvider<SeedKeypairVM>((ref) {
  final vm = SeedKeypairVM();
  unawaited(vm.init());
  return vm;
});

final currencyVmProvider = ChangeNotifierProvider<CurrencyVM>((ref) {
  final stellar = ref.read(stellarWalletServiceProvider);
  final monitor = ref.read(networkMonitorProvider);
  final vm = CurrencyVM(stellar: stellar);

  void onMonitorChanged() {
    vm.handleConnectivityChanged(
      isOnline: monitor.isOnline,
      justReconnected: monitor.justReconnected,
    );
  }

  monitor.addListener(onMonitorChanged);
  onMonitorChanged();
  ref.onDispose(() => monitor.removeListener(onMonitorChanged));
  return vm;
});

final assetVmProvider = ChangeNotifierProvider<AssetVM>((ref) {
  final currency = ref.read(currencyVmProvider);
  final config = ref.read(appConfigProvider);
  final catalogService = ref.read(assetCatalogServiceProvider);
  return AssetVM(
    currency,
    isTestnet: config.isTestnet,
    usdcIssuer: config.usdcIssuer,
    catalogService: catalogService,
  );
});

final walletHomeVmProvider = ChangeNotifierProvider<WalletHomeVM>((ref) {
  final stellar = ref.read(stellarWalletServiceProvider);
  final seed = ref.read(seedKeypairProvider);
  final assets = ref.read(assetVmProvider);
  final currency = ref.read(currencyVmProvider);
  final vm = WalletHomeVM(
    stellar: stellar,
    seedVM: seed,
    assetVM: assets,
    currencyVM: currency,
  )
    ..bindToAddress(seed.accountId);

  void syncSeed() => vm.bindToAddress(seed.accountId);

  seed.addListener(syncSeed);
  ref.onDispose(() => seed.removeListener(syncSeed));
  return vm;
});

final transactionsVmProvider = ChangeNotifierProvider<TransactionsVM>((ref) {
  final stellar = ref.read(stellarWalletServiceProvider);
  final walletHome = ref.read(walletHomeVmProvider);
  final vm = TransactionsVM(stellarSvc: stellar);

  void syncWallet() => vm.bindToAddress(walletHome.state.address);

  walletHome.addListener(syncWallet);
  syncWallet();
  ref.onDispose(() => walletHome.removeListener(syncWallet));
  return vm;
});

final portfolioVmProvider = ChangeNotifierProvider<PortfolioVM>((ref) {
  final walletHome = ref.read(walletHomeVmProvider);
  final networkMonitor = ref.read(networkMonitorProvider);
  return PortfolioVM(
    walletHomeVM: walletHome,
    networkMonitor: networkMonitor,
  );
});

final priceChartVmProvider = ChangeNotifierProvider<PriceChartVM>((ref) {
  final currency = ref.read(currencyVmProvider);
  final assets = ref.read(assetVmProvider);
  return PriceChartVM(currency, assets);
});

final portfolioVmProvider = ChangeNotifierProvider<PortfolioVM>((ref) {
  final currency = ref.read(currencyVmProvider);
  final assets = ref.read(assetVmProvider);
  return PortfolioVM(currency: currency, assetVM: assets);
});

final importWalletVmProvider = ChangeNotifierProvider<ImportWalletVM>((ref) {
  return ImportWalletVM();
});

final walletSettingsVmProvider = ChangeNotifierProvider<WalletSettingsVM>((
  ref,
) {
  return WalletSettingsVM();
});

final settingsVmProvider = ChangeNotifierProvider<SettingsVM>((ref) {
  final vm = SettingsVM();
  unawaited(vm.initDefaults());
  return vm;
});

final seedPhraseVmProvider = ChangeNotifierProvider<SeedPhraseVM>((ref) {
  final stellar = ref.read(stellarWalletServiceProvider);
  return SeedPhraseVM(service: stellar);
});

final swapVmProvider = ChangeNotifierProvider<SwapVM>((ref) {
  final stellar = ref.read(stellarWalletServiceProvider);
  final seed = ref.read(seedKeypairProvider);
  final walletHome = ref.read(walletHomeVmProvider);
  final assets = ref.read(assetVmProvider);
  final vm = SwapVM(
    svc: stellar,
    keypairVM: seed,
    walletHomeVM: walletHome,
    assetVM: assets,
  )..bindToAddress(seed.accountId);

  void syncSeed() => vm.bindToAddress(seed.accountId);

  seed.addListener(syncSeed);
  ref.onDispose(() => seed.removeListener(syncSeed));
  return vm;
});

final claimableVmProvider = ChangeNotifierProvider<ClaimableVM>((ref) {
  final stellar = ref.read(stellarWalletServiceProvider);
  final seed = ref.read(seedKeypairProvider);
  final walletHome = ref.read(walletHomeVmProvider);
  final assets = ref.read(assetVmProvider);
  return ClaimableVM(
    service: stellar,
    seedVM: seed,
    walletHomeVM: walletHome,
    assetVM: assets,
  );
});

final appShellProvider = NotifierProvider<AppShellController, AppShellState>(
  AppShellController.new,
);

final tabControllerProvider = NotifierProvider<AppTabController, AppTabState>(
  AppTabController.new,
);
