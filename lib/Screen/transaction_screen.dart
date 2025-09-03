import 'dart:async'; // NEW
import 'package:flutter/material.dart' hide Page;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/AppAlert.dart';
import 'package:next_fi/Components/empty_state.dart';
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

  late final TronWalletService _tron;

  String? _userAddress;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _errorMsg;

  int _start = 0; // pagination offset
  final int _limit = 20;
  List<Map<String, dynamic>> _transactions = [];

  StreamSubscription<Map<String, dynamic>>? _incomingSub; // NEW

  @override
  void initState() {
    super.initState();
    _tron = TronWalletService(
      TronClientConfig(
        baseUrl: 'https://api.trongrid.io',
        // tronProApiKey: '<TRON-PRO-API-KEY>',
      ),
    );
    _loadWalletAndData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _hasMore) {
        _fetchTransactions(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel(); // NEW
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletAndData() async {
    final storedMnemonic = await SeedStorage.getSeed();
    if (!mounted) return;

    if (storedMnemonic == null || storedMnemonic.isEmpty) {
      setState(() {
        _loading = false;
        _errorMsg = 'No wallet found. Please import or create a wallet.';
      });
      return;
    }

    try {
      final priv = TronWalletService.derivePrivateKey(storedMnemonic);
      final pub = TronWalletService.publicKeyFromPrivateKey(priv);
      final address = TronWalletService.tronAddressFromPublicKey(pub);

      setState(() => _userAddress = address);

      await _fetchTransactions();

      // ── NEW: start watching for incoming transfers after initial load ──
      _incomingSub = _tron
          .watchIncoming(_userAddress!, interval: const Duration(seconds: 12))
          .listen(_handleIncomingTx, onError: (_) {
        // optional: quiet fail
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Failed to load wallet: $e';
      });
    }
  }

  // NEW: Handle push of a newly detected incoming transaction
  void _handleIncomingTx(Map<String, dynamic> tx) {
    if (!mounted) return;

    // insert at top if not yet in the list
    final id = (tx['id'] ?? '').toString();
    final already = _transactions.any((t) => (t['id'] ?? '').toString() == id);
    if (!already) {
      setState(() {
        _transactions.insert(0, tx);
      });

      // Sweet lightweight toast/modal
      final asset = (tx['asset'] ?? 'TRX').toString();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      AppAlert.show(
        context: context,
        title: "Incoming $asset",
        description:
        "You received ${amount.toStringAsFixed(6)} $asset.\n"
            "Tap to view the transaction details.",
        confirmText: "OK",
      );
    }
  }

  Future<void> _fetchTransactions({bool loadMore = false}) async {
    if (_userAddress == null) return;

    setState(() {
      _errorMsg = null;
      if (loadMore) {
        _loadingMore = true;
      } else {
        _loading = true;
        _start = 0;
      }
    });

    try {
      final newTx = await _tron.getUnifiedTransactions(
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
        if (newTx.isNotEmpty) _start += _limit;
        _hasMore = newTx.length == _limit;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Error fetching history: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_errorMsg != null) {
      content = Center(
        child: EmptyState.error(
          title: 'Couldn’t load transactions',
          message: _errorMsg!,
          primaryActionLabel: 'Retry',
          onPrimaryAction: () {
            _start = 0;
            _hasMore = true;
            _fetchTransactions();
          },
          context: context,
        ),
      );
    } else if (_transactions.isEmpty) {
      content = Center(
        child: EmptyState.noData(
          title: 'No transactions yet',
          message: 'When you send or receive TRX or USDT, they’ll appear here.',
          primaryActionLabel: 'Refresh',
          onPrimaryAction: () {
            _start = 0;
            _hasMore = true;
            _fetchTransactions();
          },
          context: context,
        ),
      );
    } else {
      content = RefreshIndicator(
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
            final txId = (tx['id'] ?? '').toString();
            final ts = (tx['timestamp'] as num?)?.toInt();
            final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

            final asset = (tx['asset'] ?? 'TRX').toString();
            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final from = (tx['from'] ?? '').toString();
            final to = (tx['to'] ?? '').toString();
            final direction = (tx['direction'] ?? 'other').toString();
            final isIncoming = direction == 'in';

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
                "${amount.toStringAsFixed(2)} $asset",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              subtitle: Text(
                "From: ${from.isNotEmpty ? '${from.substring(0, 6)}...' : '???'} • "
                    "${dt != null ? DateFormat('MMM d, h:mm a').format(dt) : ''}",
                style: TextStyle(color: colors.textSecondary),
              ),
              trailing: Icon(LucideIcons.chevronRight, color: colors.textSecondary),
              onTap: () {
                AppAlert.show(
                  context: context,
                  title: "Transaction Details",
                  description:
                  "TxID: $txId\n\n"
                      "Date : ${dt != null ? DateFormat('MMM d, yyyy • h:mm a').format(dt) : 'N/A'}\n\n"
                      "From: $from\n\n"
                      "To: $to\n\n"
                      "Amount: ${amount.toStringAsFixed(6)} $asset\n\n"
                      "Direction: $direction",
                  confirmText: "Close",
                );
              },
            );
          },
        ),
      );
    }

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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: content,
      ),
    );
  }
}
