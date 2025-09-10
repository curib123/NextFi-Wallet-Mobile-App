import 'dart:async';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/AppAlert.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

import 'package:next_fi/Components/empty_state.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';

import 'package:next_fi/Provider/RecipientAddressProvider.dart';
import 'package:next_fi/model/recipient_address.dart';
import 'package:next_fi/Provider/AssetProvider.dart';

import 'package:next_fi/Components/recipient_upsert_sheet.dart';


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
  bool _accountMissing = false; // unfunded / not yet created on-chain

  String? _cursor; // horizon paging token
  final int _limit = 20;
  List<Tx> _transactions = [];
  final Set<String> _seenIds = <String>{};

  StreamSubscription<stellar.OperationResponse>? _incomingSub;
  int _fetchGen = 0;

  _TxFilter _filter = _TxFilter.all;

  static final DateFormat _listFmt = DateFormat('MMM d, h:mm a');
  static final DateFormat _detailFmt = DateFormat('MMM d, yyyy • h:mm a');

  static const String _FALLBACK_XLM_LOGO =
      'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png';

  // ─── Pending Incoming Chips (flash at top on new incoming) ─────────────
  final List<_IncomingChip> _incomingChips = [];
  void _pushIncomingChip({required String text, required Color color, IconData? icon}) {
    final chip = _IncomingChip(text: text, color: color, icon: icon ?? LucideIcons.arrowDownCircle);
    setState(() => _incomingChips.add(chip));
    chip.timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _incomingChips.remove(chip));
    });
  }

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
    for (final c in _incomingChips) {
      c.timer?.cancel();
    }
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

      // Live incoming stream (only if account exists)
      if (!_accountMissing && _userAddress != null) {
        _incomingSub = _stellar.sdk.payments
            .forAccount(_userAddress!)
            .cursor("now")
            .stream()
            .listen((op) {
          final tx = _opToTx(op, _userAddress!);
          if (tx != null) _handleIncomingTx(tx);
        }, onError: (_) {
          // optional: log
        });
      }
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
      assetCode = 'XLM';
      amount = double.tryParse(op.startingBalance ?? '');
      from = op.funder;
      to = op.account;
    } else {
      return null;
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

    _attachRecipientMetaTo([tx]);

    _set(() {
      _seenIds.add(id);
      _transactions.insert(0, tx);
    });

    final colors = AppColor.of(context);
    final asset = (tx['asset'] ?? 'XLM').toString();
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final from = (tx['from'] ?? '').toString();
    final isIncoming = true;
    final peerAddr = from.trim();

    // 1) Top-center "incoming" chip (auto dismiss)
    _pushIncomingChip(
      text: 'Incoming ${amount.toStringAsFixed(6)} $asset',
      color: colors.success,
      icon: LucideIcons.arrowDownCircle,
    );

    // 2) AppAlert (info) with "View" button to open details
    final ctl = showAppAlert(
      context,
      type: AppAlertType.info,
      title: 'Incoming $asset',
      subtitle: 'You received ${amount.toStringAsFixed(6)} $asset.\nTap below to view details.',
      primaryText: 'View',
      barrierDismissible: true,
      onPrimary: () {
        // open details, then close
        _showTxDetailsBottomSheet(
          context,
          colors,
          tx,
          peerAddr: peerAddr,
          isIncoming: isIncoming,
        );
      },
    );
    // Auto-close alert after a short delay if user ignores it
    Timer(const Duration(seconds: 5), () {
      if (mounted) ctl.close();
    });
  }

  bool _isAccountMissingError(Object e) {
    try {
      final dynamic x = e;
      final int? code = x.response?.statusCode as int?;
      final String? body = x.response?.body as String?;
      if (code == 404) return true;
      if (body != null &&
          (body.contains('Resource Missing') ||
              body.contains('"title":"Resource Missing"') ||
              body.contains('not_found'))) {
        return true;
      }
    } catch (_) {}
    final s = e.toString();
    return s.contains('404') || s.contains('Resource Missing') || s.contains('not_found');
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

      final page = await builder.execute();
      final ops = page.records ?? const <stellar.OperationResponse>[];

      final newTx = <Tx>[];
      for (final op in ops) {
        final tx = _opToTx(op, addr);
        if (tx != null) newTx.add(tx);
      }

      if (myToken != _fetchGen) return;

      _attachRecipientMetaTo(newTx);

      _set(() {
        _accountMissing = false;
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
        if (ops.isNotEmpty) {
          _cursor = ops.last.pagingToken;
        }
        _hasMore = ops.length == _limit;
      });
    } catch (e) {
      if (myToken != _fetchGen) return;

      if (_isAccountMissingError(e)) {
        _set(() {
          _accountMissing = true;
          _transactions = const [];
          _hasMore = false;
          _errorMsg = null;
        });
      } else {
        _set(() {
          _errorMsg = 'Error fetching history: $e';
        });
      }
    } finally {
      _set(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _attachRecipientMetaTo(List<Tx> list) {
    if (!mounted) return;
    final recipProv = context.read<RecipientAddressProvider>();
    if (recipProv.loading) return;

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
      final msg = _accountMissing
          ? 'This wallet is new or not yet funded on-chain. Once you receive your first XLM or USDC, your transactions will appear here.'
          : 'When you send or receive XLM or USDC, they’ll appear here.';
      content = Center(
        child: EmptyState.noData(
          title: 'No transactions yet',
          message: msg,
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

    // Wrap content in a Stack to overlay the incoming chips at the very top.
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
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: content,
          ),

          // Top-center incoming chips
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _incomingChips.map((c) {
                  return AnimatedSlide(
                    key: ValueKey(c.id),
                    duration: const Duration(milliseconds: 250),
                    offset: Offset(0, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: 1.0,
                      child: _IncomingChipWidget(chip: c, surface: colors.surface),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // List tile builder
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

    String? recName = (tx['recName'] as String?);
    int? recColor = (tx['recColor'] as int?);
    RecipientAddress? rec;

    if (recName == null || recColor == null) {
      rec = recipProv.byAddress(peerAddr);
      if (rec != null) {
        recName = rec.name;
        recColor = rec.color;
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
  // Modal: transaction details
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

    final recipProv = context.read<RecipientAddressProvider>();
    final existing = recipProv.byAddress(peerAddr);
    if (existing != null) {
      tx['recName'] = existing.name;
      tx['recColor'] = existing.color;
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

                  Row(
                    children: [
                      if (existing != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(existing.color).withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Color(existing.color).withOpacity(0.35)),
                          ),
                          child: Text(
                            existing.name,
                            style: TextStyle(
                              color: Color(existing.color),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (existing != null) const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final saved = await showRecipientUpsertSheet(
                            context,
                            initial: existing,
                          );
                          if (saved == true && mounted) {
                            final updated = context.read<RecipientAddressProvider>().byAddress(peerAddr);
                            tx['recName']  = updated?.name;
                            tx['recColor'] = updated?.color;
                            setState(() {});
                          }
                        },
                        icon: Icon(
                          existing != null ? LucideIcons.userCog : LucideIcons.userPlus,
                          size: 16,
                          color: colors.primary,
                        ),
                        label: Text(
                          existing != null ? 'Edit Contact' : 'Save Contact',
                          style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ],
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

  // Key-Value row
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
    final isTestnet = identical(svc.sdk, stellar.StellarSDK.TESTNET);
    final net = isTestnet ? 'testnet' : 'public';
    return 'https://stellar.expert/explorer/$net/tx/$hash';
  }

  Widget _buildLeadingAvatarWithLogo({
    required BuildContext context,
    required AppColor colors,
    required bool isIncoming,
    required String asset,
    String? recName,
    int? recColor,
  }) {
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

  Widget _assetLogo({
    required BuildContext context,
    required String asset,
    required double size,
  }) {
    String url = _FALLBACK_XLM_LOGO;
    try {
      final ap = context.read<AssetProvider>();
      url = ap.logoFor(asset);
    } catch (_) {}
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
            decoration: const BoxDecoration(
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

  static String _prettyAddr(String addr, RecipientAddress? rec, bool? isThisTo) {
    if (rec == null) return addr;
    final matches = rec.address.trim().toLowerCase() == addr.trim().toLowerCase();
    if (!matches) return addr;
    return '${rec.name}  •  $addr';
  }
}

/* ───────────────────── Incoming Chip classes ───────────────────── */

class _IncomingChip {
  _IncomingChip({
    required this.text,
    required this.color,
    required this.icon,
  }) : id = UniqueKey().toString();
  final String id;
  final String text;
  final Color color;
  final IconData icon;
  Timer? timer;
}

class _IncomingChipWidget extends StatelessWidget {
  const _IncomingChipWidget({required this.chip, required this.surface});
  final _IncomingChip chip;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chip.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chip.color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 16, color: chip.color),
          const SizedBox(width: 8),
          Text(
            chip.text,
            style: TextStyle(
              color: chip.color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
