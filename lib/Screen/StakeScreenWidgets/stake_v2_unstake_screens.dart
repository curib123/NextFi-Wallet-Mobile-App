import 'dart:async'; // <-- add this
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
    this.onDataChanged,     // parent can refresh after actions
  });

  final TronWalletService tron;
  final Uint8List pk;
  final String address;

  // Parameterized data
  final int stakedEnergySun;
  final int stakedBandwidthSun;
  final int availableSlots;
  final int withdrawableSun;
  final List<Map<String, dynamic>> unfrozen;

  final VoidCallback? onDataChanged;

  @override
  State<StakeV2UnstakeScreen> createState() => _StakeV2UnstakeScreenState();
}

class _StakeV2UnstakeScreenState extends State<StakeV2UnstakeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _nf = NumberFormat('#,##0.######');

  bool _performing = false;
  final _amountCtrl = TextEditingController();

  // ---- Realtime state (seeded from widget.* then auto-refreshed) ----
  late int _stakedEnergySunLive;
  late int _stakedBandwidthSunLive;
  late int _availableSlotsLive;
  late int _withdrawableSunLive;
  late List<Map<String, dynamic>> _unfrozenLive;

  // ---- Realtime polling ----
  Timer? _rt;
  bool _refreshing = false;
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _tick = Duration(seconds: 30);    // how often to poll
  static const Duration _minGap = Duration(seconds: 20);  // anti-overlap throttle

  String _fmtTrx(int sun) => _nf.format(sun / 1e6);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));

    // Seed live state from props
    _stakedEnergySunLive = widget.stakedEnergySun;
    _stakedBandwidthSunLive = widget.stakedBandwidthSun;
    _availableSlotsLive = widget.availableSlots;
    _withdrawableSunLive = widget.withdrawableSun;
    _unfrozenLive = List<Map<String, dynamic>>.from(widget.unfrozen);

    // Kick off realtime
    _startRealtime();
    // Grab a fresh snapshot right away
    _refreshFromChain(force: true);
  }

  @override
  void dispose() {
    _tab.dispose();
    _amountCtrl.dispose();
    _rt?.cancel();
    super.dispose();
  }

  // Helpers
  String _normalizeType(String? raw) {
    final up = (raw ?? '').toUpperCase();
    return up == 'NET' ? 'BANDWIDTH' : up;
  }

  int _asIntSun(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  int? _pickExpireMs(Map m) {
    final ms = m['expire_time_ms'] ?? m['unfreeze_expire_time_ms'];
    if (ms is num) return ms.toInt();
    final sec = m['expire_time'] ?? m['unfreeze_expire_time'] ?? m['timestamp'];
    if (sec is num) return (sec * 1000).toInt();
    return null;
  }

  int _pickAmountSun(Map m) {
    const candidates = [
      'amount_sun','amount','balance','value','sun',
      'frozen_balance','frozenBalance',
      'frozen_balance_for_energy','delegated_frozen_balance_for_energy',
      'frozen_balance_for_bandwidth','delegated_frozen_balance_for_bandwidth',
      'balance_sun','stake_amount','amountSun','amountSUN',
      'unfreeze_amount','unfrozen_amount',
    ];
    for (final k in candidates) {
      if (m.containsKey(k)) {
        final v = m[k];
        if (v is Map && v.containsKey('amount')) return _asIntSun(v['amount']);
        return _asIntSun(v);
      }
      final hit = m.entries.firstWhere(
            (e) => e.key.toString().toLowerCase() == k.toLowerCase(),
        orElse: () => const MapEntry('', null),
      );
      if (hit.key.isNotEmpty) {
        final v = hit.value;
        if (v is Map && v.containsKey('amount')) return _asIntSun(v['amount']);
        return _asIntSun(v);
      }
    }
    return 0;
  }

  List<Map<String, dynamic>> _normalizeStakeList(List list) {
    return list.map<Map<String, dynamic>>((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final type = _normalizeType(m['type']?.toString() ?? m['resource']?.toString() ?? m['category']?.toString());
      int amtSun = _pickAmountSun(m);
      if (amtSun == 0 && m['amount_trx'] != null) {
        final trx = (m['amount_trx'] as num?) ?? 0;
        amtSun = (trx * 1e6).toInt();
      }
      final expireMs = _pickExpireMs(m);
      return {
        ...m,
        'type': type,
        'amount_sun': amtSun,
        if (expireMs != null) 'expire_time_ms': expireMs,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _normalizeUnfreezeList(List list) {
    return list.map<Map<String, dynamic>>((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final type = _normalizeType(m['type']?.toString() ?? m['resource']?.toString() ?? m['category']?.toString());
      final amtSun = _pickAmountSun(m);
      final expireMs = _pickExpireMs(m) ?? 0;
      return {
        ...m,
        'type': type,
        'amount_sun': amtSun,
        'expire_time_ms': expireMs,
      };
    }).toList();
  }

  // ---------- Realtime polling ----------
  void _startRealtime() {
    _rt?.cancel();
    _rt = Timer.periodic(_tick, (_) => _refreshFromChain());
  }

  Future<void> _refreshFromChain({bool force = false}) async {
    if (_refreshing) {
      // still tick UI so time-based "matured" recalculations show up
      if (mounted) setState(() {});
      return;
    }
    final since = DateTime.now().difference(_lastFetch);
    if (!force && since < _minGap) {
      if (mounted) setState(() {}); // tick UI
      return;
    }

    _refreshing = true;
    try {
      final res = await Future.wait([
        widget.tron.getAllStakesV2(widget.address),
        widget.tron.getWithdrawableSun(widget.address),
        widget.tron.getAvailableUnfreezeSlots(widget.address),
      ]);

      final map = Map<String, dynamic>.from(res[0] as Map);
      final withdrawable = _asIntSun(res[1]);
      final slots = (res[2] as num?)?.toInt() ?? 0;

      final frozenRaw = (map['frozen'] ?? map['frozenV2'] ?? map['stakes'] ?? map['active'] ?? const []) as List?;
      final unfrozenRaw = (map['unfrozen'] ?? map['unfreeze'] ?? map['queue'] ?? map['pending'] ?? const []) as List?;

      final frozen = _normalizeStakeList(frozenRaw ?? const []);
      final unfrozen = _normalizeUnfreezeList(unfrozenRaw ?? const []);

      int energySun = 0, bandwidthSun = 0;
      for (final e in frozen) {
        final t = (e['type'] as String?) ?? '';
        final a = (e['amount_sun'] as int?) ?? 0;
        if (t == 'ENERGY') energySun += a;
        if (t == 'BANDWIDTH') bandwidthSun += a;
      }

      // Fallback totals via account_resource if needed
      if (energySun == 0 && bandwidthSun == 0) {
        final ar = (map['account_resource'] ?? map['accountResource'] ?? map['resources']) as Map<String, dynamic>?;
        if (ar != null) {
          final bwSum = _asIntSun(ar['frozen_balance_for_bandwidth']) + _asIntSun(ar['delegated_frozen_balance_for_bandwidth']);
          final enSum = _asIntSun(ar['frozen_balance_for_energy']) + _asIntSun(ar['delegated_frozen_balance_for_energy']);
          if (bwSum > 0 || enSum > 0) {
            bandwidthSun = bwSum;
            energySun = enSum;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _stakedEnergySunLive = energySun;
        _stakedBandwidthSunLive = bandwidthSun;
        _availableSlotsLive = slots;
        _withdrawableSunLive = withdrawable;
        _unfrozenLive = unfrozen
          ..sort((a, b) => ((a['expire_time_ms'] ?? 0) as int).compareTo((b['expire_time_ms'] ?? 0) as int));
      });
    } catch (_) {
      // silent; next tick will retry
    } finally {
      _lastFetch = DateTime.now();
      _refreshing = false;
    }
  }

  String get _currentResLabel => _tab.index == 0 ? 'ENERGY' : 'BANDWIDTH';

  List<Map<String, dynamic>> get _tabPending {
    final now = DateTime.now().millisecondsSinceEpoch;
    final filtered = _unfrozenLive.where((e) {
      final type = _normalizeType(e['type']?.toString());
      final expire = (e['expire_time_ms'] as num?)?.toInt() ?? 0;
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
    final frozen = _tab.index == 0 ? _stakedEnergySunLive : _stakedBandwidthSunLive;
    final sun = (frozen * pct).floor();
    _amountCtrl.text = _nf.format(sun / 1e6);
    setState(() {});
  }

  Future<void> _unstake() async {
    final res = _tab.index == 0 ? _Res.ENERGY : _Res.BANDWIDTH;
    final amtTrx = double.tryParse(_amountCtrl.text.trim());
    if (amtTrx == null || amtTrx <= 0) {
      showFloatingSnackBar(context, message: 'Enter a valid amount.', type: SnackBarType.error);
      return;
    }
    final sun = (amtTrx * 1e6).round();
    final frozen = _tab.index == 0 ? _stakedEnergySunLive : _stakedBandwidthSunLive;

    if (sun > frozen) {
      showFloatingSnackBar(
        context,
        message: 'Max available is ${_fmtTrx(frozen)} TRX for ${res.label}.',
        type: SnackBarType.error,
      );
      return;
    }
    if (_availableSlotsLive <= 0) {
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
      message: 'After starting, there’s a ~14-day wait. Once matured, “Withdraw” moves TRX back to your balance.',
      confirmLabel: 'Unstake',
      icon: res.icon,
    );
    if (!ok) return;

    setState(() => _performing = true);
    try {
      final tx = await widget.tron.unfreezeBalanceV2(
        privateKey: widget.pk,
        amountSun: sun,
        resource: res.label,
      );
      final short = tx.length > 10 ? '${tx.substring(0, 6)}…${tx.substring(tx.length - 4)}' : tx;
      showFloatingSnackBar(context, message: 'Unstake started. tx: $short', type: SnackBarType.success);
      // Refresh locally & let parent refresh too
      await _refreshFromChain(force: true);
      widget.onDataChanged?.call();
    } catch (e) {
      showFloatingSnackBar(context, message: e.toString(), type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _performing = false);
    }
  }

  Future<void> _withdraw() async {
    if (_withdrawableSunLive <= 0) {
      showFloatingSnackBar(context, message: 'No matured amount to withdraw yet.', type: SnackBarType.info);
      return;
    }
    final ok = await showConfirmActionSheet(
      context,
      title: 'Withdraw ${_fmtTrx(_withdrawableSunLive)} TRX?',
      message: 'This moves all matured unstakes back to your spendable balance.',
      confirmLabel: 'Withdraw',
      icon: LucideIcons.arrowDownToLine,
    );
    if (!ok) return;

    setState(() => _performing = true);
    try {
      final tx = await widget.tron.withdrawExpireUnfreeze(privateKey: widget.pk);
      final short = tx.length > 10 ? '${tx.substring(0, 6)}…${tx.substring(tx.length - 4)}' : tx;
      showFloatingSnackBar(context, message: 'Withdrawn. tx: $short', type: SnackBarType.success);
      await _refreshFromChain(force: true);
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
      message: 'This cancels every in-progress unstake. Matured amounts can be withdrawn separately.',
      confirmLabel: 'Cancel all',
      icon: LucideIcons.alertTriangle,
      destructive: true,
    );
    if (!ok) return;

    setState(() => _performing = true);
    try {
      final tx = await widget.tron.cancelAllUnfreezeV2(privateKey: widget.pk);
      final short = tx.length > 10 ? '${tx.substring(0, 6)}…${tx.substring(tx.length - 4)}' : tx;
      showFloatingSnackBar(context, message: 'Canceled. tx: $short', type: SnackBarType.success);
      await _refreshFromChain(force: true);
      widget.onDataChanged?.call();
    } catch (e) {
      showFloatingSnackBar(context, message: e.toString(), type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _performing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final frozen = _tab.index == 0 ? _stakedEnergySunLive : _stakedBandwidthSunLive;

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
                  onPressed: _performing ? () {} : _unstake,
                  type: _performing ? ButtonType.disabled : ButtonType.filled,
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
            subtitle: 'Pick a resource tab, then choose how much to unlock from your active stake.',
            leading: LucideIcons.unlock,
            leadingColor: colors.primary,
            children: [
              Row(
                children: [
                  Text('Active stake (available to unstake)',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
                  const Spacer(),
                  Text(_fmtTrx(frozen),
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                _tag(colors, LucideIcons.slidersHorizontal, 'Unstake slots', '$_availableSlotsLive'),
                const SizedBox(width: 8),
                _tag(colors, LucideIcons.arrowDownToLine, 'Withdrawable', _fmtTrx(_withdrawableSunLive)),
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
              Wrap(spacing: 8, runSpacing: 8, children: [
                _pctChip('25%', () => _applyPct(.25)),
                _pctChip('50%', () => _applyPct(.50)),
                _pctChip('75%', () => _applyPct(.75)),
                _pctChip('MAX',  () => _applyPct(1.0)),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.primary.withOpacity(.15)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(LucideIcons.info, size: 18, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Unstake starts a ~14-day timer. When it matures, tap “Withdraw matured” to return TRX to your balance.',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ]),
              ),
            ],
          ),

          // Pending for the CURRENT TAB only (auto-updates)
          if (_tabPending.isNotEmpty) ...[
            const SizedBox(height: 12),
            PendingList(items: _tabPending, formatTrx: _fmtTrx),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: CustomButton(
                  text: 'Withdraw matured',
                  icon: LucideIcons.arrowDownToLine,
                  onPressed: _performing ? () {} : _withdraw,
                  type: _performing ? ButtonType.disabled : ButtonType.outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  text: 'Cancel all',
                  icon: LucideIcons.delete,
                  onPressed: _performing ? () {} : _cancelAll,
                  type: _performing ? ButtonType.disabled : ButtonType.outlined,
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
        Expanded(child: Text(l, style: TextStyle(color: colors.textSecondary, fontSize: 12.5))),
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
