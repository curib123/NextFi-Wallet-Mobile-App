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
import 'package:next_fi/features/ViewModel/asset_vm.dart';
import 'package:next_fi/features/ViewModel/currency_vm.dart';
import 'package:next_fi/features/ViewModel/tab_vm.dart';
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

List<SingleChildWidget> _buildProviders() => [
  // ── Core service singletons ──────────────────────────────────────────
  Provider<StellarWalletService>(
    create: (_) => StellarWalletService(testnet: false),
  ),

  // ── Base VMs (no cross-VM deps) ─────────────────────────────────────
  ChangeNotifierProvider<SeedPhraseVM>(create: (_) => SeedPhraseVM()),
  ChangeNotifierProvider<ImportWalletVM>(create: (_) => ImportWalletVM()),
  ChangeNotifierProvider<RecipientAddressVM>(create: (_) => RecipientAddressVM()),
  ChangeNotifierProvider<TabVM>(create: (_) => TabVM()),
  ChangeNotifierProvider<WalletHomeVM>(create: (_) => WalletHomeVM()),
  ChangeNotifierProvider<WalletSettingsVM>(create: (_) => WalletSettingsVM()),
  ChangeNotifierProvider<WalletCreationVM>(create: (_) => WalletCreationVM()),
  ChangeNotifierProvider<AuthGateVM>(create: (_) => AuthGateVM()),
  ChangeNotifierProvider<SettingsVM>(create: (_) => SettingsVM()..initDefaults()),

  // ── Currency → Asset (Asset depends on Currency) ────────────────────
  ChangeNotifierProvider<CurrencyVM>(
    create: (ctx) => CurrencyVM(stellar: ctx.read<StellarWalletService>()),
  ),
  ChangeNotifierProxyProvider<CurrencyVM, AssetVM>(
    create: (ctx) => AssetVM(ctx.read<CurrencyVM>()),
    update: (ctx, currency, previous) => previous ?? AssetVM(currency),
  ),

  // ── PriceChart depends on Currency ──────────────────────────────────
  ChangeNotifierProxyProvider<CurrencyVM, PriceChartVM>(
    create: (ctx) => PriceChartVM(ctx.read<CurrencyVM>()),
    update: (ctx, currency, previous) => previous ?? PriceChartVM(currency),
  ),

  // ── Swap depends on WalletHome (address) + Stellar service ─────────
  ChangeNotifierProxyProvider<WalletHomeVM, SwapVM>(
    create: (ctx) => SwapVM(svc: ctx.read<StellarWalletService>()),
    update: (ctx, walletVM, swapVM) {
      final vm = swapVM ?? SwapVM(svc: ctx.read<StellarWalletService>());
      vm.bindToAddress(walletVM.state.address);
      return vm;
    },
  ),

  // ── Transactions / Send depend on Stellar service ───────────────────
  ChangeNotifierProvider<TransactionsVM>(
    create: (ctx) => TransactionsVM(stellarSvc: ctx.read<StellarWalletService>()),
  ),
  ChangeNotifierProvider<SendVM>(
    create: (ctx) => SendVM(service: ctx.read<StellarWalletService>()),
  ),
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
