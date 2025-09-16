// ────────────────── Flutter SDK ──────────────────
import 'package:flutter/material.dart';

// ───────────────── 3rd-party pkgs ────────────────
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// ─────────────────── App modules ─────────────────
import 'package:next_fi/app/home.dart';
import 'package:next_fi/Helper/AppColor.dart';

// Services
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

// View models
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';
import 'package:next_fi/features/auth_gate/view_model/auth_gate_vm.dart';
import 'package:next_fi/features/import_wallet/view_model/import_wallet_vm.dart';
import 'package:next_fi/features/price_chart/view_model/price_chart_vm.dart';
import 'package:next_fi/features/settings/view_model/settings_vm.dart';
import 'package:next_fi/features/wallet_creation/view_model/wallet_creation_vm.dart';
import 'package:next_fi/features/wallet_settings/view_model/wallet_settings_vm.dart';
import 'package:next_fi/features/seed_phrases/view_model/seed_phrase_vm.dart';
import 'package:next_fi/features/send/view_model/send_vm.dart';
import 'package:next_fi/features/swap/view_model/swap_vm.dart';
import 'package:next_fi/features/transactions/view_model/transactions_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  // Toggle here if you run testnet builds
  const bool kIsTestnet = false;

  // Safe defaults so we can boot the service before AssetVM exists.
  const _DEFAULT_USDC_MAINNET = 'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';
  const _DEFAULT_USDC_TESTNET = 'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';

  return [
    // ── 1) Boot a temporary Stellar service (will be replaced below) ─────────
    Provider<StellarWalletService>(
      create: (_) => StellarWalletService(
       usdcIssuer: kIsTestnet ? _DEFAULT_USDC_TESTNET : _DEFAULT_USDC_MAINNET,
        testnet: kIsTestnet,
      ),
    ),

    // ── 2) Currency depends on Stellar service ──────────────────────────────
    ChangeNotifierProxyProvider<StellarWalletService, CurrencyVM>(
      create: (ctx) => CurrencyVM(stellar: ctx.read<StellarWalletService>()),
      update: (ctx, stellar, prev) =>
      prev ?? CurrencyVM(stellar: stellar),
    ),

    // ── 3) AssetVM depends on Currency; holds the authoritative USDC issuer ─
    ChangeNotifierProxyProvider<CurrencyVM, AssetVM>(
      create: (ctx) => AssetVM(ctx.read<CurrencyVM>(), isTestnet: kIsTestnet),
      update: (ctx, currency, previous) =>
      previous ?? AssetVM(currency, isTestnet: kIsTestnet),
    ),

    // ── 4) Replace Stellar service once AssetVM is ready (reads issuer from VM)
    // Any consumer of StellarWalletService below will get the refreshed instance.
    ProxyProvider<AssetVM, StellarWalletService>(
      update: (ctx, assetVM, old) {
        final issuer = assetVM.usdcIssuer;
        // Recreate service if issuer/network differs from the current one
        if (old == null || old.usdcIssuer != issuer || old.isTestnet != kIsTestnet) {
          return StellarWalletService(
            usdcIssuer: issuer,
            testnet: kIsTestnet,
          );
        }
        return old;
      },
    ),

    // ── 5) PriceChart depends on Currency ───────────────────────────────────
    ChangeNotifierProxyProvider<CurrencyVM, PriceChartVM>(
      create: (ctx) => PriceChartVM(ctx.read<CurrencyVM>()),
      update: (ctx, currency, previous) =>
      previous ?? PriceChartVM(currency),
    ),

    // ── Base VMs (no cross-VM deps) ─────────────────────────────────────────
    ChangeNotifierProvider<SeedPhraseVM>(create: (_) => SeedPhraseVM()),
    ChangeNotifierProvider<ImportWalletVM>(create: (_) => ImportWalletVM()),
    ChangeNotifierProvider<RecipientAddressVM>(create: (_) => RecipientAddressVM()),
    ChangeNotifierProvider<TabVM>(create: (_) => TabVM()),
    ChangeNotifierProvider<WalletSettingsVM>(create: (_) => WalletSettingsVM()),
    ChangeNotifierProvider<WalletCreationVM>(create: (_) => WalletCreationVM()),
    ChangeNotifierProvider<AuthGateVM>(create: (_) => AuthGateVM()),
    ChangeNotifierProvider<SettingsVM>(create: (_) => SettingsVM()..initDefaults()),

    // ── Transactions / Send depend on Stellar service ───────────────────────

    ChangeNotifierProvider<WalletHomeVM>(create: (ctx) => WalletHomeVM(stellar: ctx.read<StellarWalletService>())),
    ChangeNotifierProxyProvider<StellarWalletService, TransactionsVM>(
      create: (ctx) => TransactionsVM(stellarSvc: ctx.read<StellarWalletService>()),
      update: (ctx, stellar, prev) =>
      prev ?? TransactionsVM(stellarSvc: stellar),
    ),
    ChangeNotifierProxyProvider<StellarWalletService, SendVM>(
      create: (ctx) => SendVM(service: ctx.read<StellarWalletService>()),
      update: (ctx, stellar, prev) =>
      prev ?? SendVM(service: stellar),
    ),

    // ── Swap depends on Stellar service (+ binds to WalletHome for address) ─
    ChangeNotifierProxyProvider2<StellarWalletService, WalletHomeVM, SwapVM>(
      create: (ctx) => SwapVM(svc: ctx.read<StellarWalletService>()),
      update: (ctx, stellar, walletVM, swapVM) {
        final vm = swapVM ?? SwapVM(svc: stellar);
        vm.bindToAddress(walletVM.state.address);
        return vm;
      },
    ),
  ];
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextFi Wallet',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      home: const Home(),
    );
  }
}

// ─────────────────────────── THEMES ───────────────────────────
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
