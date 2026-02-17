// ───────────────────────── Flutter SDK ─────────────────────────
import 'package:flutter/material.dart';

// ───────────────────── 3rd-party packages ─────────────────────
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:next_fi/features/settings/view_model/settings_vm.dart';
import 'package:next_fi/firebase_options.dart';
import 'package:next_fi/services/device_meta/devices_meta.dart';
import 'package:next_fi/services/fcm_notification/fcm_notification_core.dart';
import 'package:next_fi/services/fcm_notification/fcm_bootstrap.dart';
import 'package:next_fi/services/local_notif/local_nofification.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// ─────────────────────────── App core ─────────────────────────
import 'package:next_fi/app/home.dart';
import 'package:next_fi/Helper/colors/AppColor.dart' hide ThemeBridge;

// ─────────────────────────── Services ─────────────────────────
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

// ───────────────────────── View Models ────────────────────────
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';

import 'package:next_fi/features/auth_gate/view_model/auth_gate_vm.dart';
import 'package:next_fi/features/claimable/view_model/claimable_vm.dart';
import 'package:next_fi/features/import_wallet/view_model/import_wallet_vm.dart';
import 'package:next_fi/features/price_chart/view_model/price_chart_vm.dart';
import 'package:next_fi/features/seed_phrases/view_model/seed_phrase_vm.dart';
import 'package:next_fi/features/send/view_model/send_vm.dart';
import 'package:next_fi/features/swap/view_model/swap_vm.dart';
import 'package:next_fi/features/transactions/view_model/transactions_vm.dart';
import 'package:next_fi/features/wallet_creation/view_model/wallet_creation_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:next_fi/features/wallet_settings/view_model/wallet_settings_vm.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ───────────────────────── Theme persistence ─────────────────────────
const String _kThemePrefKey = 'pref.theme_mode.v1';
const FlutterSecureStorage _secure = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

final ValueNotifier<ThemeMode> _themeModeVN = ValueNotifier(ThemeMode.system);

Future<void> _loadInitialThemeMode() async {
  final raw = await _secure.read(key: _kThemePrefKey) ?? 'system';
  final mode = switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  _themeModeVN.value = mode;
}

// ───────────────────────── FCM background handler ─────────────────────────
// Must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('[FCM][bg] ${message.messageId} data=${message.data}');
  // System notification is shown automatically by backend config (no need to call LocalNotif here)
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadInitialThemeMode();

  ThemeBridge.apply = (mode) async {
    _themeModeVN.value = mode;
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _secure.write(key: _kThemePrefKey, value: raw);
  };

  // ✅ Use FcmBootstrap for clean initialization
  await FcmBootstrap.init();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    Phoenix(
      child: MultiProvider(
        providers: _buildProviders(),
        child: const MyApp(),
      ),
    ),
  );
}

