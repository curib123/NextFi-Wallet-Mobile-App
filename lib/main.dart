import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:next_fi/Provider/AssetProvider.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Provider/RecipientAddressProvider.dart';
import 'package:next_fi/Provider/SwapProvider.dart';
import 'package:next_fi/Provider/TabProvider.dart';
import 'package:next_fi/home.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:provider/provider.dart';

import 'Provider/HomeWalletProvider.dart';
import 'Provider/TransactionProvider.dart';

void main() {
  runApp(
    Phoenix(
      child:MultiProvider(
        providers: [
          ChangeNotifierProvider<CurrencyProvider>(
            create: (_) => CurrencyProvider(),
          ),
          ChangeNotifierProvider<TabProvider>(
            create: (_) => TabProvider(),
          ),
          ChangeNotifierProvider<RecipientAddressProvider>(
            create: (_) => RecipientAddressProvider(),
          ),
          ChangeNotifierProvider<SwapProvider>(
            create: (_) => SwapProvider(),
          ),
          ChangeNotifierProvider<WalletHomeProvider>(
            create: (_) => WalletHomeProvider(),
          ),
          ChangeNotifierProvider<TransactionsProvider>(
            create: (_) => TransactionsProvider(),
          ),
          ChangeNotifierProxyProvider<CurrencyProvider, AssetProvider>(
            create: (ctx) => AssetProvider(ctx.read<CurrencyProvider>()),
            update: (ctx, currency, previous) => previous ?? AssetProvider(currency),
          ),
        ],
        child: const MyApp(),
      )

    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "NextFI Wallet",

      // ✅ Light Theme
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

      // ✅ Dark Theme
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

      // ✅ Auto-switch based on system setting
      themeMode: ThemeMode.system,

      home: const Home(),
    );
  }
}
