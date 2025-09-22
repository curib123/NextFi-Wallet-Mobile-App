// ───────────────────────── Flutter SDK ─────────────────────────
import 'package:flutter/material.dart';

// ───────────────────── 3rd-party packages ─────────────────────
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:next_fi/features/seed_phrases/view_model/seed_phrase_vm.dart';
import 'package:next_fi/features/send/view_model/send_vm.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// ─────────────────────────── App core ─────────────────────────
import 'package:next_fi/app/home.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

// ─────────────────────────── Services ─────────────────────────
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

// ───────────────────────── View Models ────────────────────────
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';

import 'package:next_fi/features/auth_gate/view_model/auth_gate_vm.dart';
import 'package:next_fi/features/import_wallet/view_model/import_wallet_vm.dart';
import 'package:next_fi/features/price_chart/view_model/price_chart_vm.dart';
import 'package:next_fi/features/settings/view_model/settings_vm.dart';
import 'package:next_fi/features/transactions/view_model/transactions_vm.dart';
import 'package:next_fi/features/wallet_creation/view_model/wallet_creation_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:next_fi/features/wallet_settings/view_model/wallet_settings_vm.dart';
import 'package:next_fi/features/swap/view_model/swap_vm.dart';

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
  const String _defaultUsdcMainnet =
      'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';
  const String _defaultUsdcTestnet =
      'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';

  return [
    // 1) Boot an initial Stellar service (replaced later once AssetVM provides issuer)
    Provider<StellarWalletServices>(
      create: (_) => StellarWalletServices(
        usdcIssuer: kIsTestnet ? _defaultUsdcTestnet : _defaultUsdcMainnet,
        testnet: kIsTestnet,
      ),
    ),

    // 2) Seed keypair VM (derives/holds active account id)
    ChangeNotifierProvider(
      create: (_) => SeedKeypairVM()..init(),
    ),

    // 3) Currency depends on Stellar service
    ChangeNotifierProxyProvider<StellarWalletServices, CurrencyVM>(
      create: (ctx) => CurrencyVM(stellar: ctx.read<StellarWalletServices>()),
      update: (ctx, stellar, prev) => prev ?? CurrencyVM(stellar: stellar),
    ),

    // 4) AssetVM depends on Currency; holds authoritative USDC issuer
    ChangeNotifierProxyProvider<CurrencyVM, AssetVM>(
      create: (ctx) => AssetVM(ctx.read<CurrencyVM>(), isTestnet: kIsTestnet),
      update: (ctx, currency, prev) =>
      prev ?? AssetVM(currency, isTestnet: kIsTestnet),
    ),

    // 5) Replace Stellar service when AssetVM is ready (issuer/network aware)
    ProxyProvider<AssetVM, StellarWalletServices>(
      update: (ctx, assetVM, old) {
        final issuer = assetVM.usdcIssuer;
        if (old == null ||
            old.usdcIssuer != issuer ||
            old.isTestnet != kIsTestnet) {
          return StellarWalletServices(
            usdcIssuer: issuer,
            testnet: kIsTestnet,
          );
        }
        return old;
      },
    ),

// ✅ 6) WalletHome depends on Stellar + SeedKeypair (auto-binds address)
    ChangeNotifierProxyProvider2<StellarWalletServices, SeedKeypairVM, WalletHomeVM>(
      create: (ctx) => WalletHomeVM(
        stellar: ctx.read<StellarWalletServices>(),
        seedVM: ctx.read<SeedKeypairVM>(),
      )..bindToAddress(ctx.read<SeedKeypairVM>().accountId),
      update: (ctx, stellar, seedVM, existing) {
        final vm = existing ?? WalletHomeVM(stellar: stellar, seedVM: seedVM);
        vm.bindToAddress(seedVM.accountId); // keep bound after rebuilds / wallet switch
        return vm;
      },
    ),


    // 7) Price chart depends on Currency
    ChangeNotifierProxyProvider<CurrencyVM, PriceChartVM>(
      create: (ctx) => PriceChartVM(ctx.read<CurrencyVM>()),
      update: (ctx, currency, prev) => prev ?? PriceChartVM(currency),
    ),

    // 8) Base VMs (independent)
    ChangeNotifierProvider<ImportWalletVM>(create: (_) => ImportWalletVM()),
    ChangeNotifierProvider<RecipientAddressVM>(
        create: (_) => RecipientAddressVM()),
    ChangeNotifierProvider<TabVM>(create: (_) => TabVM()),
    ChangeNotifierProvider<WalletSettingsVM>(
        create: (_) => WalletSettingsVM()),
    ChangeNotifierProvider<WalletCreationVM>(
        create: (_) => WalletCreationVM()),
    ChangeNotifierProvider<AuthGateVM>(create: (_) => AuthGateVM()),
    ChangeNotifierProvider<SettingsVM>(
        create: (_) => SettingsVM()..initDefaults()),

    // 9) Transactions depends on Stellar
    ChangeNotifierProxyProvider<StellarWalletServices, TransactionsVM>(
      create: (ctx) => TransactionsVM(stellarSvc: ctx.read<StellarWalletServices>()),
      update: (ctx, stellar, prev) => prev ?? TransactionsVM(stellarSvc: stellar),
    ),

    // 10) Send depends on Stellar + SeedKeypair (adjust to your SendVM ctor)
    ChangeNotifierProxyProvider2<StellarWalletServices, SeedKeypairVM, SendVM>(
      create: (ctx) => SendVM(
        service: ctx.read<StellarWalletServices>(),
        seedVM: ctx.read<SeedKeypairVM>(),
      ),
      update: (ctx, stellar, seedVM, prev) =>
      prev ?? SendVM(service: stellar, seedVM: seedVM),
    ),

    // 11) Seed phrase depends on Stellar (for mnemonic gen/validate)
    ChangeNotifierProxyProvider<StellarWalletServices, SeedPhraseVM>(
      create: (ctx) => SeedPhraseVM(service: ctx.read<StellarWalletServices>()),
      update: (ctx, stellar, vm) => vm ?? SeedPhraseVM(service: stellar),
    ),

    // 12) Swap depends on Stellar + SeedKeypair
    ChangeNotifierProxyProvider2<StellarWalletServices, SeedKeypairVM, SwapVM>(
      create: (ctx) => SwapVM(
        svc: ctx.read<StellarWalletServices>(),
        keypairVM: ctx.read<SeedKeypairVM>(),
      )..bindToActiveWallet(), // bind immediately to the active wallet
      update: (ctx, stellar, seedVM, existing) {
        final vm = existing ?? SwapVM(svc: stellar, keypairVM: seedVM);
        // keep VM bound after rebuilds/hot reload or when SeedKeypairVM changes
        vm.bindToAddress(seedVM.accountId);
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