List<SingleChildWidget> _buildProviders() {
  const bool kIsTestnet = false;

  const String defaultUsdcMainnet =
      'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';
  const String defaultUsdcTestnet =
      'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';

  return [
    // 1) Boot an initial Stellar service
    Provider<StellarWalletServices>(
      create: (_) => StellarWalletServices(
        usdcIssuer: kIsTestnet ? defaultUsdcTestnet : defaultUsdcMainnet,
        testnet: kIsTestnet,
      ),
    ),

    // 2) Seed keypair VM
    ChangeNotifierProvider(
      create: (_) => SeedKeypairVM()..init(),
    ),

    // 3) Currency depends on Stellar service
    ChangeNotifierProxyProvider<StellarWalletServices, CurrencyVM>(
      create: (ctx) => CurrencyVM(stellar: ctx.read<StellarWalletServices>()),
      update: (ctx, stellar, prev) => prev ?? CurrencyVM(stellar: stellar),
    ),

    // 4) AssetVM depends on Currency
    ChangeNotifierProxyProvider<CurrencyVM, AssetVM>(
      create: (ctx) => AssetVM(ctx.read<CurrencyVM>(), isTestnet: kIsTestnet),
      update: (ctx, currency, prev) =>
      prev ?? AssetVM(currency, isTestnet: kIsTestnet),
    ),

    // 5) Replace Stellar service when AssetVM is ready
    ProxyProvider<AssetVM, StellarWalletServices>(
      update: (ctx, assetVM, old) {
        final issuer = assetVM.usdcIssuer;
        if (old == null || old.usdcIssuer != issuer || old.isTestnet != kIsTestnet) {
          return StellarWalletServices(
            usdcIssuer: issuer,
            testnet: kIsTestnet,
          );
        }
        return old;
      },
    ),

    // 6) WalletHome depends on Stellar + SeedKeypair
    ChangeNotifierProxyProvider2<StellarWalletServices, SeedKeypairVM, WalletHomeVM>(
      create: (ctx) => WalletHomeVM(
        stellar: ctx.read<StellarWalletServices>(),
        seedVM: ctx.read<SeedKeypairVM>(),
      )..bindToAddress(ctx.read<SeedKeypairVM>().accountId),
      update: (ctx, stellar, seedVM, existing) {
        final vm = existing ?? WalletHomeVM(stellar: stellar, seedVM: seedVM);
        vm.bindToAddress(seedVM.accountId);
        return vm;
      },
    ),

    // 7) Price chart depends on Currency
    ChangeNotifierProxyProvider<CurrencyVM, PriceChartVM>(
      create: (ctx) => PriceChartVM(ctx.read<CurrencyVM>()),
      update: (ctx, currency, prev) => prev ?? PriceChartVM(currency),
    ),

    // 9) Base VMs (independent)
    ChangeNotifierProvider<ImportWalletVM>(create: (_) => ImportWalletVM()),
    ChangeNotifierProvider<RecipientAddressVM>(create: (_) => RecipientAddressVM()),
    ChangeNotifierProvider<TabVM>(create: (_) => TabVM()),
    ChangeNotifierProvider<WalletSettingsVM>(create: (_) => WalletSettingsVM()),
    ChangeNotifierProvider<WalletCreationVM>(create: (_) => WalletCreationVM()),
    ChangeNotifierProvider<AuthGateVM>(create: (_) => AuthGateVM()),
    ChangeNotifierProvider<SettingsVM>(create: (_) => SettingsVM()..initDefaults()),

    // 10) Transactions depends on Stellar
    ChangeNotifierProxyProvider<StellarWalletServices, TransactionsVM>(
      create: (ctx) => TransactionsVM(stellarSvc: ctx.read<StellarWalletServices>()),
      update: (ctx, stellar, prev) => prev ?? TransactionsVM(stellarSvc: stellar),
    ),

    // 11) Send depends on Stellar + SeedKeypair
    ChangeNotifierProxyProvider2<StellarWalletServices, SeedKeypairVM, SendVM>(
      create: (ctx) => SendVM(
        service: ctx.read<StellarWalletServices>(),
        seedVM: ctx.read<SeedKeypairVM>(),
      ),
      update: (ctx, stellar, seedVM, prev) => prev ?? SendVM(service: stellar, seedVM: seedVM),
    ),

    // 12) Seed phrase depends on Stellar
    ChangeNotifierProxyProvider<StellarWalletServices, SeedPhraseVM>(
      create: (ctx) => SeedPhraseVM(service: ctx.read<StellarWalletServices>()),
      update: (ctx, stellar, vm) => vm ?? SeedPhraseVM(service: stellar),
    ),

    // 13) Swap depends on Stellar + SeedKeypair + WalletHome
    ChangeNotifierProxyProvider3<StellarWalletServices, SeedKeypairVM, WalletHomeVM, SwapVM>(
      create: (ctx) => SwapVM(
        svc: ctx.read<StellarWalletServices>(),
        keypairVM: ctx.read<SeedKeypairVM>(),
        walletHomeVM: ctx.read<WalletHomeVM>(),
      )..bindToActiveWallet(),
      update: (ctx, stellar, seedVM, walletHomeVM, existing) {
        final vm = existing ??
            SwapVM(
              svc: stellar,
              keypairVM: seedVM,
              walletHomeVM: walletHomeVM,
            );
        vm.bindToAddress(seedVM.accountId);
        return vm;
      },
    ),

    // 14) Claimable balances depends on Stellar + SeedKeypair + WalletHomeVM
    ChangeNotifierProxyProvider3<StellarWalletServices, SeedKeypairVM, WalletHomeVM, ClaimableVM>(
      create: (ctx) => ClaimableVM(
        service: ctx.read<StellarWalletServices>(),
        seedVM: ctx.read<SeedKeypairVM>(),
        walletHomeVM: ctx.read<WalletHomeVM>(),
      ),
      update: (ctx, stellar, seedVM, walletHomeVM, prev) => prev ??
          ClaimableVM(
            service: stellar,
            seedVM: seedVM,
            walletHomeVM: walletHomeVM,
          ),
    ),
  ];
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _bindFcm();
  }

  Future<void> _bindFcm() async {
    // ✅ Initialize local notifications for foreground display
    await LocalNotif.I.init(
      onLocalTap: (payload) {
        if (payload != null && payload.isNotEmpty) {
          debugPrint('[LOCAL_NOTIF] Navigate to: $payload');
          // Navigator.of(context).pushNamed(payload);
        }
      },
    );

    // ✅ Get device meta and token
    final token = await FcmBootstrap.getToken();
    final deviceMeta = await DeviceMetaService.instance.getMeta();

    debugPrint('[FCM] token=$token');
    debugPrint(
      '[FCM] deviceId=${deviceMeta.deviceId} platform=${deviceMeta.platform} appVersion=${deviceMeta.appVersion}',
    );

    // ✅ Register token with backend
    if (token != null) {
      try {
        await FcmNotificationCore().upsertDeviceToken(
          fcmToken: token,
          deviceId: deviceMeta.deviceId,
          platform: deviceMeta.platform,
          appVersion: deviceMeta.appVersion,
        );
      } catch (e) {
        debugPrint('[FCM] upsert skipped (likely not logged in yet): $e');
      }
    }

    // ✅ Auto update when token changes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] token refreshed=$newToken');
      try {
        await FcmNotificationCore().upsertDeviceToken(
          fcmToken: newToken,
          deviceId: deviceMeta.deviceId,
          platform: deviceMeta.platform,
          appVersion: deviceMeta.appVersion,
        );
      } catch (e) {
        debugPrint('[FCM] upsert on refresh failed (likely logged out): $e');
      }
    });

    // ✅ Use FcmBootstrap.bindListeners for clean setup
    await FcmBootstrap.bindListeners(
      onForeground: (RemoteMessage msg) async {
        debugPrint(
          '[FCM][onMessage] ${msg.notification?.title} | ${msg.notification?.body}',
        );
        debugPrint('[FCM][data] ${msg.data}');
        // Show notification in foreground using LocalNotif
        await LocalNotif.I.showFromFcm(msg);
      },
      onOpenedFromBackground: (RemoteMessage msg) {
        debugPrint('[FCM][openedApp] data=${msg.data}');
        _handlePushTap(msg);
      },
      onOpenedFromTerminated: (RemoteMessage msg) {
        debugPrint('[FCM][initialMessage] data=${msg.data}');
        _handlePushTap(msg);
      },
    );
  }

  void _handlePushTap(RemoteMessage msg) {
    final route = msg.data['route'];
    if (route is String && route.isNotEmpty) {
      debugPrint('[FCM] Navigate to: $route');
      // Navigator.of(context).pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeVN,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'NextFi Wallet',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          home: const Home(),
        );
      },
    );
  }
}

// ───────────────────────────── Themes ─────────────────────────────
final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.light.background,
  canvasColor: AppColor.light.surface,
  dialogBackgroundColor: AppColor.light.surface,
  textTheme: GoogleFonts.workSansTextTheme(),
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColor.light.primary,
    surface: AppColor.light.surface,
    brightness: Brightness.light,
  ),
);

final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.dark.background,
  canvasColor: AppColor.dark.surface,
  dialogBackgroundColor: AppColor.dark.surface,
  textTheme: GoogleFonts.workSansTextTheme(ThemeData.dark().textTheme),
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColor.dark.primary,
    surface: AppColor.dark.surface,
    brightness: Brightness.dark,
  ),
);