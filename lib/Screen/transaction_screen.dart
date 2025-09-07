import 'dart:async';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

import 'package:next_fi/Components/AppAlert.dart';
import 'package:next_fi/Components/empty_state.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';

import 'package:next_fi/Provider/RecipientAddressProvider.dart';
import 'package:next_fi/model/recipient_address.dart';

import 'package:next_fi/Provider/AssetProvider.dart';

typedef Tx = Map<String, dynamic>;

enum _TxFilter { all, receive, send }

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final ScrollController _scrollController = ScrollController();
  late final StellarWalletService _stellar;

  String? _userAddress; // G... public key
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _errorMsg;

  // Horizon pagination uses a cursor (paging token), not offset.
  String? _cursor; // next cursor to request when loading more
  final int _limit = 20;
  List<Tx> _transactions = [];
  final Set<String> _seenIds = <String>{};

  StreamSubscription<stellar.OperationResponse>? _incomingSub;
  int _fetchGen = 0;

  _TxFilter _filter = _TxFilter.all;

  static final DateFormat _listFmt = DateFormat('MMM d, h:mm a');
  static final DateFormat _detailFmt = DateFormat('MMM d, yyyy • h:mm a');

  // Nice default color choices for contacts
  static const List<int> _colorChoices = <int>[
    0xFF5B8CFF, 0xFFFF6B6B, 0xFF2ED573, 0xFFFFC107, 0xFF6A5ACD, 0xFF00C2A8, 0xFFEA4C89,
  ];

  // Fallback if AssetProvider isn't available for some reason
  static const String _FALLBACK_XLM_LOGO =
      'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png';

  @override
  void initState() {
    super.initState();
    _stellar = StellarWalletService();
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
      final wallet = await StellarWalletService.walletFromMnemonic(storedMnemonic);
      final kp = await StellarWalletService.getKeyPair(wallet, index: 0);
      final address = kp.accountId; // G... address

      _set(() => _userAddress = address);

      await _fetchTransactions();

      // Live incoming payments stream
      _incomingSub = _stellar.sdk.payments
          .forAccount(_userAddress!)
          .cursor("now")
          .stream()
          .listen((op) {
        final tx = _opToTx(op, _userAddress!);
        if (tx != null) _handleIncomingTx(tx);
      }, onError: (_) {});
    } catch (e) {
      _set(() {
        _loading = false;
        _errorMsg = 'Failed to load wallet: $e';
      });
    }
  }

  // Convert OperationResponse to our Tx map, or null if unsupported op type.
  Tx? _opToTx(stellar.OperationResponse op, String myAddr) {
    String? assetCode;
    double? amount;
    String? from;
    String? to;

    if (op is stellar.PaymentOperationResponse) {
      assetCode = (op.assetType == 'native') ? 'XLM' : (op.assetCode ?? 'ASSET');
      amount = double.tryParse(op.amount ?? '');
      from = op.from;
      to = op.to;
    } else if (op is stellar.PathPaymentStrictSendOperationResponse) {
      // amount here is the *destination* amount/asset
      assetCode = (op.assetType == 'native') ? 'XLM' : (op.assetCode ?? 'ASSET');
      amount = double.tryParse(op.amount ?? '');
      from = op.from;
      to = op.to;
    } else if (op is stellar.PathPaymentStrictReceiveOperationResponse) {
      assetCode = (op.assetType == 'native') ? 'XLM' : (op.assetCode ?? 'ASSET');
      amount = double.tryParse(op.amount ?? '');
      from = op.from;
      to = op.to;
    } else if (op is stellar.CreateAccountOperationResponse) {
      // Treat as incoming XLM payment (account creation funding)
      assetCode = 'XLM';
      amount = double.tryParse(op.startingBalance ?? '');
      from = op.funder;
      to = op.account;
    } else {
      return null; // skip non-payment-like ops
    }

    final hash = op.transactionHash ?? '';
    final id = '${op.pagingToken ?? hash}';
    final createdAt = op.createdAt; // ISO8601 string
    final ts = _safeParseMillis(createdAt);

    final isIncoming = (to != null && to == myAddr);

    return <String, dynamic>{
      'id': id,
      'hash': hash,
      'timestamp': ts,
      'asset': assetCode ?? 'ASSET',
      'amount': amount ?? 0.0,
      'from': from ?? '',
      'to': to ?? '',
      'direction': isIncoming ? 'in' : 'out',
      // Will be filled by _attachRecipientMetaTo()
      'recName': null,
      'recColor': null,
    };
  }

  int? _safeParseMillis(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  void _handleIncomingTx(Tx tx) {
    if (!mounted) return;
    final id = (tx['id'] ?? '').toString();
    if (id.isEmpty || _seenIds.contains(id)) return;

    // Enrich with recipient meta before inserting
    _attachRecipientMetaTo([tx]);

    _set(() {
      _seenIds.add(id);
      _transactions.insert(0, tx);
    });

    final asset = (tx['asset'] ?? 'XLM').toString();
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
        _cursor = null;
      }
    });

    try {
      final builder = _stellar.sdk.payments
          .forAccount(addr)
          .order(stellar.RequestBuilderOrder.DESC)
          .limit(_limit);

      if (loadMore && _cursor != null && _cursor!.isNotEmpty) {
        builder.cursor(_cursor!);
      }

      final page = await builder.execute(); // Page<OperationResponse>
      final ops = page.records ?? const <stellar.OperationResponse>[];

      // Map into Tx list (payments & path-payments & create-account only)
      final newTx = <Tx>[];
      for (final op in ops) {
        final tx = _opToTx(op, addr);
        if (tx != null) newTx.add(tx);
      }

      if (myToken != _fetchGen) return;

      // ✅ Iterate all fetched txs and attach name/color from address book
      _attachRecipientMetaTo(newTx);

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

        // Prepare next cursor from the last op received
        if (ops.isNotEmpty) {
          _cursor = ops.last.pagingToken;
        }
        _hasMore = ops.length == _limit;
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

  // Enrich a list of Tx with cached recipient name/color (if present)
  void _attachRecipientMetaTo(List<Tx> list) {
    if (!mounted) return;
    final recipProv = context.read<RecipientAddressProvider>();
    if (recipProv.loading) return; // will resolve next rebuild

    for (final tx in list) {
      final direction = (tx['direction'] ?? 'other').toString();
      final isIncoming = direction == 'in';
      final peerAddr = (isIncoming ? (tx['from'] ?? '') : (tx['to'] ?? '')).toString().trim();
      if (peerAddr.isEmpty) continue;

      final rec = recipProv.byAddress(peerAddr);
      if (rec != null) {
        tx['recName'] = rec.name;
        tx['recColor'] = rec.color;
      } else {
        tx['recName'] = null;
        tx['recColor'] = null;
      }
    }
  }

  Future<void> _resetAndFetch() async {
    _cursor = null;
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
        mainAxisAlignment: MainAxisAlignment.start,
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
          message: 'When you send or receive XLM or USDC, they’ll appear here.',
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

    final asset = (tx['asset'] ?? 'XLM').toString();
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final from = (tx['from'] ?? '').toString();
    final to = (tx['to'] ?? '').toString();
    final direction = (tx['direction'] ?? 'other').toString();
    final isIncoming = direction == 'in';

    final peerAddr = (isIncoming ? from : to).trim();

    // Prefer cached meta; fallback to provider for live updates
    String? recName = (tx['recName'] as String?);
    int? recColor = (tx['recColor'] as int?);
    RecipientAddress? rec;

    if (recName == null || recColor == null) {
      rec = recipProv.byAddress(peerAddr);
      if (rec != null) {
        recName = rec.name;
        recColor = rec.color;
        // store back so future rebuilds use cached
        tx['recName'] = recName;
        tx['recColor'] = recColor;
      }
    }

    final titleText = recName != null
        ? "$recName • ${amount.toStringAsFixed(2)} $asset"
        : "${amount.toStringAsFixed(2)} $asset";

    final subtitleWho = isIncoming ? "From" : "To";
    final subtitlePeer = recName != null ? "$recName (${_short(peerAddr)})" : _short(peerAddr);

    return ListTile(
      key: ValueKey(txId.isEmpty ? 'idx:${_transactions.indexOf(tx)}' : txId),
      leading: _buildLeadingAvatarWithLogo(
        context: context,
        colors: colors,
        isIncoming: isIncoming,
        recName: recName,
        recColor: recColor,
        asset: asset,
      ),
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
        peerAddr: peerAddr,
        isIncoming: isIncoming,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Modal: transaction details + Save/Edit contact by address
  // ───────────────────────────────────────────────────────────────────────────
  // ───────────────────────────────────────────────────────────────────────────
// Modal: transaction details + auto-apply contact name/color from address book
// ───────────────────────────────────────────────────────────────────────────
  void _showTxDetailsBottomSheet(
      BuildContext context,
      AppColor colors,
      Tx tx, {
        required String peerAddr,
        required bool isIncoming,
      }) {
    final txId = (tx['id'] ?? '').toString();
    final ts = (tx['timestamp'] as num?)?.toInt();
    final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

    final asset = (tx['asset'] ?? 'XLM').toString();
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final from = (tx['from'] ?? '').toString();
    final to = (tx['to'] ?? '').toString();
    final hash = (tx['hash'] ?? '').toString();

    final explorerUrl = _stellarExplorerTx(hash, _stellar);

    // 🔹 Look up existing contact by the peer address and APPLY to the tx cache
    final recipProv = context.read<RecipientAddressProvider>();
    final existing = recipProv.byAddress(peerAddr);
    if (existing != null) {
      tx['recName'] = existing.name;
      tx['recColor'] = existing.color;
      // If you want the list behind the modal to reflect this immediately:
      if (mounted) setState(() {});
    }

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
          initialChildSize: 0.62,
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

                  // Amount + asset logo
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _assetLogo(context: context, asset: asset, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        "${amount.toStringAsFixed(6)} $asset",
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 🔹 Contact chip shown using existing (auto-applied if present)
                  _ContactRow(
                    colors: colors,
                    peerAddr: peerAddr,
                    existing: existing,
                    onChanged: (rec) {
                      // if user edits/saves, persist change into tx cache and rebuild
                      tx['recName'] = rec?.name;
                      tx['recColor'] = rec?.color;
                      setState(() {});
                    },
                  ),

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

                  // 🔹 From/To rows automatically show contact name if it exists
                  _kv(
                    context: context,
                    colors: colors,
                    label: "From",
                    value: _prettyAddr(from, existing, isIncoming ? false : null),
                    mono: false,
                    copyable: true,
                  ),
                  const SizedBox(height: 8),
                  _kv(
                    context: context,
                    colors: colors,
                    label: "To",
                    value: _prettyAddr(to, existing, isIncoming ? true : null),
                    mono: false,
                    copyable: true,
                  ),
                  const SizedBox(height: 8),
                  _kv(
                    context: context,
                    colors: colors,
                    label: "Tx Hash",
                    value: hash,
                    mono: true,
                    copyable: true,
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hash.isEmpty
                              ? null
                              : () async {
                            await Clipboard.setData(ClipboardData(text: hash));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Hash copied')),
                            );
                          },
                          icon: Icon(LucideIcons.copy, size: 18, color: colors.primary),
                          label: Text(
                            "Copy Hash",
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
                          onPressed: (explorerUrl == null || explorerUrl.isEmpty)
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


  // Inside _TransactionScreenState
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
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied')),
              );
            },
          ),
      ],
    );
  }

  /* ===================== Helpers ===================== */

  String? _stellarExplorerTx(String hash, StellarWalletService svc) {
    if (hash.isEmpty) return null;
    // Use Stellar.Expert (public/testnet)
    final isTestnet = identical(svc.sdk, stellar.StellarSDK.TESTNET);
    final net = isTestnet ? 'testnet' : 'public';
    return 'https://stellar.expert/explorer/$net/tx/$hash';
  }

  // Leading avatar with optional contact color and overlaid asset logo from AssetProvider
  Widget _buildLeadingAvatarWithLogo({
    required BuildContext context,
    required AppColor colors,
    required bool isIncoming,
    required String asset,
    String? recName,
    int? recColor,
  }) {
    // Base avatar (contact-colored or direction arrow)
    Widget baseAvatar;
    if (recName != null && recColor != null) {
      final bg = Color(recColor);
      final initial = recName.trim().isNotEmpty
          ? recName.trim().characters.first.toUpperCase()
          : '•';
      baseAvatar = CircleAvatar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
      );
    } else {
      baseAvatar = CircleAvatar(
        backgroundColor: (isIncoming ? colors.success : colors.error).withOpacity(0.15),
        child: Icon(
          isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncoming ? colors.success : colors.error,
        ),
      );
    }

    // Size + overlay logo (overflow-proof)
    const double outer = 40;
    const double logoSize = 16;

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: SizedBox(width: outer, height: outer, child: baseAvatar),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary.withOpacity(0.12)),
              ),
              padding: const EdgeInsets.all(1.5),
              child: _assetLogo(context: context, asset: asset, size: logoSize),
            ),
          ),
        ],
      ),
    );
  }

  // Asset logo using AssetProvider.logoFor(); graceful fallback to XLM logo if provider missing.
  Widget _assetLogo({
    required BuildContext context,
    required String asset,
    required double size,
  }) {
    String url = _FALLBACK_XLM_LOGO;
    try {
      final ap = context.read<AssetProvider>();
      url = ap.logoFor(asset);
    } catch (_) {
      // Provider not found; keep fallback.
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black12,
              shape: BoxShape.circle,
            ),
            child: Text(
              asset.isNotEmpty ? asset.characters.first.toUpperCase() : '•',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          );
        },
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

