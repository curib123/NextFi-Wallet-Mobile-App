import 'package:flutter/material.dart' hide Page;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar_wallet_services.dart';
import 'WalletHomeScreenWidgets/action_button.dart';
import 'WalletHomeScreenWidgets/build_transaction_history.dart';
import 'WalletHomeScreenWidgets/floating_circle_button.dart';
import 'WalletHomeScreenWidgets/incoming_payment_hints.dart';
import 'WalletHomeScreenWidgets/recipient_list.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  // Wallet & Balances
  String? _userAccountId;
  double _xlmBalance = 0.0;
  bool _hideBalance = false;
  bool _loadingBalances = true;

  // Transactions
  List<PaymentOperationResponse> _transactionHistory = [];
  bool _loadingHistory = true;
  final List<Widget> _incomingPayments = [];

  // Services
  final StellarWalletService walletService = StellarWalletService();

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
      final wallet = await Wallet.from(storedMnemonic);
      final keyPair = await wallet.getKeyPair(index: 0);

      setState(() => _userAccountId = keyPair.accountId);

      await _fetchBalance();
      await _fetchTransactionHistory();
    } catch (e) {
      debugPrint("Failed to load wallet: $e");
      showFloatingSnackBar(
        context,
        message: "Failed to load wallet. Please check your seed/mnemonic.",
        type: SnackBarType.error,
      );
    }
  }

  // ------------------- BALANCE -------------------

  Future<void> _fetchBalance() async {
    if (_userAccountId == null) return;
    setState(() => _loadingBalances = true);

    try {
      final balance = await walletService.getXlmBalance(_userAccountId!);
      setState(() => _xlmBalance = balance);
    } catch (e) {
      if (e.toString().contains("404")) {
        debugPrint("Account not yet activated. Setting balance to 0 XLM.");
        setState(() => _xlmBalance = 0.0);
      } else {
        debugPrint("Error fetching XLM balance: $e");
      }
    } finally {
      setState(() => _loadingBalances = false);
    }
  }

  // ------------------- TRANSACTIONS -------------------

  Future<void> _fetchTransactionHistory() async {
    if (_userAccountId == null) return;
    setState(() => _loadingHistory = true);

    try {
      final Page<OperationResponse> payments = await walletService.sdk.payments
          .forAccount(_userAccountId!)
          .order(RequestBuilderOrder.DESC)
          .execute();

      setState(() {
        _transactionHistory =
            payments.records.whereType<PaymentOperationResponse>().toList();
      });
    } catch (e) {
      debugPrint("Error fetching transaction history: $e");
    } finally {
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> incomingPayments() async {
    if (_userAccountId == null) return;

    walletService.streamPayments(_userAccountId!, (payment) {
      setState(() {
        _incomingPayments.add(incomingPaymentHint(payment));
      });
    });
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
                'Main Wallet',
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
                itemCount: _incomingPayments.length,
                itemBuilder: (_, index) => _incomingPayments[index],
              ),
          _buildTabBar(colors),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                recipientList(colors),
               buildTransactionHistory(colors, _transactionHistory),
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
            Icon(LucideIcons.dollarSign, color: colors.textPrimary, size: 23),
            const SizedBox(width: 2),
            Text(
              _hideBalance
                  ? '••••'
                  : NumberFormat("#,##0.00", "en_US")
                  .format(currency.convertXlm(_xlmBalance)),
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _hideBalance
              ? '••••'
              : "${NumberFormat("#,##0.0000", "en_US").format(_xlmBalance)} XLM",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
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
        actionButton(colors, Icons.send, 'Send', gradient: true),
        actionButton(colors, Icons.call_received, 'Receive', gradient: true),
        actionButton(colors, LucideIcons.wallet, 'Deposit', gradient: true),
        actionButton(colors, Icons.arrow_upward, 'Withdraw', gradient: true),
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
              // TODO: Add action
            },
            icon: LucideIcons.plus,
            color: colors.primary,
          ),
          const SizedBox(height: 16),
          floatingCircleButton(
            onTap: () {
              // TODO: Scan action
            },
            icon: LucideIcons.scanLine,
            color: colors.primary,
          ),
        ],
      ),
    );
  }
}
