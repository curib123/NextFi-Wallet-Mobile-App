import 'package:flutter/material.dart' hide Page;
import 'package:intl/intl.dart';
import 'package:next_fi/Components/AppAlert.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/stellar_wallet_services.dart';
import 'package:next_fi/Services/seed_storage.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final StellarWalletService walletService = StellarWalletService();
  final ScrollController _scrollController = ScrollController();

  String? _userAccountId;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  String? _cursor; // for pagination
  List<PaymentOperationResponse> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadWalletAndData();

    // listen for infinite scroll
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _hasMore) {
        _fetchTransactions(loadMore: true);
      }
    });
  }

  Future<void> _loadWalletAndData() async {
    final storedMnemonic = await SeedStorage.getSeed();
    if (storedMnemonic == null || storedMnemonic.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final wallet = await Wallet.from(storedMnemonic);
      final keyPair = await wallet.getKeyPair(index: 0);

      setState(() => _userAccountId = keyPair.accountId);

      await _fetchTransactions();
      _listenIncoming();
    } catch (e) {
      debugPrint("Error loading wallet: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchTransactions({bool loadMore = false}) async {
    if (_userAccountId == null) return;

    setState(() {
      if (loadMore) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
    });

    try {
      var request = walletService.sdk.payments
          .forAccount(_userAccountId!)
          .order(RequestBuilderOrder.DESC)
          .limit(20);

      if (_cursor != null) {
        request = request.cursor(_cursor!);
      }

      final Page<OperationResponse> page = await request.execute();

      final newTx =
      page.records.whereType<PaymentOperationResponse>().toList();

      setState(() {
        if (loadMore) {
          _transactions.addAll(newTx);
        } else {
          _transactions = newTx;
        }

        // Update cursor for next page
        if (page.records.isNotEmpty) {
          _cursor = page.records.last.pagingToken;
        }

        // If less than limit, means no more pages
        _hasMore = newTx.length == 20;
      });
    } catch (e) {
      debugPrint("Error fetching history: $e");
    } finally {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _listenIncoming() {
    if (_userAccountId == null) return;

    walletService.streamPayments(_userAccountId!, (payment) {
      setState(() {
        _transactions.insert(0, payment); // prepend new incoming
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        title: const Text("Transactions",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          _cursor = null;
          _hasMore = true;
          await _fetchTransactions();
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _transactions.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _transactions.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final tx = _transactions[index];
            final isIncoming =
                tx.to.isNotEmpty && tx.to == _userAccountId;
            final amount = double.tryParse(tx.amount) ?? 0.0;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isIncoming
                    ? colors.success.withOpacity(0.15)
                    : colors.error.withOpacity(0.15),
                child: Icon(
                  isIncoming
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: isIncoming ? colors.success : colors.error,
                ),
              ),
              title: Text(
                "${amount.toStringAsFixed(2)} ${tx.assetCode ?? 'XLM'}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              subtitle: Text(
                "From: ${tx.from.substring(0, 6)}... • ${DateFormat('MMM d, h:mm a').format(DateTime.parse(tx.createdAt))}",
                style: TextStyle(color: colors.textSecondary),
              ),
              trailing: Icon(LucideIcons.chevronRight,
                  color: colors.textSecondary),
              onTap: () {
                AppAlert.show(
                  context: context,
                  title: "Transaction Details",
                  description:
                  "Date :  ${DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(tx.createdAt))}.\n\n"
                      "Sender: ${tx.from}\n\n"
                      "Receiver: ${tx.to}\n\n"
                      "Amount: ${double.tryParse(tx.amount)?.toStringAsFixed(2) ?? tx.amount} ${tx.assetCode ?? 'XLM'}\n\n"
                      "Status: Completed successfully on the Stellar network.",
                  confirmText: "Close",
                );
              },

            );
          },
        ),
      ),
    );
  }
}
