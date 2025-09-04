// lib/Screen/StakeScreenWidgets/stake_v2_main_screen.dart
//
// Realtime auto-refresh added:
// - Periodic poller with throttling (_minReloadGap/_minResGap)
// - Debounced "immediate" refresh scheduler for bursts
// - Clean teardown in dispose()
// - Manual refresh still works
//
// NOTE: If your TronWalletService exposes a `watchIncoming(...)` stream,
// you can hook it in _startRealtime() (see commented section).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
import 'package:next_fi/Services/tron_wallet_service.dart';

class StakeV2MainScreen extends StatefulWidget {
  const StakeV2MainScreen({super.key});

  @override
  State<StakeV2MainScreen> createState() => _StakeV2MainScreenState();
}

class _StakeV2MainScreenState extends State<StakeV2MainScreen> {
  late final TronWalletService _tron;
  Uint8List? _pk;
  String? _addr;

  final _nf = NumberFormat('#,##0.######');
  bool _loading = true;
  bool _reloading = false; // prevent overlapping reloads
  String? _error;

  int _spendableSun = 0;
  int _withdrawableSun = 0;

  // Active stake totals & slots (passable to Unstake screen)
  int _stakedEnergySun = 0;
  int _stakedBandwidthSun = 0;
  int _availableSlots = 0;

  List<Map<String, dynamic>> _frozen = const [];
  List<Map<String, dynamic>> _unfrozen = const [];

  // ResourcesCard state
  static const String _baseUrl = 'https://api.trongrid.io';
  bool _resLoading = true;
  String? _resError;
  int _freeNetLimit = 0, _freeNetUsed = 0, _netLimit = 0, _netUsed = 0;
  int _energyLimit = 0, _energyUsed = 0;

  /* ========================= Realtime (auto-refresh) ========================= */
  // Throttling / cadence
  static const Duration _minReloadGap = Duration(seconds: 20); // balances & stakes
  static const Duration _minResGap = Duration(seconds: 45);    // resource gauges

  Timer? _pollTimer;
  Timer? _debounceRefresh;
  DateTime _lastReloadAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastResAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _autoRefresh = true;

  // Optional: if your service offers incoming tx watcher (commented out to avoid compile issues)
  // StreamSubscription? _incomingSub;

  @override
  void initState() {
    super.initState();
    _tron = TronWalletService(const TronClientConfig(), logger: (m) {});
    _loadWallet();
  }

  @override
  void dispose() {
    _tron.dispose();
    _pollTimer?.cancel();
    _debounceRefresh?.cancel();
    // _incomingSub?.cancel();
    super.dispose();
  }

  String _fmtTrx(int sun) => _nf.format(sun / 1e6);
  String _short(String s) => s.length <= 10 ? s : '${s.substring(0, 6)}…${s.substring(s.length - 4)}';

  /* ========================= Wallet Load + Realtime start ========================= */

  Future<void> _loadWallet() async {
    final mn = await SeedStorage.getSeed();
    if (!mounted) return;
    if (mn == null || mn.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final pk = TronWalletService.derivePrivateKey(mn);
      final pub = TronWalletService.publicKeyFromPrivateKey(pk);
      final addr = TronWalletService.tronAddressFromPublicKey(pub);
      setState(() {
        _pk = pk;
        _addr = addr;
      });
      // First load
      await Future.wait([_reload(), _fetchResources()]);
      // Then start realtime loop
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
    if (!_autoRefresh || _addr == null) return;

    // Periodic poller (gentle cadence)
    _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) => _tickRealtime());

