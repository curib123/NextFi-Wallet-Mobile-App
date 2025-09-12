// lib/Provider/CurrencyProvider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';

import 'package:next_fi/Services/currency_secure_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

class CurrencyProvider extends ChangeNotifier {
  CurrencyProvider({
    required StellarWalletService stellar,
    this.httpTimeout = const Duration(seconds: 10),
  }) : _stellar = stellar {
    _client = _buildClient();
    _boot();
  }

  // ── Deps & Config ─────────────────────────────────────────────────────────
  final StellarWalletService _stellar;
  final Duration httpTimeout;

  // ── HTTP client ───────────────────────────────────────────────────────────
  late final IOClient _client;
  IOClient _buildClient() {
    final hc = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 8
      ..findProxy = (_) => 'DIRECT';
    return IOClient(hc);
  }

  // ── State ─────────────────────────────────────────────────────────────────
  String _fiat = 'usd';

  /// USDC→FIAT (≈ USD→FIAT)
  double _usdcRate = 0;

  /// XLM→FIAT (computed as: (USDC per XLM) * (USDC→FIAT))
  double _xlmRate = 0;

  /// Latest USDC per 1 XLM from the service stream
  double _lastUsdcPerXlm = 0;

  bool _loading = true;

  // Streams exposed to UI
  final _xlmCtrl = StreamController<double>.broadcast();
  final _usdcCtrl = StreamController<double>.broadcast();

  // Subscriptions
  StreamSubscription? _pairSub;

  // ── Public API ─────────────────────────────────────────────────────────────
  String get fiat => _fiat;
  bool get loading => _loading;
  double get usdcRate => _usdcRate;
  double get xlmRate => _xlmRate;

  /// Back-compat: price streams for widgets that already listen
  Stream<double> get xlmPriceStream => _xlmCtrl.stream;
  Stream<double> get usdcPriceStream => _usdcCtrl.stream;

  // Histories: keep simple/flat (UI safe). Replace with real series if needed.
  List<double> get xlmHistory24h => _flatHistory(hours: 24, value: _xlmRate);
  List<double> get xlmHistory7   => _flatHistory(days: 7,  value: _xlmRate);
  List<double> get xlmHistory30  => _flatHistory(days: 30, value: _xlmRate);
  List<double> get xlmHistory365 => _flatHistory(days: 365,value: _xlmRate);

  List<double> get usdcHistory24h => _flatHistory(hours: 24, value: _usdcRate);
  List<double> get usdcHistory7   => _flatHistory(days: 7,  value: _usdcRate);
  List<double> get usdcHistory30  => _flatHistory(days: 30, value: _usdcRate);
  List<double> get usdcHistory365 => _flatHistory(days: 365,value: _usdcRate);

  // Simple, stable % deltas (flat series -> 0.0)
  double get xlmPct24h  => 0.0;
  double get xlmPct7d   => 0.0;
  double get xlmPct30d  => 0.0;
  double get xlmPct1y   => 0.0;
  double get usdcPct24h => 0.0;
  double get usdcPct7d  => 0.0;
  double get usdcPct30d => 0.0;
  double get usdcPct1y  => 0.0;

  void setFiat(String v) {
    final n = v.trim().toLowerCase();
    if (n.isEmpty || n == _fiat) return;
    _fiat = n;
    CurrencySecureStorage.saveFiat(n);
    _refreshUsdToFiat(); // recompute USDC→FIAT (and thus XLM→FIAT)
    notifyListeners();
  }

  Future<void> resetFiatToUsd() async {
    _fiat = 'usd';
    await CurrencySecureStorage.clearFiat();
    await _refreshUsdToFiat();
    notifyListeners();
  }

