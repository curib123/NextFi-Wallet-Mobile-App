

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Components/confirm_action_sheet.dart';
import 'package:next_fi/Screen/SendAndReceieveWidgets/shared_widget_send_and_recieve.dart';

import 'package:next_fi/Screen/StakeScreenWidgets/stake_guide_modal.dart';
import 'package:next_fi/Screen/StakeScreenWidgets/stake_widgets.dart';
import 'package:next_fi/Screen/StakeScreenWidgets/stake_v2_screens.dart';
import 'package:next_fi/Screen/StakeScreenWidgets/stake_v2_unstake_screens.dart';

import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron/tron_wallet_service.dart';

class StakeV2MainScreen extends StatefulWidget {
  const StakeV2MainScreen({super.key});
  @override
  State<StakeV2MainScreen> createState() => _StakeV2MainScreenState();
}

class _StakeV2MainScreenState extends State<StakeV2MainScreen> {
  // ---- Services & Wallet ----
  late final TronWalletService _tron;
  Uint8List? _pk;
  String? _addr;

  // ---- UI / State ----
  final _nf = NumberFormat('#,##0.######');
  bool _loading = true;
  String? _error;

  // Spendable + withdrawable (withdrawable computed locally from matured unfreezes)
  int _spendableSun = 0;
  int _withdrawableSun = 0;

  // Stake totals + details (frozen list is filtered to >0 only)
  int _stakedEnergySun = 0;
  int _stakedBandwidthSun = 0;
  int _availableSlots = 0;
  List<Map<String, dynamic>> _frozen = const [];
  List<Map<String, dynamic>> _unfrozen = const [];

  // Resource gauges (from TronWalletService)
  bool _resLoading = true;
  String? _resError;
  int _freeNetLimit = 0, _freeNetUsed = 0, _netLimit = 0, _netUsed = 0;
  int _energyLimit = 0, _energyUsed = 0;

  // ---- Realtime / Throttling ----
  static const Duration _minReloadGap = Duration(seconds: 20);
  static const Duration _minResGapActive = Duration(seconds: 45);
  static const Duration _minResGapIdle   = Duration(minutes: 5);

  static const Duration _slotsTTL = Duration(minutes: 2);
  DateTime _lastSlotsFetchAt = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _pollTimer;
  Timer? _debounceRefresh;
  DateTime _lastReloadAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastResAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _autoRefresh = true;
  StreamSubscription<Map<String, dynamic>>? _incomingSub;
  bool _reloading = false;

  bool get _hasActiveStake => (_stakedEnergySun + _stakedBandwidthSun) > 0;

  @override
  void initState() {
    super.initState();
    _tron = TronWalletService(const TronClientConfig(), logger: (m) {});
    _initWallet();
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _pollTimer?.cancel();
    _debounceRefresh?.cancel();
    _tron.dispose();
    super.dispose();
  }

  String _fmtTrx(int sun) => _nf.format(sun / 1e6);
  String _short(String s) => s.length <= 10 ? s : '${s.substring(0, 6)}…${s.substring(s.length - 4)}';

  /* ========================= Init + Realtime ========================= */

