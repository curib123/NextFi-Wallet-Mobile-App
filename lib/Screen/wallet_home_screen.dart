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
import 'package:shimmer/shimmer.dart';

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
      final balance =
      await StellarWalletService(profitAddress: "").getXlmBalance(_userAccountId!);
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
        _transactionHistory =
            payments.records.whereType<PaymentOperationResponse>().toList();
      });
    } catch (e) {
      debugPrint("Error fetching transaction history: $e");
    } finally {
      setState(() => _loadingHistory = false);
    }
  }

  Widget _buildBalanceShimmer(AppColor colors) {
    return Shimmer.fromColors(
      baseColor: colors.surface.withOpacity(0.5),
      highlightColor: colors.surface.withOpacity(0.2),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildHistoryShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
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
                  Text('Default Wallet',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            children: [
              // Balance Section
              _loadingBalances
                  ? _buildBalanceShimmer(colors)
                  : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Total Balance',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _hideBalance = !_hideBalance),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.dollarSign,
                                color: colors.textPrimary, size: 23),
                            const SizedBox(width: 8),
                            Text(
                              _hideBalance
                                  ? '••••••'
                                  : NumberFormat("#,##0.00", "en_US")
                                  .format(currency.convertXlm(_xlmBalance)),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hideBalance
                              ? '••••••'
                              : "${NumberFormat("#,##0.0000", "en_US").format(_xlmBalance)} XLM",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        elevation: 6,
                      ),
                      onPressed: () {},
                      child: Row(
                        children: const [
                          Icon(LucideIcons.shuffle, size: 22, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Swap',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  actionButton(colors, Icons.send, 'Send', gradient: true),
                  actionButton(colors, Icons.call_received, 'Receive', gradient: true),
                  actionButton(colors, LucideIcons.wallet, 'Deposit', gradient: true),
                  actionButton(colors, Icons.arrow_upward, 'Withdraw', gradient: true),
                ],
              ),
              const SizedBox(height: 20),
              Container(
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
                    Tab(text: 'Recipient Address'),
                    Tab(text: 'Transaction History'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    recipientList(colors),
                    _loadingHistory
                        ? _buildHistoryShimmer()
                        : buildTransactionHistory(colors, _transactionHistory),
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