  // Quick converters
  double usdcToFiat(double u) => u * _usdcRate;
  double xlmToFiat(double x)  => x * _xlmRate;
  double fiatToUsdc(double f) => _usdcRate != 0 ? f / _usdcRate : 0.0;
  double fiatToXlm(double f)  => _xlmRate  != 0 ? f / _xlmRate  : 0.0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  void _boot() async {
    try {
      final savedFiat = await CurrencySecureStorage.readFiat();
      if (savedFiat != null && savedFiat.trim().isNotEmpty) {
        _fiat = savedFiat.trim().toLowerCase();
      }
      final cache = await CurrencySecureStorage.readLastGoodRates();
      if (cache != null && (cache['fiat'] as String?)?.toLowerCase() == _fiat) {
        _usdcRate = (cache['usdcRate'] as num?)?.toDouble() ?? _usdcRate;
        _xlmRate  = (cache['xlmRate']  as num?)?.toDouble() ?? _xlmRate;
      }
    } catch (_) {}

    // Subscribe to live XLM/USDC price from your Stellar service
    _pairSub = _stellar.xlmUsdcPriceStream().listen((p) {
      _lastUsdcPerXlm = p.usdcPerXlm;
      _recomputeXlmFiat();
    }, onError: (_) { /* keep last known */ });

    // Fetch initial USDC→FIAT (≈ USD→FIAT)
    await _refreshUsdToFiat();

    _setLoading(false);
  }

  @override
  void dispose() {
    _pairSub?.cancel();
    _xlmCtrl.close();
    _usdcCtrl.close();
    _client.close();
    super.dispose();
  }

  // ── Core logic ────────────────────────────────────────────────────────────
  Future<void> _refreshUsdToFiat() async {
    _setLoading(true);
    try {
      final fx = await _usdToFiat(_fiat) ?? 1.0; // USDC≈USD peg
      _usdcRate = fx;
      _usdcCtrl.add(_usdcRate);
      _recomputeXlmFiat();

      await CurrencySecureStorage.saveLastGoodRates({
        'fiat': _fiat,
        'usdcRate': _usdcRate,
        'xlmRate': _xlmRate,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    } catch (_) {
      // If offline and we have cached rates, keep them.
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void _recomputeXlmFiat() {
    if (_lastUsdcPerXlm > 0 && _usdcRate > 0) {
      _xlmRate = _lastUsdcPerXlm * _usdcRate;
      _xlmCtrl.add(_xlmRate);
      notifyListeners();
    }
  }

  void _setLoading(bool v) {
    if (_loading != v) { _loading = v; notifyListeners(); }
  }

  // ── USD→FIAT helpers (USDC≈USD) ───────────────────────────────────────────
  Future<double?> _usdToFiat(String fiat) async {
    final tgt = fiat.toUpperCase();
    if (tgt == 'USD') return 1.0;

    // Try a few reputable FX sources; first successful wins.
    return _firstNonNull<double>([
          () async {
        final m = await _json(Uri.parse('https://api.frankfurter.app/latest?from=USD&to=$tgt'));
        final v = (m['rates'] as Map?)?[tgt];
        return (v is num) ? v.toDouble() : null;
      },
          () async {
        final m = await _json(Uri.parse('https://api.exchangerate.host/latest?base=USD&symbols=$tgt'));
        final v = (m['rates'] as Map?)?[tgt];
        return (v is num) ? v.toDouble() : null;
      },
          () async {
        final m = await _json(Uri.parse('https://open.er-api.com/v6/latest/USD'));
        final v = (m['rates'] as Map?)?[tgt];
        return (v is num) ? v.toDouble() : null;
      },
    ]);
  }

  // ── Utilities ─────────────────────────────────────────────────────────────
  List<double> _flatHistory({int? hours, int? days, required double value}) {
    final n = hours ?? (days != null ? days : 1);
    final len = hours ?? (days != null ? days : 1);
    final count = hours ?? (days != null ? days : 1);
    final c = hours != null ? hours : (days ?? 1);
    return List<double>.filled(c, value <= 0 ? 1.0 : value);
  }

  Future<Map<String, dynamic>> _json(Uri url) async {
    final resp = await _client
        .get(url, headers: {'User-Agent': 'NextFi/1.0'})
        .timeout(httpTimeout);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final b = resp.body.isEmpty ? '{}' : resp.body;
      final d = jsonDecode(b);
      return d is Map<String, dynamic> ? d : {'_': d};
    }
    throw Exception('HTTP ${resp.statusCode} for $url');
  }

  Future<T?> _firstNonNull<T>(List<Future<T?> Function()> attempts) async {
    for (final f in attempts) {
      try {
        final v = await f();
        if (v != null) return v;
      } catch (_) {}
    }
    return null;
  }
}