    // Optional: hook to incoming watcher for instant updates (uncomment & adapt signature)
    /*
    try {
      _incomingSub?.cancel();
      _incomingSub = _tron.watchIncoming(
        address: _addr!,
        tokens: const ['TRX', 'USDT'],
        onEvent: (dynamic _) => _scheduleImmediateRefresh(),
      );
    } catch (_) {
      // watcher not available; polling still keeps UI fresh
    }
    */
  }

  Future<void> _tickRealtime() async {
    if (!mounted || _addr == null) return;
    final now = DateTime.now();

    if (now.difference(_lastReloadAt) >= _minReloadGap) {
      await _reload();
      _lastReloadAt = DateTime.now(); // after await to reflect completion time
    }
    if (now.difference(_lastResAt) >= _minResGap) {
      await _fetchResources();
      _lastResAt = DateTime.now();
    }
  }

  void _scheduleImmediateRefresh({Duration delay = const Duration(milliseconds: 800)}) {
    _debounceRefresh?.cancel();
    _debounceRefresh = Timer(delay, () async {
      await _reload();
      await _fetchResources();
      _lastReloadAt = DateTime.now();
      _lastResAt = DateTime.now();
    });
  }

  /* ========================= Core Reloads ========================= */

  Future<void> _reload() async {
    final addr = _addr;
    if (addr == null) return;
    if (_reloading) return; // prevent overlaps
    _reloading = true;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _tron.getTrxBalance(addr),
        _tron.getAllStakesV2(addr),
        _tron.getWithdrawableSun(addr),
        _tron.getAvailableUnfreezeSlots(addr),
      ]);

      final spendableSun = _asIntSun(results[0]);
      final stakeMap = Map<String, dynamic>.from(results[1] as Map);
      final withdrawable = _asIntSun(results[2]);
      final slots = (results[3] as num?)?.toInt() ?? 0;

      final frozenRaw = (stakeMap['frozen'] ??
          stakeMap['frozenV2'] ??
          stakeMap['stakes'] ??
          stakeMap['active'] ??
          const []) as List?;
      final unfrozenRaw = (stakeMap['unfrozen'] ??
          stakeMap['unfreeze'] ??
          stakeMap['queue'] ??
          stakeMap['pending'] ??
          const []) as List?;

      final frozen = _normalizeStakeList(frozenRaw ?? const []);
      final unfrozen = _normalizeUnfreezeList(unfrozenRaw ?? const []);

      frozen.sort((a, b) => (a['type'] as String).compareTo(b['type'] as String));
      unfrozen.sort((a, b) => ((a['expire_time_ms'] ?? 0) as int).compareTo((b['expire_time_ms'] ?? 0) as int));

      int energySun = 0, bandwidthSun = 0;
      for (final e in frozen) {
        final amt = (e['amount_sun'] as int?) ?? 0;
        final t = (e['type'] as String?) ?? '';
        if (t == 'ENERGY') {
          energySun += amt;
        } else if (t == 'BANDWIDTH') {
          bandwidthSun += amt;
        }
      }

      if (energySun == 0 && bandwidthSun == 0) {
        final ar = (stakeMap['account_resource'] ??
            stakeMap['accountResource'] ??
            stakeMap['resources']) as Map<String, dynamic>?;
        if (ar != null) {
          final bwDirect = _asIntSun(ar['frozen_balance_for_bandwidth']);
          final bwDeleg = _asIntSun(ar['delegated_frozen_balance_for_bandwidth']);
          final enDirect = _asIntSun(ar['frozen_balance_for_energy']);
          final enDeleg = _asIntSun(ar['delegated_frozen_balance_for_energy']);
          final bwSum = bwDirect + bwDeleg;
          final enSum = enDirect + enDeleg;
          if (bwSum > 0 || enSum > 0) {
            bandwidthSun = bwSum;
            energySun = enSum;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _spendableSun = spendableSun;
        _withdrawableSun = withdrawable;
        _availableSlots = slots;
        _stakedEnergySun = energySun;
        _stakedBandwidthSun = bandwidthSun;
        _frozen = frozen;
        _unfrozen = unfrozen;
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

  int _asIntSun(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _normalizeType(dynamic raw) {
    final s = (raw ?? '').toString().toUpperCase();
    if (s == 'NET') return 'BANDWIDTH';
    if (s == 'BANDWIDTH' || s == 'ENERGY') return s;
    if (s.contains('BAND')) return 'BANDWIDTH';
    if (s.contains('ENERG')) return 'ENERGY';
    return 'BANDWIDTH';
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
      'amount_sun',
      'amount',
      'balance',
      'value',
      'sun',
      'frozen_balance',
      'frozenBalance',
      'frozen_balance_for_energy',
      'delegated_frozen_balance_for_energy',
      'frozen_balance_for_bandwidth',
      'delegated_frozen_balance_for_bandwidth',
      'balance_sun',
      'stake_amount',
      'amountSun',
      'amountSUN',
      'unfreeze_amount',
      'unfrozen_amount',
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
      final type = _normalizeType(m['type'] ?? m['resource'] ?? m['category']);
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
      final type = _normalizeType(m['type'] ?? m['resource'] ?? m['category']);
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

    if (mounted) {
      setState(() {
        _resLoading = true;
        _resError = null;
      });
    }

    try {
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({'address': addr, 'visible': true});

      // Bandwidth
      final netUri = Uri.parse('$_baseUrl/wallet/getaccountnet');
      final netRes = await http
          .post(netUri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
      if (netRes.statusCode != 200) {
        throw Exception('getaccountnet ${netRes.statusCode}');
      }
      final netJ = jsonDecode(netRes.body) as Map<String, dynamic>;
      _freeNetLimit = (netJ['freeNetLimit'] as num?)?.toInt() ?? 0;
      _freeNetUsed = (netJ['freeNetUsed'] as num?)?.toInt() ?? 0;
      _netLimit = (netJ['NetLimit'] as num?)?.toInt() ?? 0;
      _netUsed = (netJ['NetUsed'] as num?)?.toInt() ?? 0;

      // Energy
      final resUri = Uri.parse('$_baseUrl/wallet/getaccountresource');
      final resRes = await http
          .post(resUri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
      if (resRes.statusCode != 200) {
        throw Exception('getaccountresource ${resRes.statusCode}');
      }
      final resJ = jsonDecode(resRes.body) as Map<String, dynamic>;
      _energyLimit = (resJ['EnergyLimit'] as num?)?.toInt() ?? 0;
      _energyUsed = (resJ['EnergyUsed'] as num?)?.toInt() ?? 0;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resError = 'Failed to load resources';
      });
    } finally {
      if (mounted) {
        setState(() => _resLoading = false);
      }
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
      // immediate refresh, but debounced to protect rate limits if chained
      _scheduleImmediateRefresh();
    } catch (e) {
      showFloatingSnackBar(context, message: e.toString(), type: SnackBarType.error);
    }
  }

  // put these in your State class
  void _openStakeGuide() {
    _doOpenStakeGuide(); // don't await inside onPressed
  }

  Future<void> _doOpenStakeGuide() async {
    await showStakeGuideSheet(context); // returns StakeGuideChoice.v2 or null
  }

  /* ========================= Build ========================= */

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    // Split unmatured vs matured
    final now = DateTime.now().millisecondsSinceEpoch;
    final matured = _unfrozen.where((e) {
      final ms = (e['expire_time_ms'] as num?)?.toInt() ?? 0;
      return ms > 0 && ms <= now;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stake 2.0'),
        actions: [

        // Toggle auto-refresh (optional)
          IconButton(
            tooltip: _autoRefresh ? 'Auto-refresh: ON' : 'Auto-refresh: OFF',
            icon: Icon(_autoRefresh ? LucideIcons.radio : LucideIcons.radioReceiver),
            onPressed: () {
              setState(() => _autoRefresh = !_autoRefresh);
              if (_autoRefresh) {
                _startRealtime();
              } else {
                _pollTimer?.cancel();
                // _incomingSub?.cancel();
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loading
                ? null
                : () async {
              await _reload();
              await _fetchResources();
              _lastReloadAt = DateTime.now();
              _lastResAt = DateTime.now();
            },
          ),
          IconButton(
            tooltip: 'Staking Guide (2.0)',
            icon: const Icon(LucideIcons.info),
            onPressed: () {
              // sync wrapper to satisfy VoidCallback
              _openStakeGuide();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _reload();
          await _fetchResources();
          _lastReloadAt = DateTime.now();
          _lastResAt = DateTime.now();
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
              ReadyList(
                items: matured,
                formatTrx: _fmtTrx,
                onWithdrawAll: _withdrawMatured,
              ),
            ],

            if (!_loading && _unfrozen.isNotEmpty) ...[
              const SizedBox(height: 12),
              PendingList(items: _unfrozen, formatTrx: _fmtTrx),
            ],

            if (!_loading && _frozen.isEmpty && _unfrozen.isEmpty) ...[
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
                        // pass all data so Unstake does NO fetch:
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
