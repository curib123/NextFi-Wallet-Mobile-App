import 'dart:async';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Provider/TransactionProvider.dart';
import 'package:next_fi/Components/AppAlert.dart';
import 'package:next_fi/Components/empty_state.dart';
import 'package:next_fi/Components/recipient_upsert_sheet.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/AssetProvider.dart';
import 'package:next_fi/Provider/RecipientAddressProvider.dart';
import 'package:next_fi/model/recipient_address.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Tx>? _incomingUiSub;

  static final DateFormat _listFmt = DateFormat('MMM d, h:mm a');
  static final DateFormat _detailFmt = DateFormat('MMM d, yyyy • h:mm a');

  static const String _FALLBACK_XLM_LOGO =
      'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png';

  // UI-only ephemeral chips
  final List<_IncomingChip> _incomingChips = [];

  // Boot guard so we don’t call start() or subscribe multiple times
  bool _booted = false;

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

    _scrollController.addListener(() {
      final pos = _scrollController.position;
      if (!mounted || !pos.hasPixels) return;
      final p = context.read<TransactionsProvider>();
      if (pos.pixels >= pos.maxScrollExtent - 200 && !p.loadingMore && p.hasMore) {
        p.fetch(loadMore: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // use existing provider from context; no local ChangeNotifierProvider here
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<TransactionsProvider>();

      if (!_booted) {
        p.start(); // assume idempotent; guarded so it won’t spam
        _incomingUiSub ??= p.incomingStream.listen((tx) {
          final colors = AppColor.of(context);
          final asset = (tx['asset'] ?? 'XLM').toString();
          final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

          _pushIncomingChip(
            text: 'Incoming ${amount.toStringAsFixed(6)} $asset',
            color: colors.success,
            icon: LucideIcons.arrowDownCircle,
          );

          // toast alert with quick-view
          final ctl = showAppAlert(
            context,
            type: AppAlertType.info,
            title: 'Incoming $asset',
            subtitle: 'You received ${amount.toStringAsFixed(6)} $asset. Tap below to view details.',
            primaryText: 'View',
            barrierDismissible: true,
            onPrimary: () {
              final peerAddr = (tx['from'] ?? '').toString().trim();
              const isIncoming = true;
              _showTxDetailsBottomSheet(context, AppColor.of(context), tx,
                  peerAddr: peerAddr, isIncoming: isIncoming);
            },
          );
          Timer(const Duration(seconds: 5), () {
            if (mounted) ctl.close();
          });
        });
        _booted = true;
      }
    });
  }

  @override
  void dispose() {
    _incomingUiSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final colors = AppColor.of(context);
    final p = context.watch<TransactionsProvider>();
    final recipProv = context.watch<RecipientAddressProvider>();

    // Attach contact meta on-demand (UI-only; provider stays pure)
    void attachRecipientMetaTo(List<Tx> list) {
      if (recipProv.loading) return;
      for (final tx in list) {
        final direction = (tx['direction'] ?? 'other').toString();
        final isIncoming = direction == 'in';
        final peerAddr =
        (isIncoming ? (tx['from'] ?? '') : (tx['to'] ?? '')).toString().trim();
        if (peerAddr.isEmpty) continue;
        final rec = recipProv.byAddress(peerAddr);
        tx['recName'] = rec?.name;
        tx['recColor'] = rec?.color;
      }
    }

    final visibleTxs = [...p.visibleTxs];
    attachRecipientMetaTo(visibleTxs);
    final showLoaderRow = p.loadingMore && p.filter == TxFilter.all;

    Widget content;
    if (p.loading && p.txs.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (p.errorMsg != null) {
      content = Center(
        child: EmptyState.error(
          title: 'Couldn’t load transactions',
          message: p.errorMsg!,
          primaryActionLabel: 'Retry',
          onPrimaryAction: p.resetAndFetch,
          context: context,
        ),
      );
    } else if (p.txs.isEmpty) {
      final msg = p.accountMissing
          ? 'This wallet is new or not yet funded on-chain. Once you receive your first XLM or USDC, your transactions will appear here.'
          : 'When you send or receive XLM or USDC, they’ll appear here.';
      content = Center(
        child: EmptyState.noData(
          title: 'No transactions yet',
          message: msg,
          primaryActionLabel: 'Refresh',
          onPrimaryAction: p.resetAndFetch,
          context: context,
        ),
      );
    } else if (p.txs.isNotEmpty && visibleTxs.isEmpty) {
      content = Center(
        child: EmptyState.noData(
          title: 'No matching transactions',
          message: 'Try switching filters to All, Receive, or Send.',
          primaryActionLabel: 'Clear Filter',
          onPrimaryAction: () => p.setFilter(TxFilter.all),
          context: context,
        ),
      );
    } else {
      content = RefreshIndicator(
        onRefresh: p.resetAndFetch,
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
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildFilterChips(colors, p),
        ),
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: content,
          ),
          // Top-center incoming chips overlay
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
                    offset: const Offset(0, 0),
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

  Widget _buildFilterChips(AppColor colors, TransactionsProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _chip(colors, p, label: 'All', value: TxFilter.all),
          const SizedBox(width: 8),
          _chip(colors, p, label: 'Receive', value: TxFilter.receive),
          const SizedBox(width: 8),
          _chip(colors, p, label: 'Send', value: TxFilter.send),
        ],
      ),
    );
  }

  Widget _chip(AppColor colors, TransactionsProvider p,
      {required String label, required TxFilter value}) {
    final selected = p.filter == value;
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
      onSelected: (_) => p.setFilter(value),
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
        ? '$recName • ${amount.toStringAsFixed(2)} $asset'
        : '${amount.toStringAsFixed(2)} $asset';

    final subtitleWho = isIncoming ? 'From' : 'To';
    final subtitlePeer =
    recName != null ? '$recName (${_short(peerAddr)})' : _short(peerAddr);

    return ListTile(
      key: ValueKey(txId.isEmpty ? 'idx:${tx.hashCode}' : txId),
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
        '$subtitleWho: $subtitlePeer • ${dt != null ? _listFmt.format(dt) : ''}',
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
    final ts = (tx['timestamp'] as num?)?.toInt();
    final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

    final asset = (tx['asset'] ?? 'XLM').toString();
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final from = (tx['from'] ?? '').toString();
    final to = (tx['to'] ?? '').toString();
    final hash = (tx['hash'] ?? '').toString();

    final isTestnet = context.read<TransactionsProvider>().isTestnet;
    final explorerUrl = _explorerUrlFor(hash, isTestnet);

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
                        'Transaction Details',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isIncoming ? colors.success : colors.error)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: (isIncoming ? colors.success : colors.error)
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          isIncoming ? 'IN' : 'OUT',
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
                        '${amount.toStringAsFixed(6)} $asset',
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(existing.color).withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Color(existing.color).withOpacity(0.35)),
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
                            final updated = context
                                .read<RecipientAddressProvider>()
                                .byAddress(peerAddr);
                            tx['recName'] = updated?.name;
                            tx['recColor'] = updated?.color;
                            setState(() {});
                          }
                        },
                        icon: Icon(
                          existing != null
                              ? LucideIcons.userCog
                              : LucideIcons.userPlus,
                          size: 16,
                          color: colors.primary,
                        ),
                        label: Text(
                          existing != null ? 'Edit Contact' : 'Save Contact',
                          style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(LucideIcons.calendarClock,
                          size: 16, color: colors.textSecondary),
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
                      label: 'From',
                      value: from,
                      mono: false,
                      copyable: true),
                  const SizedBox(height: 8),
                  _kv(
                      context: context,
                      colors: colors,
                      label: 'To',
                      value: to,
                      mono: false,
                      copyable: true),
                  const SizedBox(height: 8),
                  _kv(
                      context: context,
                      colors: colors,
                      label: 'Tx Hash',
                      value: hash,
                      mono: true,
                      copyable: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hash.isEmpty
                              ? null
                              : () async {
                            await Clipboard.setData(
                                ClipboardData(text: hash));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Hash copied')));
                          },
                          icon: Icon(LucideIcons.copy,
                              size: 18, color: colors.primary),
                          label: Text('Copy Hash',
                              style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: colors.primary.withOpacity(0.35)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (explorerUrl == null ||
                              explorerUrl.isEmpty)
                              ? null
                              : () async {
                            await Clipboard.setData(
                                ClipboardData(text: explorerUrl));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                    Text('Explorer link copied')));
                          },
                          icon: const Icon(LucideIcons.externalLink,
                              size: 18, color: Colors.white),
                          label: const Text('Explorer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
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
                      label: const Text('Done'),
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
          child:
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
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
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Copied')));
            },
          ),
      ],
    );
  }

  String? _explorerUrlFor(String hash, bool isTestnet) {
    if (hash.isEmpty) return null;
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

  Widget _assetLogo({required BuildContext context, required String asset, required double size}) {
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
            decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
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
}

/* ───────────────────── Incoming Chip classes ───────────────────── */
class _IncomingChip {
  _IncomingChip({required this.text, required this.color, required this.icon})
      : id = UniqueKey().toString();
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
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 16, color: chip.color),
          const SizedBox(width: 8),
          Text(
            chip.text,
            style: TextStyle(color: chip.color, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
