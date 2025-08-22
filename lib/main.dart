import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/home.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CurrencyProvider>(
            create: (_) => CurrencyProvider()..fetchRate(),
          ),
          // Add more providers here if needed
        ],
        child: const MyApp(),
      )

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
