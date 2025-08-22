import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Screen/WalletHomeScreen/wallet_home_widget.dart';
import 'package:next_fi/Services/coingecko_services.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron_wallet_services.dart';
import 'package:provider/provider.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  bool _hideBalance = false;
  double _usdtBalance = 0.0;
  double _trxBalance = 0.0;
  bool _loadingBalances = true;

  String? _trxImageUrl;
  String? _tetherImageUrl;

  String? _userAddress;

  @override
  void initState() {
    super.initState();
    _loadWalletAddress();
    _fetchTrxImage();
    _fetchTetherImage();
  }

  Future<void> _loadWalletAddress() async {
    final storedMnemonic = await SeedStorage.getSeed();
    if (storedMnemonic != null && storedMnemonic.isNotEmpty) {
      try {
        // Derive private key
        final privKey = TronWalletService.derivePrivateKey(storedMnemonic);

        // Derive public key
        final pubKey = TronWalletService.publicKeyFromPrivateKey(privKey);

        // Get Tron address
        final address = TronWalletService.tronAddressFromPublicKey(pubKey);

        setState(() {
          _userAddress = address; // update the state variable
        });

        // Optionally fetch balances after getting address
        await _fetchBalances();
      } catch (e) {
        debugPrint('Error deriving wallet: $e');
        showFloatingSnackBar(
          context,
          message: "Failed to derive wallet. Please try again.",
          type: SnackBarType.error,
        );
      }
    } else {
      showFloatingSnackBar(
        context,
        message: "No stored wallet found. Please create or import one.",
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _fetchTrxImage() async {
    final imageUrl = await CoinGeckoService.getTrxImage();
    if (mounted) {
      setState(() => _trxImageUrl = imageUrl);
    }
  }

  Future<void> _fetchTetherImage() async {
    final imageUrl = await CoinGeckoService.getUsdtImage();
    if (mounted) {
      setState(() => _tetherImageUrl = imageUrl);
    }
  }
  Future<void> _fetchBalances() async {
    if (_userAddress == null) return; // do nothing if address not ready
    setState(() => _loadingBalances = true);
    try {
      final trxSun = await TronWalletService.getTrxBalance(_userAddress!);
      final usdt = await TronWalletService.getUsdtBalance(_userAddress!);

      setState(() {
        _trxBalance = trxSun / 1e6; // convert SUN to TRX
        _usdtBalance = usdt;
      });
    } catch (e) {
      debugPrint("Error fetching balances: $e");
    } finally {
      setState(() => _loadingBalances = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final AppColor colors = AppColor.of(context);
    final currency = Provider.of<CurrencyProvider>(context);

    // Total balance in USDT including TRX converted to USDT (optional)
    final double totalBalance = _usdtBalance; // primary token
    final double trxAsUsd = 0; // optional conversion if you want TRX -> USDT

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: colors.surface,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon:  Icon(LucideIcons.fileText, color: colors.textPrimary,size: 28,),
                onPressed: () {},
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Default Wallet',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(width: 4),
                  Icon(LucideIcons.chevronDown, size: 20),
                ],
              ),
              IconButton(
                icon:  Icon(LucideIcons.settings, color: colors.textPrimary,size: 28,),
                onPressed: () {},
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Column(
                children: [
                  // Balance Section
                  _loadingBalances
                      ? SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Primary Balance = USDT
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.dollarSign,
                              color: colors.textPrimary, size: 30),
                          const SizedBox(width: 4),
                          Text(
                            _hideBalance
                                ? '••••••'
                                : NumberFormat("#,##0.00", "en_US")
                                .format(totalBalance),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _hideBalance = !_hideBalance;
                              });
                            },
                            child: Icon(
                              _hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                              color: colors.textSecondary,
                              size: 25,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _hideBalance
                            ? '${currency.fiat.toUpperCase()} ••••'
                            : '${currency.fiat.toUpperCase()} ${NumberFormat("#,##0.00", "en_US").format(currency.convert(totalBalance))}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // TRX Balance as gas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _trxImageUrl != null
                              ? Image.network(_trxImageUrl!, width: 20, height: 20)
                              : Icon(LucideIcons.triangle, color: colors.primary, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            "TRX ${NumberFormat("#,##0.0000", "en_US").format(_trxBalance)} (for gas fees)",
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      actionButton(colors, Icons.send, 'Send'),
                      actionButton(colors, Icons.call_received, 'Receive'),
                      actionButton(colors, Icons.account_balance_wallet, 'Deposit'),
                      actionButton(colors, Icons.arrow_upward, 'Withdraw'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // TabBar
                  TabBar(
                    indicatorColor: colors.textPrimary,
                    dividerColor: Colors.transparent,
                    indicatorWeight: 2,
                    labelColor: colors.textPrimary,
                    unselectedLabelColor: colors.textSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    tabs: const [
                      Tab(text: 'Recipient Address'),
                      Tab(text: 'Chain Network'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        recipientList(colors),
                        _userAddress == null
                            ? const Center(child: CircularProgressIndicator())
                            : chainListView(colors,_userAddress!)

                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Floating Scan Button with Label
            Positioned(
              bottom: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label/Icon Above FAB
                  const Text(
                    "Scan",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Floating Button
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.scanLine,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Two Floating Buttons
            Positioned(
              bottom: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 2nd Floating Button (new icon)
                  GestureDetector(
                    onTap: () {
                      // Action for the 2nd button
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.plus, // 👈 replace with any icon you like
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),

                  // Main Scan Floating Button
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.scanLine,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}