/* ===================== Contact row (save / edit) ===================== */
class _ContactRow extends StatelessWidget {
  final AppColor colors;
  final String peerAddr;
  final RecipientAddress? existing;
  final ValueChanged<RecipientAddress?> onChanged;

  const _ContactRow({
    required this.colors,
    required this.peerAddr,
    required this.existing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rec = existing ??
        context.read<RecipientAddressProvider>().byAddress(peerAddr);
    final has = rec != null;

    return Row(
      children: [
        if (has)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Color(rec!.color).withOpacity(0.14),
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
        if (has) const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () =>
              _showContactEditor(context, peerAddr, rec, onChanged),
          icon: Icon(has ? LucideIcons.userCog : LucideIcons.userPlus, size: 16,
              color: colors.primary),
          label: Text(has ? 'Edit Contact' : 'Save Contact',
              style: TextStyle(
                  color: colors.primary, fontWeight: FontWeight.w700)),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  static Future<void> _showContactEditor(BuildContext context,
      String addr,
      RecipientAddress? existing,
      ValueChanged<RecipientAddress?> onChanged,) async {
    final colors = AppColor.of(context);
    final prov = context.read<RecipientAddressProvider>();

    final nameCtl = TextEditingController(text: existing?.name ?? '');
    int chosen = existing?.color ?? _TransactionScreenState._colorChoices.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery
                    .of(ctx)
                    .viewInsets
                    .bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    existing == null ? 'Save Contact' : 'Edit Contact',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Alice',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'Color', style: TextStyle(color: colors.textSecondary)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _TransactionScreenState._colorChoices.map((c) {
                      final sel = c == chosen;
                      return GestureDetector(
                        onTap: () => setModalState(() => chosen = c),
                        // ✅ FIX: no void-expression error
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: sel
                              ? const Icon(
                              Icons.check, size: 18, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel', style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = nameCtl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('Please enter a name')),
                              );
                              return;
                            }
                            RecipientAddress saved;
                            if (existing == null) {
                              saved = await prov.add(
                                  name: name, address: addr, color: chosen);
                            } else {
                              saved = (await prov.update(
                                  existing.id, name: name, color: chosen)) ??
                                  existing;
                            }
                            onChanged(saved);
                            if (context.mounted) Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary, elevation: 0),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
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