import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Screen/WalletHomeScreen/wallet_home_widget.dart';
import 'package:provider/provider.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  bool _hideBalance = false;

  @override
  Widget build(BuildContext context) {
    final AppColor colors = AppColor.of(context);
    final double totalBalance = 1250.75;

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
              // Left Icons
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.fileText, color: Colors.blue),
                    onPressed: () {},
                  ),
                ],
              ),

              // Center Title
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Default Wallet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(width: 4),
                  Icon(LucideIcons.chevronDown, size: 20),
                ],
              ),

              // Right Icons
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.settings, color: Colors.blue),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            /// Main Content
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Column(
                children: [
                  // Balance Section
                  Consumer<CurrencyProvider>(
                    builder: (context, currency, child) {
                      final double fiatValue = currency.convert(totalBalance);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.dollarSign,
                                color: colors.textPrimary,
                                size: 30,
                              ),
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
                                  _hideBalance
                                      ? LucideIcons.eyeOff
                                      : LucideIcons.eye,
                                  color: colors.textSecondary,
                                  size: 25,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          currency.loading
                              ? const SizedBox(
                            height: 16,
                            width: 16,
                            child:
                            CircularProgressIndicator(strokeWidth: 2),
                          )
                              : Text(
                            _hideBalance
                                ? '${currency.fiat.toUpperCase()} ••••'
                                : '${currency.fiat.toUpperCase()} ${NumberFormat("#,##0.00", "en_US").format(fiatValue)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
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
                    indicatorColor: colors.primary,
                    dividerColor: Colors.transparent,
                    indicatorWeight: 2,
                    labelColor: colors.primary,
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
                        // list of addresses
                        recipientList(colors),
                        // List of network chains
                        chainListView(colors),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /// Floating Scan Button
            Positioned(
              bottom: 24,
              right: 24,
              child: GestureDetector(
                onTap: () {
                  // TODO: Scan action
                },
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.scanLine,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ]
        ),
      ),
    );
  }
}
