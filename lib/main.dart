// lib/main.dart

// ────────────────── Flutter SDK ──────────────────
import 'package:flutter/material.dart';

// ───────────────── 3rd-party pkgs ────────────────
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:next_fi/Provider/TransactionProvider.dart';
import 'package:provider/provider.dart';

// ─────────────────── App modules ─────────────────
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

import 'package:next_fi/Provider/AssetProvider.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Provider/HomeWalletProvider.dart';
import 'package:next_fi/Provider/RecipientAddressProvider.dart';
import 'package:next_fi/Provider/SendProvider.dart';
import 'package:next_fi/Provider/SwapProvider.dart';
import 'package:next_fi/Provider/TabProvider.dart';

import 'package:next_fi/home.dart';

void main() {
  runApp(
    Phoenix(
      child: MultiProvider(
        providers: [
          // Core service singleton
          Provider<StellarWalletService>(
            create: (_) => StellarWalletService(testnet: false),
          ),

          // Wallet engine (boots once and lives app-wide)
          ChangeNotifierProvider<WalletHomeProvider>(
            create: (ctx) =>
            WalletHomeProvider(stellar: ctx.read<StellarWalletService>())..boot(),
          ),

          // Currency / FX rates (depends on Stellar service)
          ChangeNotifierProvider<CurrencyProvider>(
            create: (ctx) =>
                CurrencyProvider(stellar: ctx.read<StellarWalletService>()),
          ),

          // Assets (depends on CurrencyProvider)
          ChangeNotifierProxyProvider<CurrencyProvider, AssetProvider>(
            create: (ctx) => AssetProvider(ctx.read<CurrencyProvider>()),
            update: (ctx, currency, previous) => previous ?? AssetProvider(currency),
          ),

          // Transactions (bind to active wallet)
          ChangeNotifierProxyProvider<WalletHomeProvider, TransactionsProvider>(
            create: (ctx) =>
                TransactionsProvider(stellarSvc: ctx.read<StellarWalletService>()),
            update: (ctx, home, tx) => tx!..bindToAddress(home.address),
          ),

          // Swap (bind to active wallet)
          ChangeNotifierProxyProvider<WalletHomeProvider, SwapProvider>(
            create: (ctx) => SwapProvider(svc: ctx.read<StellarWalletService>()),
            update: (ctx, home, swap) => swap!..bindToAddress(home.address),
          ),

          // Recipients / UI tabs (standalone)
          ChangeNotifierProvider<RecipientAddressProvider>(
            create: (_) => RecipientAddressProvider(),
          ),
          ChangeNotifierProvider<TabProvider>(
            create: (_) => TabProvider(),
          ),

          // Send flow provider (you can also scope this per route)
          ChangeNotifierProvider<SendProvider>(
            create: (ctx) => SendProvider(
              service: ctx.read<StellarWalletService>(),
              getActiveSeed: SeedStorage.getActiveSeed,
            ),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NextFI Wallet',

      // Light theme
      theme: ThemeData(
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
      ),

      // Dark theme
      darkTheme: ThemeData(
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
      ),

      // Follow system
      themeMode: ThemeMode.system,

      home: const Home(),
    );
  }
}