  Future<void> _initWallet() async {
    try {
      final mn = await SeedStorage.getSeed();
      if (!mounted) return;
      if (mn == null || mn.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final pk = TronWalletService.derivePrivateKey(mn);
      final addr = TronWalletService.tronAddressFromMnemonic(mn);

      setState(() {
        _pk = pk;
        _addr = addr;
      });

      await Future.wait([_reload(), _fetchResources()]);
      _startRealtime();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load wallet';
        _loading = false;
      });
    }
  }

  void _startRealtime() {
    _pollTimer?.cancel();
    _incomingSub?.cancel();

    if (!_autoRefresh || _addr == null) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) => _tickRealtime());

    try {
      _incomingSub = _tron
          .watchIncoming(_addr!, interval: const Duration(seconds: 12), pageLimit: 20)
          .listen((_) => _scheduleImmediateRefresh());
    } catch (_) {}
  }

  Future<void> _tickRealtime() async {
    if (!mounted || _addr == null) return;
    final now = DateTime.now();

    if (now.difference(_lastReloadAt) >= _minReloadGap) {
      await _reload();
      _lastReloadAt = DateTime.now();
    }

    final resGap = _hasActiveStake ? _minResGapActive : _minResGapIdle;
    if (now.difference(_lastResAt) >= resGap) {
      await _fetchResources();
      _lastResAt = DateTime.now();
    }
  }

  void _scheduleImmediateRefresh({Duration delay = const Duration(milliseconds: 800)}) {
    _debounceRefresh?.cancel();
    _debounceRefresh = Timer(delay, () async {
      await _reload();
      if (!mounted) return;
      final resGap = _hasActiveStake ? _minResGapActive : _minResGapIdle;
      if (DateTime.now().difference(_lastResAt) >= resGap) {
        await _fetchResources();
        _lastResAt = DateTime.now();
      }
    });
  }

  /* ========================= Core Reloads (lean requests) ========================= */

  Future<void> _reload() async {
    if (_addr == null || _reloading) return;
    _reloading = true;
    if (mounted) setState(() => _loading = true);

    try {
      final addr = _addr!;

      final results = await Future.wait([
        _tron.getTrxBalance(addr),   // int sun
        _tron.getAllStakesV2(addr),  // {frozen[], unfrozen[], ...}
      ]);

      final spendableSun = (results[0] as num).toInt();
      final stakeMap = (results[1] as Map).cast<String, dynamic>();
      final frozenRaw = ((stakeMap['frozen'] as List?) ?? const []).cast<Map<String, dynamic>>();
      final unfrozenRaw = ((stakeMap['unfrozen'] as List?) ?? const []).cast<Map<String, dynamic>>();

      // Keep only positive-amount active stakes
      final frozen = [
        for (final m in frozenRaw)
          if (((m['amount_sun'] as num?)?.toInt() ?? 0) > 0) m
      ];

      int energySun = 0, bandwidthSun = 0;
      for (final m in frozen) {
        final t = ((m['type'] ?? '') as String).toUpperCase();
        final a = (m['amount_sun'] as num?)?.toInt() ?? 0;
        if (t == 'ENERGY') energySun += a;
        if (t == 'BANDWIDTH') bandwidthSun += a;
      }

      frozen.sort((a, b) => (a['type'] as String).compareTo(b['type'] as String));
      unfrozenRaw.sort((a, b) => ((a['expire_time_ms'] as num?)?.toInt() ?? 0)
          .compareTo((b['expire_time_ms'] as num?)?.toInt() ?? 0));

      // Compute withdrawable from matured only
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      int withdrawable = 0;
      for (final u in unfrozenRaw) {
        final ms = (u['expire_time_ms'] as num?)?.toInt() ?? 0;
        final amt = (u['amount_sun'] as num?)?.toInt() ?? 0;
        if (ms > 0 && ms <= nowMs && amt > 0) withdrawable += amt;
      }

      // Fetch slots rarely and only if useful
      int slots = _availableSlots;
      final needsSlots = (energySun + bandwidthSun) > 0 || unfrozenRaw.isNotEmpty;
      if (needsSlots && DateTime.now().difference(_lastSlotsFetchAt) >= _slotsTTL) {
        try {
          slots = (await _tron.getAvailableUnfreezeSlots(addr) as num).toInt();
          _lastSlotsFetchAt = DateTime.now();
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _spendableSun = spendableSun;
        _withdrawableSun = withdrawable;
        _availableSlots = slots;
        _stakedEnergySun = energySun;
        _stakedBandwidthSun = bandwidthSun;
        _frozen = frozen;
        _unfrozen = unfrozenRaw;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      _reloading = false;
    }
  }

  /* ========================= Resource Gauges (via TronWalletService) ========================= */

  Future<void> _fetchResources() async {
    final addr = _addr ?? '';
    if (addr.isEmpty) {
      if (!mounted) return;
      setState(() {
        _resLoading = false;
        _resError = 'Wallet not loaded';
      });
      return;
    }

    if (mounted) setState(() { _resLoading = true; _resError = null; });

    try {
      // NOTE: These method names assume you exposed wrappers in TronWalletService.
      // If yours are named differently, just rename the two calls below.
      final net = (await _tron.getAccountNet(addr)) as Map<String, dynamic>;
      final res = (await _tron.getAccountResource(addr)) as Map<String, dynamic>;

      _freeNetLimit = (net['freeNetLimit'] as num?)?.toInt() ?? 0;
      _freeNetUsed  = (net['freeNetUsed']  as num?)?.toInt() ?? 0;
      _netLimit     = (net['NetLimit']     as num?)?.toInt() ?? 0;
      _netUsed      = (net['NetUsed']      as num?)?.toInt() ?? 0;

      _energyLimit  = (res['EnergyLimit']  as num?)?.toInt() ?? 0;
      _energyUsed   = (res['EnergyUsed']   as num?)?.toInt() ?? 0;

      if (!mounted) return;
      setState(() => _resLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resError = 'Failed to load resources';
        _resLoading = false;
      });
    }
  }

  /* ========================= UI Actions ========================= */

  Future<void> _withdrawMatured() async {
    if (_pk == null) return;
    if (_withdrawableSun <= 0) {
      showFloatingSnackBar(context, message: 'No matured amount to withdraw.', type: SnackBarType.info);
      return;
    }
    final ok = await showConfirmActionSheet(
      context,
      title: 'Withdraw ${_fmtTrx(_withdrawableSun)} TRX?',
      message: 'This will move all matured unstakes back to your spendable balance.',
      confirmLabel: 'Withdraw',
      icon: LucideIcons.arrowDownToLine,
    );
    if (!ok) return;

    try {
      final tx = await _tron.withdrawExpireUnfreeze(privateKey: _pk!);
      showFloatingSnackBar(context, message: 'Withdrawn. tx: ${_short(tx)}', type: SnackBarType.success);
      _scheduleImmediateRefresh();
    } catch (e) {
      showFloatingSnackBar(context, message: e.toString(), type: SnackBarType.error);
    }
  }

  Future<void> _openStakeGuide() => showStakeGuideSheet(context);

  /* ========================= Build ========================= */

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final matured = _unfrozen.where((e) {
      final ms  = (e['expire_time_ms'] as num?)?.toInt() ?? 0;
      final amt = (e['amount_sun'] as num?)?.toInt() ?? 0;
      return ms > 0 && ms <= nowMs && amt > 0;
    }).toList();

    final pending = _unfrozen.where((e) {
      final ms  = (e['expire_time_ms'] as num?)?.toInt() ?? 0;
      final amt = (e['amount_sun'] as num?)?.toInt() ?? 0;
      return ms > nowMs && amt > 0;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stake 2.0'),
        actions: [
          IconButton(
            tooltip: _autoRefresh ? 'Auto-refresh: ON' : 'Auto-refresh: OFF',
            icon: Icon(_autoRefresh ? LucideIcons.radio : LucideIcons.radioReceiver),
            onPressed: () {
              setState(() => _autoRefresh = !_autoRefresh);
              if (_autoRefresh) { _startRealtime(); } else { _pollTimer?.cancel(); _incomingSub?.cancel(); }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loading ? null : () async {
              await _reload();
              final resGap = _hasActiveStake ? _minResGapActive : _minResGapIdle;
              if (DateTime.now().difference(_lastResAt) >= resGap) {
                await _fetchResources();
                _lastResAt = DateTime.now();
              }
            },
          ),
          IconButton(
            tooltip: 'Staking Guide (2.0)',
            icon: const Icon(LucideIcons.info),
            onPressed: _openStakeGuide,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _reload();
          final resGap = _hasActiveStake ? _minResGapActive : _minResGapIdle;
          if (DateTime.now().difference(_lastResAt) >= resGap) {
            await _fetchResources();
            _lastResAt = DateTime.now();
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.error.withOpacity(0.25)),
                ),
                child: Text(_error!, style: TextStyle(color: colors.error)),
              ),

            SectionCard(
              title: 'Overview',
              subtitle: 'Your spendable balance and on-chain resources.',
              leading: LucideIcons.wallet,
              leadingColor: colors.primary,
              children: [
                _loading
                    ? const Row(children: [
                  SizedBox(height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Syncing…'),
                ])
                    : StatRow(icon: LucideIcons.coins, label: 'Spendable TRX', value: _fmtTrx(_spendableSun)),
              ],
            ),

            const SizedBox(height: 12),
            ResourcesCard(
              loading: _resLoading,
              errorText: _resError,
              onRetry: _fetchResources,
              energyUsed: _energyUsed,
              energyLimit: _energyLimit,
              bandwidthUsed: _freeNetUsed + _netUsed,
              bandwidthLimit: _freeNetLimit + _netLimit,
              colors: colors,
              showGuide: false,
              showEnergy: true,
              showBandwidth: true,
              showActions: false,
            ),

            if (!_loading && _frozen.isNotEmpty) ...[
              const SizedBox(height: 12),
              StakedList(items: _frozen, formatTrx: _fmtTrx),
            ],

            if (!_loading && matured.isNotEmpty) ...[
              const SizedBox(height: 12),
              ReadyList(items: matured, formatTrx: _fmtTrx, onWithdrawAll: _withdrawMatured),
            ],

            if (!_loading && pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              PendingList(items: pending, formatTrx: _fmtTrx),
            ],

            if (!_loading && _frozen.isEmpty && matured.isEmpty && pending.isEmpty) ...[
              const SizedBox(height: 12),
              Text('No stakes yet. Tap “Stake” to begin.', style: TextStyle(color: colors.textSecondary)),
            ],

            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: CustomButton(
                  text: 'Stake',
                  icon: LucideIcons.lock,
                  onPressed: (_pk == null || _addr == null || _loading)
                      ? () => showFloatingSnackBar(context, message: 'Wallet not ready', type: SnackBarType.error)
                      : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StakeV2StakeScreen(
                        tron: _tron,
                        pk: _pk!,
                        address: _addr!,
                        spendableSun: _spendableSun,
                      ),
                    ),
                  ).then((_) => _scheduleImmediateRefresh()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  text: 'Unstake',
                  type: ButtonType.outlined,
                  icon: LucideIcons.unlock,
                  onPressed: (_pk == null || _addr == null || _loading)
                      ? () => showFloatingSnackBar(context, message: 'Wallet not ready', type: SnackBarType.error)
                      : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StakeV2UnstakeScreen(
                        tron: _tron,
                        pk: _pk!,
                        address: _addr!,
                        stakedEnergySun: _stakedEnergySun,
                        stakedBandwidthSun: _stakedBandwidthSun,
                        availableSlots: _availableSlots,
                        withdrawableSun: _withdrawableSun,
                        unfrozen: _unfrozen,
                        onDataChanged: () => _scheduleImmediateRefresh(),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
