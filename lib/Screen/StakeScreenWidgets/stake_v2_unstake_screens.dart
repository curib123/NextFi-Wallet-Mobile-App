// lib/Screen/StakeScreenWidgets/stake_v2_unstake_screen.dart
//
// Full screen: "Unstake (Stake 2.0)"
// - Shows a blocking loader (non-dismissible) while performing actions
// - Retries transient errors with exponential backoff
// - Keeps your snackbars, confirm sheet, and parent refresh pattern
//
// Dependencies you already have in your app:
//   - AppColor.of(context)
//   - CustomButton / ButtonType
//   - showFloatingSnackBar(...)
//   - showConfirmActionSheet(...)
//   - TronWalletService with: unfreezeBalanceV2, withdrawExpireUnfreeze, cancelAllUnfreezeV2
//   - stake_widgets.dart providing SectionCard, PendingList (or adjust to your components)
//
// Drop-in ready.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Components/confirm_action_sheet.dart';
import 'package:next_fi/Services/tron_wallet_service.dart';

import 'stake_widgets.dart';

enum _Res { ENERGY, BANDWIDTH }

extension on _Res {
  String get label => this == _Res.ENERGY ? 'ENERGY' : 'BANDWIDTH';
  IconData get icon => this == _Res.ENERGY ? LucideIcons.zap : LucideIcons.activity;
}

class StakeV2UnstakeScreen extends StatefulWidget {
  const StakeV2UnstakeScreen({
    super.key,
    required this.tron,
    required this.pk,
    required this.address,
    // ---- Data passed from MAIN screen (parameterized) ----
    required this.stakedEnergySun,
    required this.stakedBandwidthSun,
    required this.availableSlots,
    required this.withdrawableSun,
    required this.unfrozen, // pending + matured list (raw from API or normalized)
    this.onDataChanged, // parent can refresh after actions
  });

  final TronWalletService tron;
  final Uint8List pk;
  final String address;

  // Parameterized data (SUN = 1e-6 TRX)
  final int stakedEnergySun;
  final int stakedBandwidthSun;
  final int availableSlots;
  final int withdrawableSun;
  final List<Map<String, dynamic>> unfrozen;

  final VoidCallback? onDataChanged;

  @override
  State<StakeV2UnstakeScreen> createState() => _StakeV2UnstakeScreenState();
}

