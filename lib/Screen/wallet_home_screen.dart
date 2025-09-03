import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/token_chooser_receiver.dart';
import 'package:next_fi/Screen/WalletHomeScreenWidgets/asset_widget.dart';
import 'package:next_fi/Screen/WalletHomeScreenWidgets/recipient_list_widget.dart';
import 'package:next_fi/Screen/receive_screen.dart';
import 'package:next_fi/Screen/send_screen.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron_wallet_service.dart';

import 'WalletHomeScreenWidgets/action_button.dart';
import 'WalletHomeScreenWidgets/floating_circle_button.dart';
import 'WalletHomeScreenWidgets/incoming_payment_hints.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  // Service (NEW)
  late final TronWalletService _tron;

  // Wallet
  String? _tronAddress;
  Uint8List? _privateKey;

  // Balances
  double _trxBalance = 0.0;
  double _usdtBalance = 0.0;
  bool _hideBalance = false;
  bool _loadingBalances = true;

  // Transactions
  final List<Map<String, dynamic>> _transactionHistory = [];
  bool _loadingHistory = true;
  final List<Widget> _incomingPayments = [];

  @override
  void initState() {
    super.initState();
    // Initialize service (configure API key/baseUrl here if needed)
    _tron = TronWalletService(
      TronClientConfig(
        baseUrl: 'https://api.trongrid.io',
        // tronProApiKey: '<TRON-PRO-API-KEY>', // optional
      ),
    );
    _loadWallet();
  }

  // ------------------- WALLET -------------------

  Future<void> _loadWallet() async {
    final storedMnemonic = await SeedStorage.getSeed();
    if (!mounted) return;
    if (storedMnemonic == null || storedMnemonic.isEmpty) return;

    try {
      final privKey = TronWalletService.derivePrivateKey(storedMnemonic);
      final pubKey = TronWalletService.publicKeyFromPrivateKey(privKey);
      final address = TronWalletService.tronAddressFromPublicKey(pubKey);

      setState(() {
        _privateKey = privKey;
        _tronAddress = address;
      });

      await _fetchBalances();
      await _fetchTransactionHistory();
    } catch (e) {
      debugPrint("Failed to load Tron wallet: $e");
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: "Failed to load wallet. Please check your mnemonic.",
        type: SnackBarType.error,
      );
    }
  }

  // ------------------- BALANCE -------------------

  Future<void> _fetchBalances() async {
    if (_tronAddress == null) return;
    setState(() => _loadingBalances = true);

    try {
      // UPDATED: instance methods
      final trxSun = await _tron.getTrxBalance(_tronAddress!);
      final usdt = await _tron.getUsdtBalance(_tronAddress!);

      setState(() {
        _trxBalance = trxSun / 1e6; // SUN → TRX
        _usdtBalance = usdt;        // already decimal (6 dp)
      });
    } catch (e) {
      debugPrint("Error fetching balances: $e");
    } finally {
      if (mounted) setState(() => _loadingBalances = false);
    }
  }

  // ------------------- TRANSACTIONS -------------------

  Future<void> _fetchTransactionHistory() async {
    if (_tronAddress == null) return;
    setState(() => _loadingHistory = true);

    try {
      // UPDATED: instance method
      final history = await _tron.getTransactionHistory(_tronAddress!);

      // Robust incoming filter:
      // Our normalized tx has 'contract' = value map; raw Tron tx often uses hex 'to_address'
      final myBase58 = _tronAddress!;
      String? myHex41;
      try {
        myHex41 = TronWalletService.tronBase58ToHex(myBase58);
      } catch (_) {
        myHex41 = null;
      }

      final incoming = history.where((tx) {
        final contractVal = tx['contract'] as Map<String, dynamic>?;
        if (contractVal == null) return false;
        final to = (contractVal['to_address'] ?? contractVal['to'] ?? '').toString();
        if (to.isEmpty) return false;
        // match either base58 directly or hex(41...)
        final matchBase58 = to == myBase58;
        final matchHex = myHex41 != null && to.toUpperCase() == myHex41!.toUpperCase();
        return matchBase58 || matchHex;
      });

      setState(() {
        _transactionHistory
          ..clear()
          ..addAll(history);

        _incomingPayments
          ..clear()
          ..addAll(incoming.map((tx) => incomingPaymentHint(tx, myBase58)));
      });
    } catch (e) {
      debugPrint("Error fetching Tron transaction history: $e");
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = Provider.of<CurrencyProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: _buildAppBar(colors),
        body: Stack(
          children: [
            _buildMainContent(colors, currency),
            _buildFloatingButtons(colors),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor colors) {
    return AppBar(
      elevation: 0,
      backgroundColor: colors.surface,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(LucideIcons.fileText, color: colors.textPrimary, size: 28),
            onPressed: () {},
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Tron Wallet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(width: 4),
              Icon(LucideIcons.chevronDown, size: 20),
            ],
          ),
          IconButton(
            icon: Icon(LucideIcons.settings, color: colors.textPrimary, size: 28),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(AppColor colors, CurrencyProvider currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        children: [
          _buildBalanceCard(colors, currency),
          const SizedBox(height: 24),
          _buildActionButtons(colors),
          const SizedBox(height: 20),
          if (_incomingPayments.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _incomingPayments.length,
              itemBuilder: (_, index) => _incomingPayments[index],
            ),
          _buildTabBar(colors),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                AssetWidget(colors: colors),
                RecipientListWidget(colors: colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(AppColor colors, CurrencyProvider currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBalanceInfo(colors, currency),
          _buildSwapButton(colors),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo(AppColor colors, CurrencyProvider currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Total Balance',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _hideBalance = !_hideBalance),
              child: Icon(
                _hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                color: colors.textSecondary,
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              _hideBalance
                  ? '••••'
                  : NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase()).format(
                (currency.fiatToTrx(_trxBalance) + currency.fiatToUsdt(_usdtBalance)),
              ),
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSwapButton(AppColor colors) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        elevation: 3,
      ),
      onPressed: () {},
      child: Row(
        children: const [
          Icon(LucideIcons.shuffle, size: 22, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Swap',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppColor colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            actionButton(
              colors,
              Icons.send,
              'Send',
              gradient: true,
              onTap: () {
                if (_tronAddress == null) {
                  showFloatingSnackBar(context, message: "Wallet not loaded yet", type: SnackBarType.warning);
                  return;
                }
                showTokenSelector(
                  context,
                  _tronAddress!,
                  _trxBalance,
                  _usdtBalance,
                  title: "Send Token",
                  screenBuilder: (address, token, balance) => SendScreen(
                    address: address,
                    token: token,
                    balance: balance,
                  ),
                );
              },
            ),
            actionButton(
              colors,
              Icons.call_received,
              'Receive',
              gradient: true,
              onTap: () {
                if (_tronAddress == null) {
                  showFloatingSnackBar(context, message: "Wallet not loaded yet", type: SnackBarType.warning);
                  return;
                }
                showTokenSelector(
                  context,
                  _tronAddress!,
                  _trxBalance,
                  _usdtBalance,
                  title: "Receive Token",
                  screenBuilder: (address, token, balance) => ReceiveScreen(
                    address: address,
                    token: token,
                    balance: balance,
                  ),
                );
              },
            ),
            actionButton(
              colors,
              LucideIcons.wallet,
              'Deposit',
              gradient: true,
              onTap: () {
                debugPrint("Deposit clicked");
              },
            ),
            actionButton(
              colors,
              Icons.arrow_upward,
              'Withdraw',
              gradient: true,
              onTap: () {
                debugPrint("Withdraw clicked");
              },
            ),
          ],
        )
      ],
    );
  }

  Widget _buildTabBar(AppColor colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        labelColor: colors.primary,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'Assets & Holdings'),
          Tab(text: 'Recipient Address'),
        ],
      ),
    );
  }

  Widget _buildFloatingButtons(AppColor colors) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          floatingCircleButton(
            onTap: () {
              if (_tronAddress == null) {
                showFloatingSnackBar(context, message: "Wallet not loaded yet", type: SnackBarType.warning);
                return;
              }
              // Optionally open Send screen directly
            },
            icon: LucideIcons.plus,
            color: colors.primary,
          ),
          const SizedBox(height: 16),
          floatingCircleButton(
            onTap: () {
              // TODO: Add QR scan
            },
            icon: LucideIcons.scanLine,
            color: colors.primary,
          ),
        ],
      ),
    );
  }
}
