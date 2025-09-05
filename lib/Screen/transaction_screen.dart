import 'dart:async';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Components/AppAlert.dart';
import 'package:next_fi/Components/empty_state.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron/tron_wallet_service.dart';

import 'package:next_fi/Provider/RecipientAddressProvider.dart';
import 'package:next_fi/model/recipient_address.dart';

typedef Tx = Map<String, dynamic>;

enum _TxFilter { all, receive, send }

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

  int _start = 0;
  final int _limit = 20;
  List<Tx> _transactions = [];
  final Set<String> _seenIds = <String>{};

  StreamSubscription<Tx>? _incomingSub;
  int _fetchGen = 0;

  _TxFilter _filter = _TxFilter.all;

  static final DateFormat _listFmt = DateFormat('MMM d, h:mm a');
  static final DateFormat _detailFmt = DateFormat('MMM d, yyyy • h:mm a');

  @override
  void initState() {
    super.initState();
    _tron = TronWalletService(TronClientConfig());
    _loadWalletAndData();

    _scrollController.addListener(() {
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 200 && !_loadingMore && _hasMore) {
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

  void _set(void Function() fn) {
    if (mounted) setState(fn);
  }

  Future<void> _loadWalletAndData() async {
    final storedMnemonic = await SeedStorage.getSeed();
    if (!mounted) return;

    if (storedMnemonic == null || storedMnemonic.isEmpty) {
      _set(() {
        _loading = false;
        _errorMsg = 'No wallet found. Please import or create a wallet.';
      });
      return;
    }

    try {
      final priv = TronWalletService.derivePrivateKey(storedMnemonic);
      final pub = TronWalletService.publicKeyFromPrivateKey(priv);
      final address = TronWalletService.tronAddressFromPublicKey(pub!);

      _set(() => _userAddress = address);

      await _fetchTransactions();

      _incomingSub = _tron
          .watchIncoming(_userAddress!, interval: const Duration(seconds: 12))
          .listen(_handleIncomingTx, onError: (_) {});
    } catch (e) {
      _set(() {
        _loading = false;
        _errorMsg = 'Failed to load wallet: $e';
      });
    }
  }

  void _handleIncomingTx(Tx tx) {
    if (!mounted) return;
    final id = (tx['id'] ?? '').toString();
    if (id.isEmpty || _seenIds.contains(id)) return;

    _set(() {
      _seenIds.add(id);
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

  Future<void> _fetchTransactions({bool loadMore = false}) async {
    final addr = _userAddress;
    if (addr == null) return;

    final myToken = ++_fetchGen;

    _set(() {
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
        addr,
        limit: _limit,
        start: _start,
      );

      if (myToken != _fetchGen) return;

      _set(() {
        if (loadMore) {
          _transactions.addAll(newTx);
        } else {
          _transactions = newTx;
          _seenIds.clear();
        }
        for (final t in newTx) {
          final id = (t['id'] ?? '').toString();
          if (id.isNotEmpty) _seenIds.add(id);
        }
        if (newTx.isNotEmpty) _start += _limit;
        _hasMore = newTx.length == _limit;
      });
    } catch (e) {
      _set(() => _errorMsg = 'Error fetching history: $e');
    } finally {
      _set(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _resetAndFetch() async {
    _start = 0;
    _hasMore = true;
    await _fetchTransactions();
  }

  // ---- Filtering
  List<Tx> get _visibleTxs {
    if (_filter == _TxFilter.all) return _transactions;
    final wantIn = _filter == _TxFilter.receive;
    return _transactions
        .where((t) => (t['direction'] ?? 'other') == (wantIn ? 'in' : 'out'))
        .toList();
  }

  Widget _buildFilterChips(AppColor colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _chip(colors, label: 'All', value: _TxFilter.all),
          const SizedBox(width: 8),
          _chip(colors, label: 'Receive', value: _TxFilter.receive),
          const SizedBox(width: 8),
          _chip(colors, label: 'Send', value: _TxFilter.send),
        ],
      ),
    );
  }

  Widget _chip(AppColor colors, {required String label, required _TxFilter value}) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : colors.primary,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: colors.primary,
      backgroundColor: colors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colors.transparent : colors.primary.withOpacity(0.55),
          width: 1.2,
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    // Watch provider so tiles update when the saved address book changes.
    final recipProv = context.watch<RecipientAddressProvider>();

    final visibleTxs = _visibleTxs;
    final showLoaderRow = _loadingMore && _filter == _TxFilter.all;

    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_errorMsg != null) {
      content = Center(
        child: EmptyState.error(
          title: 'Couldn’t load transactions',
          message: _errorMsg!,
          primaryActionLabel: 'Retry',
          onPrimaryAction: _resetAndFetch,
          context: context,
        ),
      );
    } else if (_transactions.isEmpty) {
      content = Center(
        child: EmptyState.noData(
          title: 'No transactions yet',
          message: 'When you send or receive TRX or USDT, they’ll appear here.',
          primaryActionLabel: 'Refresh',
          onPrimaryAction: _resetAndFetch,
          context: context,
        ),
      );
    } else if (_transactions.isNotEmpty && visibleTxs.isEmpty) {
      content = Center(
        child: EmptyState.noData(
          title: 'No matching transactions',
          message: 'Try switching filters to All, Receive, or Send.',
          primaryActionLabel: 'Clear Filter',
          onPrimaryAction: () => setState(() => _filter = _TxFilter.all),
          context: context,
        ),
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _resetAndFetch,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: visibleTxs.length + (showLoaderRow ? 1 : 0),
          itemBuilder: (context, index) {
            if (showLoaderRow && index >= visibleTxs.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final tx = visibleTxs[index];
            return _buildTxTile(context, colors, tx, recipProv);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        title: const Text("Transactions", style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildFilterChips(colors),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: content,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // List tile builder (uses provider.byAddress to resolve name/color)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTxTile(
      BuildContext context,
      AppColor colors,
      Tx tx,
      RecipientAddressProvider recipProv,
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

    final peerAddr = (isIncoming ? from : to).trim();
    final RecipientAddress? rec = recipProv.byAddress(peerAddr);

    final titleText = rec != null
        ? "${rec.name} • ${amount.toStringAsFixed(2)} $asset"
        : "${amount.toStringAsFixed(2)} $asset";

    final subtitleWho = isIncoming ? "From" : "To";
    final subtitlePeer = rec != null ? "${rec.name} (${_short(peerAddr)})" : _short(peerAddr);

    return ListTile(
      key: ValueKey(txId.isEmpty ? 'idx:${_transactions.indexOf(tx)}' : txId),
      leading: _buildLeadingAvatar(colors: colors, isIncoming: isIncoming, rec: rec),
      title: Text(
        titleText,
        style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "$subtitleWho: $subtitlePeer • ${dt != null ? _listFmt.format(dt) : ''}",
        style: TextStyle(color: colors.textSecondary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(LucideIcons.chevronRight, color: colors.textSecondary),
      onTap: () => _showTxDetailsBottomSheet(
        context,
        colors,
        tx,
        rec: rec, // pass resolved recipient so modal can show name/color
        isIncoming: isIncoming,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Modal: transaction details (rec name/color shown when available)
  // ───────────────────────────────────────────────────────────────────────────
  void _showTxDetailsBottomSheet(
      BuildContext context,
      AppColor colors,
      Tx tx, {
        RecipientAddress? rec,
        required bool isIncoming,
      }) {
    final txId = (tx['id'] ?? '').toString();
    final ts = (tx['timestamp'] as num?)?.toInt();
    final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

    final asset = (tx['asset'] ?? 'TRX').toString();
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final from = (tx['from'] ?? '').toString();
    final to = (tx['to'] ?? '').toString();

    final explorerUrl =
    txId.isNotEmpty ? 'https://tronscan.org/#/transaction/$txId' : null;

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
                  Row(
                    children: [
                      Icon(
                        isIncoming
                            ? LucideIcons.arrowDownCircle
                            : LucideIcons.arrowUpCircle,
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
                  Text(
                    "${amount.toStringAsFixed(6)} $asset",
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (rec != null) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(rec.color).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Color(rec.color).withOpacity(0.35)),
                      ),
                      child: Text(
                        rec.name,
                        style: TextStyle(
                          color: Color(rec.color),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(LucideIcons.calendarClock, size: 16, color: colors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        dt != null ? _detailFmt.format(dt) : 'Unknown date',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _kv(
                    context: context,
                    colors: colors,
                    label: "From",
                    value: _prettyAddr(from, rec, isIncoming ? false : null),
                    mono: false,
                    copyable: true,
                  ),
                  const SizedBox(height: 8),
                  _kv(
                    context: context,
                    colors: colors,
                    label: "To",
                    value: _prettyAddr(to, rec, isIncoming ? true : null),
                    mono: false,
                    copyable: true,
                  ),
                  const SizedBox(height: 8),
                  _kv(
                    context: context,
                    colors: colors,
                    label: "TxID",
                    value: txId,
                    mono: true,
                    copyable: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: txId.isEmpty
                              ? null
                              : () async {
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

  /* ===================== Helpers ===================== */

  Widget _buildLeadingAvatar({
    required AppColor colors,
    required bool isIncoming,
    RecipientAddress? rec,
  }) {
    if (rec != null) {
      final bg = Color(rec.color);
      final initial = rec.name.trim().isNotEmpty
          ? rec.name.trim().characters.first.toUpperCase()
          : '•';
      return CircleAvatar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
      );
    }
    return CircleAvatar(
      backgroundColor: (isIncoming ? colors.success : colors.error).withOpacity(0.15),
      child: Icon(
        isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
        color: isIncoming ? colors.success : colors.error,
      ),
    );
  }

  static String _short(String addr) {
    if (addr.isEmpty) return '—';
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }

  /// If [isThisTo] == true we highlight the "to" address if it matches [rec],
  /// if false we highlight the "from", if null we just render name+address.
  static String _prettyAddr(String addr, RecipientAddress? rec, bool? isThisTo) {
    if (rec == null) return addr;
    final matches = rec.address.trim().toLowerCase() == addr.trim().toLowerCase();
    if (!matches) return addr;
    return '${rec.name}  •  $addr';
  }
}

/* ===================== Shared KV row ===================== */
Widget _kv({
  required BuildContext context,
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
        child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
          },
        ),
    ],
  );
}
