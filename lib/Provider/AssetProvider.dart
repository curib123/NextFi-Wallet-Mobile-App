// lib/Provider/AssetProvider.dart (refactored to avoid redundant fetching)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:next_fi/Model/asset_model.dart';

class AssetProvider with ChangeNotifier {
  AssetProvider({
    String vsCurrency = 'usd',
    Duration requestTimeout = const Duration(seconds: 6),
    Duration minFetchGap = const Duration(seconds: 15), // throttle window
  })  : _vsCurrency = vsCurrency.toLowerCase(),
        _requestTimeout = requestTimeout,
        _minFetchGap = minFetchGap;

  static const String _base = 'https://api.coingecko.com/api/v3';
  String _vsCurrency;
  final Duration _requestTimeout;
  final Duration _minFetchGap;

  // Static list of supported assets (logos + 24h%)
  final List<AssetModel> _assets = <AssetModel>[
    AssetModel(id: 'tron', name: 'Tron', symbol: 'TRX', coingeckoId: 'tron'),
    AssetModel(id: 'tether_trc20', name: 'Tether (TRC20)', symbol: 'USDT', coingeckoId: 'tether'),
  ];

  Map<String, String> _logos = <String, String>{};
  bool _loading = true; // true until first successful fetch

  // Realtime + lifecycle
  Timer? _timer;
  bool _isDisposed = false;
  bool _started = false; // guard startRealtimeUpdates

  // De-dupe & cache
  bool _inFlight = false; // network call in progress
  Completer<void>? _pendingFetch; // coalesce concurrent callers
  DateTime? _lastFetchAt; // last successful (200 or 304) fetch time
  String? _lastEtag; // server-provided ETag for 304 flow

  // Public getters
  List<AssetModel> get assets => _assets;
  Map<String, String> get logos => _logos;
  bool get loading => _loading;
  String get vsCurrency => _vsCurrency;

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }

  // --- Public API -----------------------------------------------------------

  /// Fetch logos and 24h price change for configured assets.
  /// - Coalesces concurrent calls
  /// - Throttles by [_minFetchGap] unless [force] is true
  /// - Uses ETag to avoid downloading unchanged payloads (304)
  Future<void> fetchLogosAndPriceChange({bool force = false}) async {
    // Throttle
    final now = DateTime.now();
    if (!force && _lastFetchAt != null &&
        now.difference(_lastFetchAt!) < _minFetchGap) {
      return; // recent enough
    }

    // Coalesce: if a fetch is already running, just await it
    if (_pendingFetch != null) {
      return _pendingFetch!.future;
    }
    _pendingFetch = Completer<void>();

    if (!_inFlight) {
      _inFlight = true;
      final wasLoading = _loading;
      if (_loading) _safeNotify(); // let UI show spinner on first load

      try {
        final ids = _assets
            .map((a) => a.coingeckoId.trim())
            .where((s) => s.isNotEmpty)
            .join(',');
        if (ids.isEmpty) {
          _loading = false;
          _finishFetch(now);
          return;
        }

        final uri = Uri.parse(
          '$_base/coins/markets?vs_currency=$_vsCurrency&ids=$ids&price_change_percentage=24h',
        );

        final headers = <String, String>{'Accept': 'application/json'};
        if (_lastEtag != null) headers['If-None-Match'] = _lastEtag!;

        final resp = await http
            .get(uri, headers: headers)
            .timeout(_requestTimeout);

        if (resp.statusCode == 304) {
          // Not modified — avoid notify unless we transition from loading
          _loading = false;
          _finishFetch(now, changed: _loading != wasLoading);
          return;
        }

        if (resp.statusCode == 200) {
          _lastEtag = resp.headers['etag'] ?? _lastEtag;
          final List<dynamic> list = json.decode(resp.body) as List<dynamic>;

          // Snapshot current state for diffing
          final Map<String, double> beforePct = {
            for (final a in _assets) a.id: (a.priceChangePercent24h ?? 0.0),
          };
          final Map<String, String> beforeLogos = Map.of(_logos);

          // Build new state
          final Map<String, String> newLogos = <String, String>{};
          for (final item in list) {
            if (item is! Map<String, dynamic>) continue;
            final String cgId = (item['id'] ?? '').toString();
            final String image = (item['image'] ?? '').toString();
            final double pct = _toDouble(item['price_change_percentage_24h_in_currency']) ??
                _toDouble(item['price_change_percentage_24h']) ??
                0.0;

            final idx = _assets.indexWhere((a) => a.coingeckoId == cgId);
            if (idx != -1) {
              _assets[idx].priceChangePercent24h = pct;
              newLogos[_assets[idx].id] = image; // key by our id
            }
          }

          // Diff to avoid redundant notify
          final bool logosChanged = !mapEquals(beforeLogos, newLogos);
          bool pricesChanged = false;
          for (final a in _assets) {
            final before = beforePct[a.id] ?? 0.0;
            final nowPct = a.priceChangePercent24h ?? 0.0;
            if ((before - nowPct).abs() > 0.0001) {
              pricesChanged = true;
              break;
            }
          }

          if (logosChanged) _logos = newLogos;
          _loading = false;
          _finishFetch(now, changed: (logosChanged || pricesChanged) || _loading != wasLoading);
        } else {
          debugPrint('CoinGecko error ${resp.statusCode}: ${resp.body}');
          _loading = false;
          _finishFetch(now, changed: _loading != wasLoading);
        }
      } catch (e) {
        debugPrint('fetchLogosAndPriceChange error: $e');
        _loading = false;
        _finishFetch(now, changed: true); // surface that loading state changed
      } finally {
        _inFlight = false;
      }
    }

    _pendingFetch?.complete();
    _pendingFetch = null;
  }

  /// Starts polling (idempotent). If already running, does nothing.
  void startRealtimeUpdates({Duration interval = const Duration(seconds: 30)}) {
    if (_started) return; // prevent multiple timers if screens rebuild
    _started = true;

    _timer?.cancel();
    unawaited(fetchLogosAndPriceChange(force: true));
    _timer = Timer.periodic(interval, (_) {
      if (!_isDisposed) {
        unawaited(fetchLogosAndPriceChange());
      }
    });
  }

  void stopRealtimeUpdates() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Optionally switch the reference currency at runtime (debounced by throttle).
  Future<void> setVsCurrency(String vs, {bool force = false}) async {
    final next = vs.toLowerCase();
    if (next == _vsCurrency) return;
    _vsCurrency = next;
    await fetchLogosAndPriceChange(force: force);
  }

  // --- Internal -------------------------------------------------------------

  void _finishFetch(DateTime now, {bool changed = false}) {
    _lastFetchAt = now;
    if (changed) _safeNotify();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

void unawaited(Future<void> f) {}
