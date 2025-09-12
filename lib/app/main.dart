// lib/main.dart
// ────────────────── Flutter SDK ──────────────────
import 'package:flutter/material.dart';

// ───────────────── 3rd-party packages ────────────
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:next_fi/features/auth_gate/view_model/auth_gate_vm.dart';
import 'package:next_fi/features/import_wallet/view_model/import_wallet_vm.dart';
import 'package:next_fi/features/settings/view_model/settings_vm.dart';
import 'package:next_fi/features/wallet_creation/view_model/wallet_creation_vm.dart';
import 'package:next_fi/features/wallet_settings/view_model/wallet_settings_vm.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// ─────────────────── App modules ─────────────────
import 'package:next_fi/app/home.dart';
import 'package:next_fi/Helper/AppColor.dart';

// Services
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

// Legacy/global providers
import 'package:next_fi/Provider/asset_vm.dart';
import 'package:next_fi/Provider/currency_vm.dart';
import 'package:next_fi/Provider/tab_vm.dart';

// Feature VMs
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

List<SingleChildWidget> _buildProviders() => [
  // ── Core services ──────────────────────────────────────────────────────
  Provider<StellarWalletService>(
    create: (_) => StellarWalletService(testnet: false),
  ),

  // ── Standalone VMs (no cross-VM ) ─────────────────────────────────
  ChangeNotifierProvider<SeedPhraseVM>(create: (_) => SeedPhraseVM()),
  ChangeNotifierProvider<ImportWalletVM>(create: (_) => ImportWalletVM()),
  ChangeNotifierProvider<RecipientAddressVM>(create: (_) => RecipientAddressVM()),
  ChangeNotifierProvider<TabProvider>(create: (_) => TabProvider()),
  ChangeNotifierProvider<WalletHomeVM>(create: (_) => WalletHomeVM()),
  ChangeNotifierProvider<WalletSettingsVM>(create: (_) => WalletSettingsVM()),
  ChangeNotifierProvider<WalletCreationVM>(create: (_) => WalletCreationVM()),
  ChangeNotifierProvider<AuthGateVM>(create: (_) => AuthGateVM()),
  ChangeNotifierProvider<SettingsVM>(create: (_) => SettingsVM()),
  ChangeNotifierProvider<SettingsVM>(create: (_) => SettingsVM()..initDefaults()),


  // ── Currency -> Asset (proxy depends on Currency) ─────────────────────
  ChangeNotifierProvider<CurrencyProvider>(
    create: (ctx) =>
        CurrencyProvider(stellar: ctx.read<StellarWalletService>()),
  ),
  ChangeNotifierProxyProvider<CurrencyProvider, AssetProvider>(
    create: (ctx) => AssetProvider(ctx.read<CurrencyProvider>()),
    update: (ctx, currency, previous) =>
    previous ?? AssetProvider(currency),
  ),

  // ── SwapVM depends on WalletHomeVM (address) + Stellar service ────────
  ChangeNotifierProxyProvider<WalletHomeVM, SwapVM>(
    create: (ctx) => SwapVM(svc: ctx.read<StellarWalletService>()),
    update: (ctx, walletVM, swapVM) {
      final vm = swapVM ?? SwapVM(svc: ctx.read<StellarWalletService>());
      vm.bindToAddress(walletVM.state.address);
      return vm;
    },
  ),

  // ── Transactions / Send (need Stellar service) ────────────────────────
  ChangeNotifierProvider<TransactionsVM>(create: (ctx) => TransactionsVM(stellarSvc: ctx.read<StellarWalletService>()),),
  ChangeNotifierProvider<SendVM>(create: (ctx) => SendVM(service: ctx.read<StellarWalletService>()),),
];

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
