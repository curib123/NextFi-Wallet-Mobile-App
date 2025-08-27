import 'dart:typed_data';

import 'package:flutter/material.dart' ;
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
  // Wallet
  String? _tronAddress;
  Uint8List? _privateKey;

  // Balances
  double _trxBalance = 0.0;
  double _usdtBalance = 0.0;
  bool _hideBalance = false;
  bool _loadingBalances = true;

  // Transactions (Tron API returns events/logs, you can adapt it)
  final List<Map<String, dynamic>> _transactionHistory = [];
  bool _loadingHistory = true;
  final List<Widget> _incomingPayments = [];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  // ------------------- WALLET -------------------

  Future<void> _loadWallet() async {
    final storedMnemonic = await SeedStorage.getSeed();
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
      final trxSun = await TronWalletService.getTrxBalance(_tronAddress!);
      final usdt = await TronWalletService.getUsdtBalance(_tronAddress!);

      setState(() {
        _trxBalance = trxSun / 1e6; // convert SUN → TRX
        _usdtBalance = usdt;
      });
    } catch (e) {
      debugPrint("Error fetching balances: $e");
    } finally {
      setState(() => _loadingBalances = false);
    }
  }

  // ------------------- TRANSACTIONS -------------------

  Future<void> _fetchTransactionHistory() async {
    if (_tronAddress == null) return;
    setState(() => _loadingHistory = true);

    try {
      final history = await TronWalletService.getTransactionHistory(_tronAddress!);

      setState(() {
        _transactionHistory
          ..clear()
          ..addAll(history);

        _incomingPayments
          ..clear()
          ..addAll(
            history
                .where((tx) {
              final contract = tx['raw_data']?['contract']?[0];
              final value = contract?['parameter']?['value'] ?? {};
              final to = value['to_address'] ?? '';
              return to == _tronAddress; // only incoming
            })
                .map((tx) => incomingPaymentHint(tx, _tronAddress!)),
          );
      });
    } catch (e) {
      debugPrint("Error fetching Tron transaction history: $e");
    } finally {
      setState(() => _loadingHistory = false);
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
              itemCount: _incomingPayments.length,
              itemBuilder: (_, index) => _incomingPayments[index],
            ),
          _buildTabBar(colors),
          const SizedBox(height: 12),
    Expanded(
    child: TabBarView(
    children: [
     AssetWidget(colors: colors,),
     RecipientListWidget(colors: colors,),
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
                // Open bottom modal to choose TRX or USDT dynamically
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
                // TODO: Deposit action
                print("Deposit clicked");
              },
            ),
            actionButton(
              colors,
              Icons.arrow_upward,
              'Withdraw',
              gradient: true,
              onTap: () {
                // TODO: Withdraw action
                print("Withdraw clicked");
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
              // TODO: Add send TRX/USDT action
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