class _StakeV2UnstakeScreenState extends State<StakeV2UnstakeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _nf = NumberFormat('#,##0.######');

  bool _performing = false;
  final _amountCtrl = TextEditingController();

  String _fmtTrx(int sun) => _nf.format(sun / 1e6);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------

  // Show a blocking loader (non-dismissible) while running an async action.
  // We DON'T await the dialog Future, so we can run the action and close it in finally.
  Future<T> _withBlockingLoader<T>({
    String title = 'Processing…',
    String message = 'Please wait.',
    required Future<T> Function() action,
  }) async {
    if (!mounted) {
      return await action();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await action();
      return result;
    } finally {
      if (mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
    }
  }

  /// Simple retry with exponential backoff (1s, 2s, 4s ...).
  /// Returns the result of `task` on success; rethrows on final failure.
  Future<T> _retry<T>(
      Future<T> Function() task, {
        int maxAttempts = 3,
        Duration initialDelay = const Duration(seconds: 1),
        bool Function(Object e)? isRetriable,
      }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxAttempts) {
      attempt += 1;
      try {
        return await task();
      } catch (e) {
        final canRetry = isRetriable == null ? true : isRetriable(e);
        if (!canRetry || attempt >= maxAttempts) {
          rethrow;
        }
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    // unreachable
    // ignore: only_throw_errors
    throw Exception('Retry failed');
  }

  String _normalizeType(String? raw) {
    final up = (raw ?? '').toUpperCase();
    return up == 'NET' ? 'BANDWIDTH' : up;
  }

  String get _currentResLabel => _tab.index == 0 ? 'ENERGY' : 'BANDWIDTH';

  List<Map<String, dynamic>> get _tabPending {
    final now = DateTime.now().millisecondsSinceEpoch;
    final filtered = widget.unfrozen.where((e) {
      final type = _normalizeType(e['type']?.toString());
      final expire = (e['expire_time_ms'] as num?)?.toInt() ?? 0;
      // show only this tab's resource + still pending (not yet matured)
      return type == _currentResLabel && (expire == 0 || expire > now);
    }).toList()
      ..sort((a, b) {
        final ax = (a['expire_time_ms'] as num?)?.toInt() ?? 0;
        final bx = (b['expire_time_ms'] as num?)?.toInt() ?? 0;
        return ax.compareTo(bx);
      });
    return filtered;
  }

  void _applyPct(double pct) {
    final frozen = _tab.index == 0 ? widget.stakedEnergySun : widget.stakedBandwidthSun;
    final sun = (frozen * pct).floor();
    _amountCtrl.text = _nf.format(sun / 1e6);
    setState(() {});
  }

  int _currentFrozenSun() =>
      _tab.index == 0 ? widget.stakedEnergySun : widget.stakedBandwidthSun;

  // ---------- Actions ----------

  Future<void> _unstake() async {
    final res = _tab.index == 0 ? _Res.ENERGY : _Res.BANDWIDTH;

    // Accept inputs like "1,234.5"
    final raw = _amountCtrl.text.trim().replaceAll(',', '');
    final amtTrx = double.tryParse(raw);
    if (amtTrx == null || amtTrx <= 0) {
      showFloatingSnackBar(context, message: 'Enter a valid amount.', type: SnackBarType.error);
      return;
    }

    final sun = (amtTrx * 1e6).round();
    final frozen = _currentFrozenSun();

    if (sun > frozen) {
      showFloatingSnackBar(
        context,
        message: 'Max available is ${_fmtTrx(frozen)} TRX for ${res.label}.',
        type: SnackBarType.error,
      );
      return;
    }
    if (widget.availableSlots <= 0) {
      showFloatingSnackBar(
        context,
        message: 'No available Unstake slots. Withdraw matured first.',
        type: SnackBarType.warning,
      );
      return;
    }

    final ok = await showConfirmActionSheet(
      context,
      title: 'Start Unstake of ${_fmtTrx(sun)} TRX?',
      message:
      'After starting, there’s a ~14-day wait. Once it matures, tap “Withdraw” to move TRX back to your balance.',
      confirmLabel: 'Unstake',
      icon: res.icon,
    );
    if (!ok) return;

    if (!mounted) return;
    setState(() => _performing = true);

    try {
      final tx = await _withBlockingLoader<String>(
        title: 'Starting Unstake…',
        message: 'Broadcasting transaction and waiting for confirmation…',
        action: () => _retry<String>(
              () => widget.tron.unfreezeBalanceV2(
            privateKey: widget.pk,
            amountSun: sun,
            resource: res.label,
          ),
          maxAttempts: 3,
          initialDelay: const Duration(seconds: 1),
          // Example predicate if you want to restrict retries:
          // isRetriable: (e) => e is TronError && (e.status == null || e.status! >= 500),
        ),
      );

      final short = tx.length > 10 ? '${tx.substring(0, 6)}…${tx.substring(tx.length - 4)}' : tx;
      showFloatingSnackBar(
        context,
        message: 'Unstake started. tx: $short',
        type: SnackBarType.success,
      );

      widget.onDataChanged?.call(); // parent refresh
    } catch (e) {
      showFloatingSnackBar(context, message: e.toString(), type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _performing = false);
    }
  }

  Future<void> _withdraw() async {
    if (widget.withdrawableSun <= 0) {
      showFloatingSnackBar(context, message: 'No matured amount to withdraw yet.', type: SnackBarType.info);
      return;
    }

    final ok = await showConfirmActionSheet(
      context,
      title: 'Withdraw ${_fmtTrx(widget.withdrawableSun)} TRX?',
      message: 'This returns all matured unstakes to your spendable balance.',
      confirmLabel: 'Withdraw',
      icon: LucideIcons.arrowDownToLine,
    );
    if (!ok) return;

    if (!mounted) return;
    setState(() => _performing = true);

    try {
      final tx = await _withBlockingLoader<String>(
        title: 'Withdrawing…',
        message: 'Broadcasting and confirming transaction…',
        action: () => _retry<String>(
              () => widget.tron.withdrawExpireUnfreeze(privateKey: widget.pk),
          maxAttempts: 3,
          initialDelay: const Duration(seconds: 1),
        ),
      );

      final short = tx.length > 10 ? '${tx.substring(0, 6)}…${tx.substring(tx.length - 4)}' : tx;
      showFloatingSnackBar(context, message: 'Withdrawn. tx: $short', type: SnackBarType.success);
      widget.onDataChanged?.call();
    } catch (e) {
      showFloatingSnackBar(context, message: e.toString(), type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _performing = false);
    }
  }

  Future<void> _cancelAll() async {
    final ok = await showConfirmActionSheet(
      context,
      title: 'Cancel ALL pending unstakes?',
      message:
      'This cancels every in-progress unstake. Matured amounts can be withdrawn separately.',
      confirmLabel: 'Cancel all',
      icon: LucideIcons.alertTriangle,
      destructive: true,
    );
    if (!ok) return;

    if (!mounted) return;
    setState(() => _performing = true);

    try {
      final tx = await _withBlockingLoader<String>(
        title: 'Cancelling…',
        message: 'Broadcasting and confirming cancellation…',
        action: () => _retry<String>(
              () => widget.tron.cancelAllUnfreezeV2(privateKey: widget.pk),
          maxAttempts: 3,
          initialDelay: const Duration(seconds: 1),
        ),
      );

      final short = tx.length > 10 ? '${tx.substring(0, 6)}…${tx.substring(tx.length - 4)}' : tx;
      showFloatingSnackBar(context, message: 'Canceled. tx: $short', type: SnackBarType.success);
      widget.onDataChanged?.call();
    } catch (e) {
      showFloatingSnackBar(context, message: e.toString(), type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _performing = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final frozen = _currentFrozenSun();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unstake'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'ENERGY', icon: Icon(LucideIcons.zap)),
            Tab(text: 'BANDWIDTH', icon: Icon(LucideIcons.activity)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Start Unstake',
                  icon: LucideIcons.unlock,
                  onPressed:  _unstake,
                  type: _performing ? ButtonType.disabled : ButtonType.filled,
                  // If supported: isLoading: _performing,
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          SectionCard(
            title: 'Unstake amount',
            subtitle:
            'Pick a resource tab, then choose how much to unlock from your active stake.',
            leading: LucideIcons.unlock,
            leadingColor: colors.primary,
            children: [
              Row(
                children: [
                  Text(
                    'Active stake (available to unstake)',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                  ),
                  const Spacer(),
                  Text(
                    _fmtTrx(frozen),
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                _tag(colors, LucideIcons.slidersHorizontal, 'Unstake slots',
                    '${widget.availableSlots}'),
                const SizedBox(width: 8),
                _tag(colors, LucideIcons.arrowDownToLine, 'Withdrawable',
                    _fmtTrx(widget.withdrawableSun)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g., 10',
                  prefixIcon: const Icon(LucideIcons.coins),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pctChip('25%', () => _applyPct(.25)),
                  _pctChip('50%', () => _applyPct(.50)),
                  _pctChip('75%', () => _applyPct(.75)),
                  _pctChip('MAX', () => _applyPct(1.0)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.primary.withOpacity(.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.info, size: 18, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Unstake starts a ~14-day timer. When it matures, tap “Withdraw matured” to return TRX to your balance.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Pending for the CURRENT TAB only
          if (_tabPending.isNotEmpty) ...[
            const SizedBox(height: 12),
            PendingList(items: _tabPending, formatTrx: _fmtTrx),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: CustomButton(
                  text: 'Withdraw matured',
                  icon: LucideIcons.arrowDownToLine,
                  onPressed:  _withdraw,
                  type: _performing ? ButtonType.disabled : ButtonType.outlined,
                  // isLoading: _performing,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  text: 'Cancel all',
                  icon: LucideIcons.delete,
                  onPressed:  _cancelAll,
                  type: _performing ? ButtonType.disabled : ButtonType.outlined,
                  // isLoading: _performing,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _tag(AppColor colors, IconData i, String l, String v) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border.withOpacity(.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(i, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(l, style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
        ),
        Text(v, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
      ]),
    ),
  );

  Widget _pctChip(String text, VoidCallback onTap) => ChoiceChip(
    label: Text(text),
    selected: false,
    onSelected: (_) => onTap(),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
  );
}
