import 'package:flutter/material.dart' hide Page;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/AppAlert.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron_wallet_service.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final ScrollController _scrollController = ScrollController();

  String? _userAddress;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int _start = 0; // pagination offset
  final int _limit = 20;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadWalletAndData();

    // infinite scroll
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
      // Derive Tron address from mnemonic
      final priv = TronWalletService.derivePrivateKey(storedMnemonic);
      final pub = TronWalletService.publicKeyFromPrivateKey(priv);
      final address = TronWalletService.tronAddressFromPublicKey(pub);

      setState(() => _userAddress = address);

      await _fetchTransactions();
    } catch (e) {
      debugPrint("Error loading wallet: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchTransactions({bool loadMore = false}) async {
    if (_userAddress == null) return;

    setState(() {
      if (loadMore) {
        _loadingMore = true;
      } else {
        _loading = true;
        _start = 0; // reset pagination if not loadMore
      }
    });

    try {
      final newTx = await TronWalletService.getTransactionHistory(
        _userAddress!,
        limit: _limit,
        start: _start,
      );

      setState(() {
        if (loadMore) {
          _transactions.addAll(newTx);
        } else {
          _transactions = newTx;
        }

        if (newTx.isNotEmpty) {
          _start += _limit;
        }

        _hasMore = newTx.length == _limit;
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        title: const Text(
          "Transactions",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          _start = 0;
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
            final txId = tx['txID'];
            final timestamp = tx['timestamp'];
            final type = tx['type'] ?? "Unknown";
            final contract = tx['contract'] ?? {};

            // determine direction & amount
            final from = contract['owner_address'] ?? '';
            final to = contract['to_address'] ?? '';
            final rawAmount = contract['amount'] ?? 0;
            final amount = rawAmount is int
                ? rawAmount / 1e6
                : double.tryParse(rawAmount.toString()) ?? 0.0;

            final isIncoming =
                _userAddress != null && to == _userAddress;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isIncoming
                    ? colors.success.withOpacity(0.15)
                    : colors.error.withOpacity(0.15),
                child: Icon(
                  isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncoming ? colors.success : colors.error,
                ),
              ),
              title: Text(
                "${amount.toStringAsFixed(2)} TRX/USDT",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              subtitle: Text(
                "From: ${from.isNotEmpty ? from.substring(0, 6) : '???'}... • "
                    "${timestamp != null ? DateFormat('MMM d, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(timestamp)) : ''}",
                style: TextStyle(color: colors.textSecondary),
              ),
              trailing: Icon(LucideIcons.chevronRight,
                  color: colors.textSecondary),
              onTap: () {
                AppAlert.show(
                  context: context,
                  title: "Transaction Details",
                  description:
                  "TxID: $txId\n\n"
                      "Date : ${timestamp != null ? DateFormat('MMM d, yyyy • h:mm a').format(DateTime.fromMillisecondsSinceEpoch(timestamp)) : 'N/A'}\n\n"
                      "From: $from\n\n"
                      "To: $to\n\n"
                      "Amount: ${amount.toStringAsFixed(2)}\n\n"
                      "Type: $type",
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
