import 'package:flutter/material.dart' hide Page;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar_wallet_services.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'WalletHomeScreen/wallet_home_widget.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  bool _hideBalance = false;
  double _xlmBalance = 0.0;
  bool _loadingBalances = true;

  String? _userSecretSeed;
  String? _userAccountId;

  List<PaymentOperationResponse> _transactionHistory = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final storedMnemonic = await SeedStorage.getSeed();
    if (storedMnemonic == null || storedMnemonic.isEmpty) return;

    try {
      final wallet = await Wallet.from(storedMnemonic);
      final keyPair = await wallet.getKeyPair(index: 0);

      setState(() {
        _userAccountId = keyPair.accountId;
        _userSecretSeed = keyPair.secretSeed;
      });

      // Fetch balance and history after wallet load
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

  Future<void> _fetchBalance() async {
    if (_userAccountId == null) return;
    setState(() => _loadingBalances = true);

    try {
      final balance = await StellarWalletService(profitAddress: "").getXlmBalance(_userAccountId!);
      setState(() => _xlmBalance = balance);
    } catch (e) {
      // Handle unactivated account (404 error)
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


  Future<void> _fetchTransactionHistory() async {
    if (_userAccountId == null) return;
    setState(() => _loadingHistory = true);

    try {
      final walletService = StellarWalletService(profitAddress: "");
      final Page<OperationResponse> payments = await walletService.sdk.payments
          .forAccount(_userAccountId!)
          .order(RequestBuilderOrder.DESC)
          .execute();

      setState(() {
        _transactionHistory = payments.records
            .whereType<PaymentOperationResponse>()
            .toList();
      });
    } catch (e) {
      debugPrint("Error fetching transaction history: $e");
    } finally {
      setState(() => _loadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColor colors = AppColor.of(context);
    final currency = Provider.of<CurrencyProvider>(context);

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
                icon: Icon(LucideIcons.fileText, color: colors.textPrimary, size: 28),
                onPressed: () {},
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Default Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
        ),
        body: Padding(
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
                  // USD equivalent (top line)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.dollarSign, color: colors.textPrimary, size: 28),
                      const SizedBox(width: 6),
                      Text(
                        _hideBalance
                            ? '••••••'
                            : NumberFormat("#,##0.00", "en_US").format(currency.convertXlm(_xlmBalance)),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _hideBalance = !_hideBalance),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.surface.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                            color: colors.textSecondary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // XLM amount (bottom line)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'XLM',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hideBalance
                            ? '••••••'
                            : NumberFormat("#,##0.0000", "en_US").format(_xlmBalance),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.5),
                tabs: const [
                  Tab(text: 'Recipient Address'),
                  Tab(text: 'Transaction History'),
                ],
              ),
              const SizedBox(height: 8),

              // Tab Content
              Expanded(
                child: TabBarView(
                  children: [
                    recipientList(colors), // Your existing recipient list widget
                    _loadingHistory
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                      itemCount: _transactionHistory.length,
                      itemBuilder: (context, index) {
                        final tx = _transactionHistory[index];
                        final amount = double.parse(tx.amount);
                        final from = tx.sourceAccount;
                        final to = tx.to;

                        return ListTile(
                          leading: Icon(LucideIcons.arrowRightCircle, color: colors.primary),
                          title: Text('$amount XLM'),
                          subtitle: Text('From: $from\nTo: $to'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
