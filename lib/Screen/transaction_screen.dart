import 'dart:async';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Components/AppAlert.dart'; // kept for incoming toast
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

  StreamSubscription<Map<String, dynamic>>? _incomingSub;

  @override
  void initState() {
    super.initState();
    _tron = TronWalletService(
      TronClientConfig(),
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
    _incomingSub?.cancel();
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

      // watch for incoming (append at top + small toast)
      _incomingSub = _tron
          .watchIncoming(_userAddress!, interval: const Duration(seconds: 12))
          .listen(_handleIncomingTx, onError: (_) {});
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Failed to load wallet: $e';
      });
    }
  }

  void _handleIncomingTx(Map<String, dynamic> tx) {
    if (!mounted) return;

    final id = (tx['id'] ?? '').toString();
    final already = _transactions.any((t) => (t['id'] ?? '').toString() == id);
    if (!already) {
      setState(() {
        _transactions.insert(0, tx);
      });

      final asset = (tx['asset'] ?? 'TRX').toString();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      AppAlert.show(
        context: context,
        title: "Incoming $asset",
        description:
        "You received ${amount.toStringAsFixed(6)} $asset.\nTap to view the transaction details.",
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
              onTap: () => _showTxDetailsBottomSheet(context, colors, tx),
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

  // ───────────────────────────────────────────────────────────────────────────
  // Modal sheet for full transaction details (replaces alert)
  // ───────────────────────────────────────────────────────────────────────────
  void _showTxDetailsBottomSheet(
      BuildContext context,
      AppColor colors,
      Map<String, dynamic> tx,
      ) {
    final txId = (tx['id'] ?? '').toString();
    final ts = (tx['timestamp'] as num?)?.toInt();
    final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

    final asset = (tx['asset'] ?? 'TRX').toString();
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final from = (tx['from'] ?? '').toString();
    final to = (tx['to'] ?? '').toString();
    final direction = (tx['direction'] ?? 'other').toString();
    final isIncoming = direction == 'in';

    final explorerUrl = txId.isNotEmpty
        ? 'https://tronscan.org/#/transaction/$txId'
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.95,
          initialChildSize: 0.55,
          minChildSize: 0.40,
          builder: (context, scroll) {
            return SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // grabber
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // title row + direction chip
                  Row(
                    children: [
                      Icon(
                        isIncoming ? LucideIcons.arrowDownCircle : LucideIcons.arrowUpCircle,
                        color: isIncoming ? colors.success : colors.error,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Transaction Details",
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isIncoming ? colors.success : colors.error).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: (isIncoming ? colors.success : colors.error).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          isIncoming ? "IN" : "OUT",
                          style: TextStyle(
                            color: isIncoming ? colors.success : colors.error,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // amount big
                  Text(
                    "${amount.toStringAsFixed(6)} $asset",
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // date/time
                  Row(
                    children: [
                      Icon(LucideIcons.calendarClock, size: 16, color: colors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        dt != null
                            ? DateFormat('MMM d, yyyy • h:mm a').format(dt)
                            : 'Unknown date',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(height: 1),

                  const SizedBox(height: 12),

                  // From
                  _kv(
                    colors: colors,
                    label: "From",
                    value: from,
                    mono: true,
                    copyable: true,
                  ),
                  const SizedBox(height: 8),

                  // To
                  _kv(
                    colors: colors,
                    label: "To",
                    value: to,
                    mono: true,
                    copyable: true,
                  ),
                  const SizedBox(height: 8),

                  // TxID
                  _kv(
                    colors: colors,
                    label: "TxID",
                    value: txId,
                    mono: true,
                    copyable: true,
                  ),

                  const SizedBox(height: 16),

                  // actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (txId.isEmpty) return;
                            await Clipboard.setData(ClipboardData(text: txId));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('TxID copied')),
                            );
                          },
                          icon: Icon(LucideIcons.copy, size: 18, color: colors.primary),
                          label: Text(
                            "Copy TxID",
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.primary.withOpacity(0.35)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: explorerUrl == null
                              ? null
                              : () async {
                            // Let the caller open externally; you can
                            // integrate url_launcher if you use it app-wide.
                            // For now, just copy the link:
                            await Clipboard.setData(ClipboardData(text: explorerUrl));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Explorer link copied')),
                            );
                          },
                          icon: const Icon(LucideIcons.externalLink, size: 18, color: Colors.white),
                          label: const Text("Explorer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: const Text("Done"),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// small inline key/value row
Widget _kv({
  required AppColor colors,
  required String label,
  required String value,
  bool mono = false,
  bool copyable = false,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 70,
        child: Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SelectableText(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: mono ? 'monospace' : null,
            fontSize: 13.5,
          ),
        ),
      ),
      if (copyable && value.isNotEmpty)
        IconButton(
          splashRadius: 18,
          icon: Icon(LucideIcons.copy, size: 16, color: colors.textSecondary),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            // ignore: use_build_context_synchronously

          }
        ),
    ],
  );
}
