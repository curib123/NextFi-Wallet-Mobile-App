import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/app/env/app_env.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/app/viewmodels/currency_math.dart';
import 'package:next_fi/core/services/base_url/base_url.dart';
import 'package:next_fi/core/services/secure_storage/currency_secure_storage.dart';
import 'package:next_fi/core/services/stellar/stellar_wallet_services.dart';

enum _AssetPricingKind { xlm, usdStable, unsupported }

enum _AssetHistorySelection { h24, d7, d30, y1, all }

class _TimedPricePoint {
  const _TimedPricePoint({required this.at, required this.price});

  final DateTime at;
  final double price;
}

class _FxSourceQuote {
  const _FxSourceQuote({required this.source, required this.value});

  final String source;
  final double value;
}

class CurrencyVM extends ChangeNotifier {
  CurrencyVM({
    required StellarWalletServices stellar,
    this.httpTimeout = const Duration(seconds: 10),
    this.rateCacheDuration = const Duration(minutes: 5),
    this.historyCacheDuration = const Duration(hours: 1),
  }) : _stellar = stellar {
    _client = _buildClient();
    _boot();
  }

  final StellarWalletServices _stellar;
  final Duration httpTimeout;
  final Duration rateCacheDuration;
  final Duration historyCacheDuration;

  static const int _maxHistoryDays = 5000;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);
  static const String _userAgent = 'NextFi/2.0';
  static const double _maxFxSpreadPct = 3.0;
  static const double _maxSingleSourceJumpPct = 20.0;
  static const Duration _coinGeckoRateLimitCooldown = Duration(minutes: 3);
  static const Duration _backendWalletSummaryCacheTtl = Duration(seconds: 10);

  static const int _maxResponseBytes = 10 * 1024 * 1024;

  static const List<String> currencyFontFallback = <String>[
    'Roboto',
    '.SF Pro Text',
    'Segoe UI',
    'Segoe UI Symbol',
    'Noto Sans',
    'Noto Sans Symbols',
    'Noto Sans Symbols2',
    'Arial Unicode MS',
    'Arial',
  ];

  static const Map<String, String> _symbolOverrides = <String, String>{
    'USD': r'$',
    'EUR': '€',
    'GBP': 'GBP',
    'JPY': 'JPY',
    'CNY': 'CNY',
    'KRW': '₩',
    'PHP': '₱',
    'THB': '฿',
    'VND': '₫',
    'IDR': 'Rp',
    'INR': '₹',
    'RUB': '₽',
    'AUD': r'$',
    'CAD': r'$',
    'NZD': r'$',
    'SGD': r'$',
    'HKD': r'$',
    'TWD': r'$',
    'MYR': 'RM',
    'AED': 'د.إ',
    'SAR': '﷼',
    'QAR': 'ر.ق',
    'KWD': 'د.ك',
    'BHD': 'د.ب',
    'OMR': 'ر.ع.',
    'ZAR': 'R',
    'BRL': 'R\$',
    'MXN': r'$',
    'NGN': '₦',
    'EGP': 'EGP',
    'TRY': '₺',
  };

  late final IOClient _client;
  bool _disposed = false;

  IOClient _buildClient() {
    final hc = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 8
      ..findProxy = (_) => 'DIRECT';
    return IOClient(hc);
  }

  String _fiat = 'usd';
  String? _ratesForFiat = 'usd';

  double _usdcRate = 0;

  double _xlmRate = 0;

  double _lastUsdcPerXlm = 0;

  bool _loading = true;

  bool _ratesUnavailable = false;
  bool _usingFallbackRates = false;

  DateTime? _lastRateRefresh;
  DateTime? _lastHistoryRefresh;

  Map<String, dynamic>? _lastGoodRatesCache;
  List<double>? _lastGoodHistoryCache;
  Map<String, dynamic>? _backendWalletSummaryCache;
  DateTime? _backendWalletSummaryAt;
  Future<Map<String, dynamic>>? _backendWalletSummaryInFlight;

  final _xlmCtrl = StreamController<double>.broadcast();
  final _usdcCtrl = StreamController<double>.broadcast();

  StreamSubscription<dynamic>? _pairSub;
  bool _isOnline = true;
  bool _reconnectRecoveryInFlight = false;

  List<double> _xlmHist24h = const [];
  List<double> _xlmHist7 = const [];
  List<double> _xlmHist30 = const [];
  List<double> _xlmHist365 = const [];
  List<double> _xlmHistAll = const [];

  final Map<String, double> _assetUsdPriceById = {};
  final Map<String, List<double>> _assetUsdHistoryById = {};
  final Map<String, DateTime> _assetUsdPriceAt = {};
  final Map<String, DateTime> _assetUsdHistoryAt = {};
  final Set<String> _assetPriceLoadsInFlight = <String>{};
  final Set<String> _assetHistoryLoadsInFlight = <String>{};
  DateTime? _coinGeckoRateLimitedUntil;

  static const Duration _assetPriceCacheTtl = Duration(minutes: 10);
  static const Duration _assetHistoryCacheTtl = Duration(hours: 6);

  static const int _maxConsecutiveErrors = 3;
  int _streamConsecutiveErrors = 0;

  String get fiat => _fiat;
  String get fiatCode => _fiat.toUpperCase();

  String get fiatSymbol {
    final code = fiatCode;
    final override = _symbolOverrides[code];
    if (override != null && override.trim().isNotEmpty) return override;
    try {
      final sym = NumberFormat.simpleCurrency(name: code).currencySymbol.trim();
      if (sym.isEmpty || sym == 'CUR') return code;
      return sym;
    } catch (_) {
      return code;
    }
  }

  String get fiatSymbolMaybeCode {
    final s = fiatSymbol.trim();
    return s.toUpperCase() == fiatCode ? fiatCode : s;
  }

  bool get loading => _loading;

  bool get ratesUnavailable => _ratesUnavailable;
  bool get usingFallbackRates => _usingFallbackRates;

  double get usdcRate => _usdcRate;
  double get xlmRate => _xlmRate;
  double get lastUsdcPerXlm => _lastUsdcPerXlm;

  Stream<double> get xlmPriceStream => _xlmCtrl.stream;
  Stream<double> get usdcPriceStream => _usdcCtrl.stream;

  List<double> get xlmHistory24h => List.unmodifiable(_xlmHist24h);
  List<double> get xlmHistory7 => List.unmodifiable(_xlmHist7);
  List<double> get xlmHistory30 => List.unmodifiable(_xlmHist30);
  List<double> get xlmHistory365 => List.unmodifiable(_xlmHist365);
  List<double> get xlmHistoryAll => List.unmodifiable(_xlmHistAll);

  List<double> get usdcHistory24h =>
      List<double>.filled(2, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory7 =>
      List<double>.filled(7, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory30 =>
      List<double>.filled(30, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory365 =>
      List<double>.filled(365, _usdcRate <= 0 ? 1.0 : _usdcRate);

  double get xlmPct24h => _pct(_xlmHist24h);
  double get xlmPct7d => _pct(_xlmHist7);
  double get xlmPct30d => _pct(_xlmHist30);
  double get xlmPct1y => _pct(_xlmHist365);
  double get xlmPctAll => _pct(_xlmHistAll);

  double get usdcPct24h => 0.0;
  double get usdcPct7d => 0.0;
  double get usdcPct30d => 0.0;
  double get usdcPct1y => 0.0;

  bool get hasValidRateCache =>
      _lastRateRefresh != null &&
      DateTime.now().toUtc().difference(_lastRateRefresh!) < rateCacheDuration;

  bool get hasValidHistoryCache =>
      _lastHistoryRefresh != null &&
      DateTime.now().toUtc().difference(_lastHistoryRefresh!) <
          historyCacheDuration;

  Future<void> setFiat(String v) async {
    final n = v.trim().toLowerCase();
    if (n.isEmpty || n == _fiat) return;
    _fiat = n;
    _ratesForFiat = null;
    _usdcRate = 0;
    _xlmRate = 0;
    _ratesUnavailable = true;
    _usingFallbackRates = false;
    await CurrencySecureStorage.saveFiat(n);
    _lastRateRefresh = null;
    await _refreshUsdToFiat(force: true);
    notifyListeners();
  }

  Future<void> resetFiatToUsd() async {
    _fiat = 'usd';
    _ratesForFiat = null;
    _usdcRate = 0;
    _xlmRate = 0;
    _ratesUnavailable = true;
    _usingFallbackRates = false;
    _lastRateRefresh = null;
    await CurrencySecureStorage.clearFiat();
    await _refreshUsdToFiat(force: true);
    notifyListeners();
  }

  Future<void> refreshRates({bool force = false}) async {
    if (!force && hasValidRateCache) {
      debugPrint('CurrencyVM: Using cached rates');
      return;
    }
    await _refreshUsdToFiat(force: force);
  }

  Future<void> refreshHistory({bool force = false}) async {
    if (!force && hasValidHistoryCache) {
      debugPrint('CurrencyVM: Using cached history');
      return;
    }
    await _refreshXlmHistoriesWithFallbacks(force: force);
  }

  void handleConnectivityChanged({
    required bool isOnline,
    bool justReconnected = false,
  }) {
    final wasOnline = _isOnline;
    _isOnline = isOnline;

    if (!isOnline) return;

    final shouldRecover =
        justReconnected || (!wasOnline && isOnline) || _ratesUnavailable;
    if (!shouldRecover || _reconnectRecoveryInFlight) return;

    unawaited(_recoverAfterReconnect());
  }

  NumberFormat fiatFormatter({int? decimalDigits}) =>
      NumberFormat.simpleCurrency(name: fiatCode, decimalDigits: decimalDigits);

  String formatFiat(double amount, {int? decimalDigits}) {
    final safe = CurrencyMath.sanitize(amount);
    return fiatFormatter(decimalDigits: decimalDigits).format(safe);
  }

  String formatFiatWithCode(double amount, {int? decimalDigits}) {
    final safe = CurrencyMath.sanitize(amount);
    final number = NumberFormat.currency(
      name: '',
      symbol: '',
      decimalDigits: decimalDigits,
    ).format(safe).trim();
    return '$fiatSymbol $fiatCode $number';
  }

  String formatSignedFiat(double amount, {int? decimalDigits}) {
    final formatted = formatFiat(amount.abs(), decimalDigits: decimalDigits);
    return amount >= 0 ? '+$formatted' : '-$formatted';
  }

  double usdcToFiat(double u) => (u.isFinite && !u.isNaN) ? u * _usdcRate : 0.0;

  double xlmToFiat(double x) => (x.isFinite && !x.isNaN) ? x * _xlmRate : 0.0;

  double fiatToUsdc(double f) =>
      (f.isFinite && !f.isNaN && _usdcRate > 0) ? f / _usdcRate : 0.0;

  double fiatToXlm(double f) =>
      (f.isFinite && !f.isNaN && _xlmRate > 0) ? f / _xlmRate : 0.0;

  bool supportsAssetPricing(AssetModel asset) =>
      _pricingKindForAsset(asset) != _AssetPricingKind.unsupported ||
      _canResolveUnsupportedAssetPricing(asset);

  double assetUnitPriceFiat(AssetModel asset) {
    switch (_pricingKindForAsset(asset)) {
      case _AssetPricingKind.xlm:
        return _xlmRate;
      case _AssetPricingKind.usdStable:
        return _usdcRate;
      case _AssetPricingKind.unsupported:
        _primeAssetMarketData(asset);
        final usd = _assetUsdPriceById[asset.id] ?? 0.0;
        final fx = _usdToFiatRate;
        if (usd <= 0 || fx <= 0 || !usd.isFinite || !fx.isFinite) return 0.0;
        return usd * fx;
    }
  }

  double assetAmountToFiat(AssetModel asset, double amount) {
    final unitPrice = assetUnitPriceFiat(asset);
    return CurrencyMath.assetAmountToFiat(amount: amount, unitPrice: unitPrice);
  }

  List<double> assetHistory24h(AssetModel asset) => _assetHistory(
    asset,
    selection: _AssetHistorySelection.h24,
    xlmHistory: _xlmHist24h,
    stableHistory: usdcHistory24h,
  );

  List<double> assetHistory7d(AssetModel asset) => _assetHistory(
    asset,
    selection: _AssetHistorySelection.d7,
    xlmHistory: _xlmHist7,
    stableHistory: usdcHistory7,
  );

  List<double> assetHistory30d(AssetModel asset) => _assetHistory(
    asset,
    selection: _AssetHistorySelection.d30,
    xlmHistory: _xlmHist30,
    stableHistory: usdcHistory30,
  );

  List<double> assetHistory1y(AssetModel asset) => _assetHistory(
    asset,
    selection: _AssetHistorySelection.y1,
    xlmHistory: _xlmHist365,
    stableHistory: usdcHistory365,
  );

  List<double> assetHistoryAll(AssetModel asset) => _assetHistory(
    asset,
    selection: _AssetHistorySelection.all,
    xlmHistory: _xlmHistAll,
    stableHistory: usdcHistory365,
  );

  List<double> _assetHistory(
    AssetModel asset, {
    required _AssetHistorySelection selection,
    required List<double> xlmHistory,
    required List<double> stableHistory,
  }) {
    switch (_pricingKindForAsset(asset)) {
      case _AssetPricingKind.xlm:
        return List<double>.from(xlmHistory);
      case _AssetPricingKind.usdStable:
        return List<double>.from(stableHistory);
      case _AssetPricingKind.unsupported:
        _primeAssetMarketData(asset, needHistory: true);
        final usdSeries = _assetUsdHistoryById[asset.id] ?? const <double>[];
        if (usdSeries.isEmpty) return const [];
        return _historyForRange(_convertUsdSeriesToFiat(usdSeries), selection);
    }
  }

  double get _usdToFiatRate {
    if (_fiat == 'usd') return 1.0;
    return (_usdcRate > 0 && _usdcRate.isFinite) ? _usdcRate : 0.0;
  }

  List<double> _convertUsdSeriesToFiat(List<double> usdSeries) {
    final fx = _usdToFiatRate;
    if (fx <= 0 || !fx.isFinite) return const [];
    return usdSeries
        .where((value) => value.isFinite && !value.isNaN && value > 0)
        .map((value) => value * fx)
        .toList(growable: false);
  }

  List<double> _historyForRange(
    List<double> series,
    _AssetHistorySelection selection,
  ) {
    if (series.isEmpty) return const [];
    switch (selection) {
      case _AssetHistorySelection.h24:
        return _tail(series, 2);
      case _AssetHistorySelection.d7:
        return _tail(series, 7);
      case _AssetHistorySelection.d30:
        return _tail(series, 30);
      case _AssetHistorySelection.y1:
        return _tail(series, 365);
      case _AssetHistorySelection.all:
        return List<double>.from(series);
    }
  }

  void _primeAssetMarketData(AssetModel asset, {bool needHistory = false}) {
    if (!_canResolveUnsupportedAssetPricing(asset) || _disposed) return;

    final now = DateTime.now().toUtc();
    final priceAt = _assetUsdPriceAt[asset.id];
    if (!_assetPriceLoadsInFlight.contains(asset.id) &&
        (priceAt == null || now.difference(priceAt) > _assetPriceCacheTtl)) {
      _assetPriceLoadsInFlight.add(asset.id);
      unawaited(_fetchAssetUsdPrice(asset));
    }

    if (!needHistory) return;

    final historyAt = _assetUsdHistoryAt[asset.id];
    if (!_assetHistoryLoadsInFlight.contains(asset.id) &&
        (historyAt == null ||
            now.difference(historyAt) > _assetHistoryCacheTtl)) {
      _assetHistoryLoadsInFlight.add(asset.id);
      unawaited(_fetchAssetUsdHistory(asset));
    }
  }

  String? _coingeckoIdForAsset(AssetModel asset) {
    const keys = <String>[
      'coingecko',
      'coingeckoId',
      'coingecko_id',
      'coinGecko',
    ];
    for (final key in keys) {
      final value = asset.externalIds[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  bool _canResolveUnsupportedAssetPricing(AssetModel asset) {
    return _coingeckoIdForAsset(asset) != null ||
        _canFetchStellarDexPricing(asset) ||
        _assetSymbolForMarketData(asset) != null ||
        _coinCapIdForAsset(asset) != null ||
        _messariSlugForAsset(asset) != null;
  }

  bool _canFetchStellarDexPricing(AssetModel asset) {
    return asset.chain.trim().toLowerCase() == 'stellar' &&
        !asset.isNative &&
        (asset.assetCode ?? '').trim().isNotEmpty &&
        (asset.issuer ?? '').trim().isNotEmpty;
  }

  Map<String, String>? _stellarAssetQueryParams(
    AssetModel asset, {
    required String prefix,
  }) {
    final code = (asset.assetCode ?? '').trim();
    final issuer = (asset.issuer ?? '').trim();
    if (code.isEmpty || issuer.isEmpty) return null;
    final type = code.length <= 4 ? 'credit_alphanum4' : 'credit_alphanum12';
    return <String, String>{
      '${prefix}_asset_type': type,
      '${prefix}_asset_code': code,
      '${prefix}_asset_issuer': issuer,
    };
  }

  Map<String, String> _stellarNativeAssetQueryParams({required String prefix}) {
    return <String, String>{'${prefix}_asset_type': 'native'};
  }

  String? _assetSymbolForMarketData(AssetModel asset) {
    final candidates = <String>[
      asset.symbol,
      asset.assetCode ?? '',
      ...asset.aliases,
    ];
    for (final candidate in candidates) {
      final normalized = candidate.trim().toUpperCase();
      if (normalized.isNotEmpty && normalized.length <= 12) return normalized;
    }
    return null;
  }

  String? _coinCapIdForAsset(AssetModel asset) {
    const keys = <String>['coincap', 'coincapId', 'coincap_id'];
    for (final key in keys) {
      final value = asset.externalIds[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }

    final symbol = _assetSymbolForMarketData(asset);
    return switch (symbol) {
      'BTC' => 'bitcoin',
      'ETH' => 'ethereum',
      'XLM' => 'stellar',
      'XRP' => 'xrp',
      'SOL' => 'solana',
      'ADA' => 'cardano',
      'DOGE' => 'dogecoin',
      'LTC' => 'litecoin',
      'USDT' => 'tether',
      'USDC' => 'usd-coin',
      _ => null,
    };
  }

  String? _messariSlugForAsset(AssetModel asset) {
    const keys = <String>['messari', 'messariSlug', 'messari_slug'];
    for (final key in keys) {
      final value = asset.externalIds[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }

    final symbol = _assetSymbolForMarketData(asset);
    return switch (symbol) {
      'BTC' => 'bitcoin',
      'ETH' => 'ethereum',
      'XLM' => 'stellar',
      'XRP' => 'xrp',
      'SOL' => 'solana',
      'ADA' => 'cardano',
      'DOGE' => 'dogecoin',
      'LTC' => 'litecoin',
      'USDT' => 'tether',
      'USDC' => 'usd-coin',
      _ => null,
    };
  }

  bool get _shouldBypassCoinGecko {
    final until = _coinGeckoRateLimitedUntil;
    return until != null && until.isAfter(DateTime.now().toUtc());
  }

  bool _isCoinGeckoRateLimitError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('429') && text.contains('coingecko');
  }

  void _markCoinGeckoRateLimited() {
    _coinGeckoRateLimitedUntil = DateTime.now().toUtc().add(
      _coinGeckoRateLimitCooldown,
    );
    debugPrint(
      'CurrencyVM: CoinGecko rate limited, '
      'cooling down until $_coinGeckoRateLimitedUntil',
    );
  }

  Future<void> _fetchAssetUsdPrice(AssetModel asset) async {
    try {
      final price = await _fetchAssetUsdPriceWithFallbacks(asset);
      if (price != null) {
        _assetUsdPriceById[asset.id] = price;
        _assetUsdPriceAt[asset.id] = DateTime.now().toUtc();
        if (!_disposed) notifyListeners();
      }
    } catch (e) {
      debugPrint(
        'CurrencyVM: Asset price fetch failed for ${asset.symbol}: $e',
      );
    } finally {
      _assetPriceLoadsInFlight.remove(asset.id);
    }
  }

  Future<void> _fetchAssetUsdHistory(AssetModel asset) async {
    try {
      final history = await _fetchAssetUsdHistoryWithFallbacks(asset);
      if (history != null && history.isNotEmpty) {
        final now = DateTime.now().toUtc();
        _assetUsdHistoryById[asset.id] = history;
        _assetUsdHistoryAt[asset.id] = now;
        _assetUsdPriceById[asset.id] = history.last;
        _assetUsdPriceAt[asset.id] = now;
        if (!_disposed) notifyListeners();
      }
    } catch (e) {
      debugPrint(
        'CurrencyVM: Asset history fetch failed for ${asset.symbol}: $e',
      );
    } finally {
      _assetHistoryLoadsInFlight.remove(asset.id);
    }
  }

  Future<double?> _fetchAssetUsdPriceWithFallbacks(AssetModel asset) async {
    final cgId = _coingeckoIdForAsset(asset);
    final coinCapId = _coinCapIdForAsset(asset);
    final messariSlug = _messariSlugForAsset(asset);
    final symbol = _assetSymbolForMarketData(asset);

    final attempts = <Future<double?> Function()>[
      if (cgId != null && !_shouldBypassCoinGecko)
        () => _fetchAssetUsdPriceFromCoinGecko(cgId),
      if (_canFetchStellarDexPricing(asset))
        () => _fetchAssetUsdPriceFromStellarDex(asset),
      if (symbol != null) () => _fetchAssetUsdPriceFromCryptoCompare(symbol),
      if (symbol != null) () => _fetchAssetUsdPriceFromCoinbase(symbol),
      if (symbol != null) () => _fetchAssetUsdPriceFromBinance(symbol),
      if (symbol != null) () => _fetchAssetUsdPriceFromKraken(symbol),
      if (symbol != null) () => _fetchAssetUsdPriceFromBitfinex(symbol),
      if (symbol != null) () => _fetchAssetUsdPriceFromKuCoin(symbol),
      if (symbol != null) () => _fetchAssetUsdPriceFromOkx(symbol),
      if (coinCapId != null) () => _fetchAssetUsdPriceFromCoinCap(coinCapId),
      if (messariSlug != null)
        () => _fetchAssetUsdPriceFromMessari(messariSlug),
    ];

    for (var i = 0; i < attempts.length; i++) {
      try {
        final value = await attempts[i]();
        if (value != null && value.isFinite && value > 0) {
          debugPrint(
            'CurrencyVM: Asset price loaded for ${asset.symbol} from layer ${i + 1}',
          );
          return value;
        }
      } catch (e) {
        if (_isCoinGeckoRateLimitError(e)) {
          _markCoinGeckoRateLimited();
        }
        debugPrint(
          'CurrencyVM: Asset price layer ${i + 1} failed for ${asset.symbol}: $e',
        );
      }
    }

    return _assetUsdPriceById[asset.id];
  }

  Future<List<double>?> _fetchAssetUsdHistoryWithFallbacks(
    AssetModel asset,
  ) async {
    final cgId = _coingeckoIdForAsset(asset);
    final coinCapId = _coinCapIdForAsset(asset);
    final messariSlug = _messariSlugForAsset(asset);
    final symbol = _assetSymbolForMarketData(asset);

    final attempts = <Future<List<double>?> Function()>[
      if (cgId != null && !_shouldBypassCoinGecko)
        () => _fetchAssetUsdHistoryFromCoinGecko(cgId),
      if (_canFetchStellarDexPricing(asset))
        () => _fetchAssetUsdHistoryFromStellarDex(asset),
      if (symbol != null) () => _fetchAssetUsdHistoryFromCryptoCompare(symbol),
      if (symbol != null) () => _fetchAssetUsdHistoryFromCoinbase(symbol),
      if (symbol != null) () => _fetchAssetUsdHistoryFromBinance(symbol),
      if (symbol != null) () => _fetchAssetUsdHistoryFromKraken(symbol),
      if (symbol != null) () => _fetchAssetUsdHistoryFromBitfinex(symbol),
      if (symbol != null) () => _fetchAssetUsdHistoryFromKuCoin(symbol),
      if (symbol != null) () => _fetchAssetUsdHistoryFromOkx(symbol),
      if (coinCapId != null) () => _fetchAssetUsdHistoryFromCoinCap(coinCapId),
      if (messariSlug != null)
        () => _fetchAssetUsdHistoryFromMessari(messariSlug),
    ];

    for (var i = 0; i < attempts.length; i++) {
      try {
        final history = await attempts[i]();
        if (history != null && history.length >= 2) {
          debugPrint(
            'CurrencyVM: Asset history loaded for ${asset.symbol} from layer ${i + 1}',
          );
          return history;
        }
      } catch (e) {
        if (_isCoinGeckoRateLimitError(e)) {
          _markCoinGeckoRateLimited();
        }
        debugPrint(
          'CurrencyVM: Asset history layer ${i + 1} failed for ${asset.symbol}: $e',
        );
      }
    }

    return _assetUsdHistoryById[asset.id];
  }

  Future<double?> _fetchAssetUsdPriceFromStellarDex(AssetModel asset) async {
    final history = await _fetchAssetUsdHistoryFromStellarDex(asset);
    if (history == null || history.isEmpty) return null;
    return history.last;
  }

  Future<double?> _fetchAssetUsdPriceFromCoinGecko(String cgId) async {
    final url = Uri.parse(
      'https://api.coingecko.com/api/v3/simple/price'
      '?ids=${Uri.encodeQueryComponent(cgId)}'
      '&vs_currencies=usd',
    );
    final payload = await _json(url);
    final market = payload[cgId];
    return _toD(market is Map ? market['usd'] : null);
  }

  Future<double?> _fetchAssetUsdPriceFromCoinCap(String assetId) async {
    final payload = await _json(
      Uri.parse(
        'https://api.coincap.io/v2/assets/${Uri.encodeComponent(assetId)}',
      ),
    );
    final data = payload['data'];
    return _toD(data is Map ? data['priceUsd'] : null);
  }

  Future<double?> _fetchAssetUsdPriceFromCryptoCompare(String symbol) async {
    final payload = await _json(
      Uri.parse(
        'https://min-api.cryptocompare.com/data/price'
        '?fsym=${Uri.encodeQueryComponent(symbol)}&tsyms=USD',
      ),
    );
    return _toD(payload['USD']);
  }

  Future<double?> _fetchAssetUsdPriceFromCoinbase(String symbol) async {
    final payload = await _json(
      Uri.parse(
        'https://api.exchange.coinbase.com/products/${Uri.encodeComponent(symbol)}-USD/ticker',
      ),
    );
    return _toD(payload['price']);
  }

  Future<double?> _fetchAssetUsdPriceFromBinance(String symbol) async {
    final payload = await _json(
      Uri.parse(
        'https://api.binance.com/api/v3/ticker/price'
        '?symbol=${Uri.encodeQueryComponent(symbol)}USDT',
      ),
    );
    return _toD(payload['price']);
  }

  Future<double?> _fetchAssetUsdPriceFromKraken(String symbol) async {
    final payload = await _json(
      Uri.parse(
        'https://api.kraken.com/0/public/Ticker?pair=${Uri.encodeQueryComponent(symbol)}USD',
      ),
    );
    final result = (payload['result'] as Map?) ?? const {};
    for (final entry in result.entries) {
      if (entry.key == 'last') continue;
      final data = entry.value;
      if (data is Map) {
        final close = data['c'];
        if (close is List && close.isNotEmpty) {
          final parsed = _toD(close.first);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  Future<double?> _fetchAssetUsdPriceFromBitfinex(String symbol) async {
    final payload = await _jsonList(
      Uri.parse(
        'https://api-pub.bitfinex.com/v2/ticker/t${Uri.encodeQueryComponent(symbol)}USD',
      ),
    );
    if (payload.length < 7) return null;
    return _toD(payload[6]);
  }

  Future<double?> _fetchAssetUsdPriceFromKuCoin(String symbol) async {
    final payload = await _json(
      Uri.parse(
        'https://api.kucoin.com/api/v1/market/orderbook/level1'
        '?symbol=${Uri.encodeQueryComponent(symbol)}-USDT',
      ),
    );
    final data = payload['data'];
    return _toD(data is Map ? data['price'] : null);
  }

  Future<double?> _fetchAssetUsdPriceFromOkx(String symbol) async {
    final payload = await _json(
      Uri.parse(
        'https://www.okx.com/api/v5/market/ticker'
        '?instId=${Uri.encodeQueryComponent(symbol)}-USDT',
      ),
    );
    final list = (payload['data'] as List?) ?? const [];
    final item = list.isNotEmpty ? list.first : null;
    return _toD(item is Map ? item['last'] : null);
  }

  Future<double?> _fetchAssetUsdPriceFromMessari(String slug) async {
    final payload = await _json(
      Uri.parse(
        'https://data.messari.io/api/v1/assets/${Uri.encodeComponent(slug)}/metrics',
      ),
    );
    final data = payload['data'];
    final marketData = data is Map ? data['market_data'] : null;
    return _toD(marketData is Map ? marketData['price_usd'] : null);
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromCoinGecko(String cgId) async {
    final payload = await _json(
      Uri.parse(
        'https://api.coingecko.com/api/v3/coins/${Uri.encodeComponent(cgId)}/market_chart'
        '?vs_currency=usd&days=max&interval=daily',
      ),
    );
    final raw = (payload['prices'] as List?) ?? const [];
    final history = <double>[];
    for (final point in raw) {
      if (point is! List || point.length < 2) continue;
      final price = _toD(point[1]);
      if (price != null) history.add(price);
    }
    return history.isEmpty ? null : history;
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromCoinCap(String assetId) async {
    final payload = await _json(
      Uri.parse(
        'https://api.coincap.io/v2/assets/${Uri.encodeComponent(assetId)}/history'
        '?interval=d1',
      ),
    );
    final raw = (payload['data'] as List?) ?? const [];
    final history = <double>[];
    for (final point in raw) {
      final price = _toD((point as Map?)?['priceUsd']);
      if (price != null) history.add(price);
    }
    return history.length >= 2 ? history : null;
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromCryptoCompare(
    String symbol,
  ) async {
    final payload = await _json(
      Uri.parse(
        'https://min-api.cryptocompare.com/data/v2/histoday'
        '?fsym=${Uri.encodeQueryComponent(symbol)}&tsym=USD&limit=2000',
      ),
    );
    final data = (payload['Data'] as Map?)?['Data'] as List? ?? const [];
    final history = <double>[];
    for (final point in data) {
      final price = _toD((point as Map?)?['close']);
      if (price != null) history.add(price);
    }
    return history.length >= 2 ? history : null;
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromCoinbase(String symbol) async {
    final payload = await _jsonList(
      Uri.parse(
        'https://api.exchange.coinbase.com/products/${Uri.encodeQueryComponent(symbol)}-USD/candles'
        '?granularity=86400&limit=350',
      ),
    );
    final closes = _extractCloses(payload, closeIndex: 4);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromBinance(String symbol) async {
    final payload = await _jsonList(
      Uri.parse(
        'https://api.binance.com/api/v3/klines'
        '?symbol=${Uri.encodeQueryComponent(symbol)}USDT&interval=1d&limit=1000',
      ),
    );
    return _extractCloses(payload, closeIndex: 4);
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromKraken(String symbol) async {
    final payload = await _json(
      Uri.parse(
        'https://api.kraken.com/0/public/OHLC?pair=${Uri.encodeQueryComponent(symbol)}USD&interval=1440',
      ),
    );
    final result = (payload['result'] as Map?) ?? const {};
    String? dataKey;
    for (final key in result.keys.cast<String>()) {
      if (key != 'last') {
        dataKey = key;
        break;
      }
    }
    if (dataKey == null) return null;
    final data = (result[dataKey] as List?) ?? const [];
    return _extractCloses(data, closeIndex: 4);
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromBitfinex(String symbol) async {
    final payload = await _jsonList(
      Uri.parse(
        'https://api-pub.bitfinex.com/v2/candles/trade:1D:t${Uri.encodeQueryComponent(symbol)}USD/hist?limit=1000',
      ),
    );
    final closes = _extractCloses(payload, closeIndex: 2);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromKuCoin(String symbol) async {
    final payload = await _json(
      Uri.parse(
        'https://api.kucoin.com/api/v1/market/candles'
        '?type=1day&symbol=${Uri.encodeQueryComponent(symbol)}-USDT',
      ),
    );
    final data = (payload['data'] as List?) ?? const [];
    final closes = _extractCloses(data, closeIndex: 2);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromOkx(String symbol) async {
    final payload = await _json(
      Uri.parse(
        'https://www.okx.com/api/v5/market/candles'
        '?instId=${Uri.encodeQueryComponent(symbol)}-USDT&bar=1D&limit=1000',
      ),
    );
    final data = (payload['data'] as List?) ?? const [];
    final closes = _extractCloses(data, closeIndex: 4);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromMessari(String slug) async {
    final start = DateTime.now().toUtc().subtract(const Duration(days: 2000));
    final end = DateTime.now().toUtc();
    final payload = await _json(
      Uri.parse(
        'https://data.messari.io/api/v1/assets/${Uri.encodeComponent(slug)}/metrics/price/time-series'
        '?interval=1d'
        '&timestamp-format=rfc3339'
        '&start=${Uri.encodeQueryComponent(start.toIso8601String())}'
        '&end=${Uri.encodeQueryComponent(end.toIso8601String())}',
      ),
    );
    final values = ((payload['data'] as Map?)?['values'] as List?) ?? const [];
    final history = <double>[];
    for (final point in values) {
      if (point is! List || point.length < 2) continue;
      final price = point.length > 4 ? _toD(point[4]) : _toD(point[1]);
      if (price != null) history.add(price);
    }
    return history.length >= 2 ? history : null;
  }

  Future<List<double>?> _fetchAssetUsdHistoryFromStellarDex(
    AssetModel asset,
  ) async {
    final assetParams = _stellarAssetQueryParams(asset, prefix: 'base');
    if (assetParams == null) return null;

    final usdcIssuer = _stellar.usdcIssuer.trim();
    if (usdcIssuer.isNotEmpty) {
      final usdcParams = <String, String>{
        'counter_asset_type': 'credit_alphanum4',
        'counter_asset_code': 'USDC',
        'counter_asset_issuer': usdcIssuer,
      };
      final usdcSeries = await _fetchStellarTradeAggregationSeries(
        baseParams: assetParams,
        counterParams: usdcParams,
      );
      if (usdcSeries.length >= 2) {
        return usdcSeries.map((point) => point.price).toList(growable: false);
      }
    }

    final xlmSeries = await _fetchStellarTradeAggregationSeries(
      baseParams: assetParams,
      counterParams: _stellarNativeAssetQueryParams(prefix: 'counter'),
    );
    if (xlmSeries.length < 2) return null;

    final xlmUsdSeries = await _fetchStellarTradeAggregationSeries(
      baseParams: _stellarNativeAssetQueryParams(prefix: 'base'),
      counterParams: <String, String>{
        'counter_asset_type': 'credit_alphanum4',
        'counter_asset_code': 'USDC',
        'counter_asset_issuer': usdcIssuer,
      },
    );
    if (xlmUsdSeries.length < 2) return null;

    final xlmUsdByDay = <int, double>{};
    for (final point in xlmUsdSeries) {
      xlmUsdByDay[_dayBucketUtc(point.at)] = point.price;
    }

    final converted = <double>[];
    double? lastKnownXlmUsd;
    for (final point in xlmSeries) {
      final xlmUsd =
          xlmUsdByDay[_dayBucketUtc(point.at)] ??
          lastKnownXlmUsd ??
          _lastUsdcPerXlm;
      if (xlmUsd <= 0 || !xlmUsd.isFinite) continue;
      lastKnownXlmUsd = xlmUsd;
      final usdPrice = point.price * xlmUsd;
      if (usdPrice.isFinite && usdPrice > 0) {
        converted.add(usdPrice);
      }
    }

    return converted.length >= 2 ? converted : null;
  }

  Future<List<_TimedPricePoint>> _fetchStellarTradeAggregationSeries({
    required Map<String, String> baseParams,
    required Map<String, String> counterParams,
    int days = 400,
  }) async {
    final now = DateTime.now().toUtc();
    var start = now.subtract(Duration(days: days));
    final unique = <int, _TimedPricePoint>{};

    while (start.isBefore(now) && !_disposed) {
      final end = start.add(const Duration(days: 180)).isAfter(now)
          ? now
          : start.add(const Duration(days: 180));
      final params = <String, String>{
        ...baseParams,
        ...counterParams,
        'resolution': '86400000',
        'start_time': '${start.millisecondsSinceEpoch}',
        'end_time': '${end.millisecondsSinceEpoch}',
        'order': 'asc',
        'limit': '200',
      };
      final url = Uri.https(
        'horizon.stellar.org',
        '/trade_aggregations',
        params,
      );
      final payload = await _json(url);
      final records =
          (payload['_embedded']?['records'] as List?) ??
          (payload['records'] as List?) ??
          const [];
      for (final record in records) {
        final row = record as Map?;
        final close = _toD(row?['close']);
        final at = _tradeAggregationTimestamp(row);
        if (close == null || at == null) continue;
        unique[_dayBucketUtc(at)] = _TimedPricePoint(at: at, price: close);
      }

      if (end.isAtSameMomentAs(now)) break;
      start = end.add(const Duration(milliseconds: 1));
    }

    final sorted = unique.values.toList()..sort((a, b) => a.at.compareTo(b.at));
    return sorted;
  }

  DateTime? _tradeAggregationTimestamp(Map? row) {
    final raw =
        row?['timestamp'] ?? row?['timestamp_close'] ?? row?['timestamp_start'];
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final asInt = int.tryParse(raw);
      if (asInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
      }
      return DateTime.tryParse(raw)?.toUtc();
    }
    return null;
  }

  int _dayBucketUtc(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day).millisecondsSinceEpoch;
  }

  _AssetPricingKind _pricingKindForAsset(AssetModel asset) {
    final keys = _assetKeys(asset);
    final tags = asset.tags.map((e) => e.trim().toLowerCase()).toSet();

    if (_isStellarXlmAsset(asset, keys: keys)) {
      return _AssetPricingKind.xlm;
    }

    if (_isUsdStableAsset(asset, keys: keys, tags: tags)) {
      return _AssetPricingKind.usdStable;
    }

    return _AssetPricingKind.unsupported;
  }

  Set<String> _assetKeys(AssetModel asset) {
    return <String>{
      asset.symbol.trim().toUpperCase(),
      (asset.assetCode ?? '').trim().toUpperCase(),
      ...asset.aliases.map((alias) => alias.trim().toUpperCase()),
    }.where((value) => value.isNotEmpty).toSet();
  }

  bool _isStellarXlmAsset(AssetModel asset, {required Set<String> keys}) {
    final chain = asset.chain.trim().toLowerCase();
    if (chain != 'stellar') {
      return keys.contains('XLM') && asset.isNative;
    }

    if (asset.isNative) return true;
    return keys.contains('XLM');
  }

  bool _isUsdStableAsset(
    AssetModel asset, {
    required Set<String> keys,
    required Set<String> tags,
  }) {
    if (tags.contains('stablecoin') ||
        tags.contains('usd-stable') ||
        tags.contains('fiat-pegged') ||
        tags.contains('dollar-pegged')) {
      return true;
    }

    const stableSymbols = <String>{
      'USD',
      'USDC',
      'USDT',
      'PYUSD',
      'FDUSD',
      'USDB',
      'USDL',
      'RLUSD',
    };
    if (keys.any(stableSymbols.contains)) return true;

    const externalFiatKeys = <String>[
      'peg',
      'pegCurrency',
      'peg_currency',
      'quote',
      'quoteCurrency',
      'quote_currency',
      'fiat',
      'fiatCurrency',
      'fiat_currency',
    ];
    for (final key in externalFiatKeys) {
      final value = asset.externalIds[key]?.trim().toUpperCase();
      if (value == 'USD') return true;
    }

    final cgId = _coingeckoIdForAsset(asset)?.trim().toLowerCase();
    const stableCoinGeckoIds = <String>{
      'usd-coin',
      'tether',
      'paypal-usd',
      'first-digital-usd',
      'global-dollar',
      'rlusd',
      'usdb',
      'mountain-protocol-usdm',
    };
    if (cgId != null && stableCoinGeckoIds.contains(cgId)) return true;

    final normalizedName = asset.name.trim().toLowerCase();
    if (normalizedName.contains('usd') &&
        (normalizedName.contains('stable') ||
            normalizedName.contains('tether') ||
            normalizedName.contains('dollar'))) {
      return true;
    }

    return false;
  }

  Future<void> _boot() async {
    try {
      final savedFiat = await CurrencySecureStorage.readFiat();
      if (savedFiat != null && savedFiat.trim().isNotEmpty) {
        _fiat = savedFiat.trim().toLowerCase();
      }

      final cache = await CurrencySecureStorage.readLastGoodRates();
      if (cache != null) {
        _lastGoodRatesCache = cache;
        final cachedFiat = (cache['fiat'] as String?)?.toLowerCase();
        if (cachedFiat == _fiat) {
          final usdc = (cache['usdcRate'] as num?)?.toDouble() ?? 0.0;
          final xlm = (cache['xlmRate'] as num?)?.toDouble() ?? 0.0;
          final cachedUsdcPerXlm = (cache['lastUsdcPerXlm'] as num?)
              ?.toDouble();
          if (usdc > 0 && xlm > 0) {
            _usdcRate = usdc;
            _xlmRate = xlm;
            _lastUsdcPerXlm =
                (cachedUsdcPerXlm != null &&
                    cachedUsdcPerXlm.isFinite &&
                    cachedUsdcPerXlm > 0)
                ? cachedUsdcPerXlm
                : (_xlmRate / _usdcRate);
            _ratesForFiat = _fiat;
            _usingFallbackRates = true;
            final age = _getCacheAge(cache);
            debugPrint(
              'CurrencyVM: Seeded from cache '
              '(age: ${age?.inMinutes ?? "unknown"}m, '
              'XLM: $_xlmRate $_fiat, USDC/XLM: $_lastUsdcPerXlm)',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('CurrencyVM: Error during boot cache load: $e');
    }

    _pairSub = _stellar.xlmUsdcPriceStream().listen(
      (p) {
        if (_disposed) return;
        if (p.usdcPerXlm > 0 && p.usdcPerXlm.isFinite) {
          final oldPrice = _lastUsdcPerXlm;
          _lastUsdcPerXlm = p.usdcPerXlm;
          _ratesUnavailable = false;
          _usingFallbackRates = false;
          _recomputeXlmFiat();
          _streamConsecutiveErrors = 0;
          unawaited(_saveLatestPricesToCache());

          if ((oldPrice - p.usdcPerXlm).abs() > 0.0001) {
            debugPrint(
              'CurrencyVM: Stream updated: '
              '${p.usdcPerXlm} USDC/XLM → '
              '${_xlmRate.toStringAsFixed(4)} $_fiat/XLM',
            );
          }
        }
      },
      onError: (Object e) {
        debugPrint('CurrencyVM: Stream error: $e');
        _streamConsecutiveErrors++;
        if (_streamConsecutiveErrors >= _maxConsecutiveErrors) {
          debugPrint(
            'CurrencyVM: ${'$_streamConsecutiveErrors'} consecutive stream errors - preserving last valid rates if available',
          );
          _handleRateFailure('pair stream error');
          if (!_disposed) notifyListeners();
        }
      },
      cancelOnError: false,
    );

    await Future.wait([
      _refreshUsdToFiat(force: true),
      _refreshXlmHistoriesWithFallbacks(force: true),
    ]);

    _setLoading(false);
  }

  @override
  void dispose() {
    _disposed = true;
    _pairSub?.cancel();
    if (!_xlmCtrl.isClosed) _xlmCtrl.close();
    if (!_usdcCtrl.isClosed) _usdcCtrl.close();
    _client.close();
    super.dispose();
  }

  void _subscribeToPairStream() {
    _pairSub?.cancel();
    _pairSub = _stellar.xlmUsdcPriceStream().listen(
      (p) {
        if (_disposed) return;
        if (p.usdcPerXlm > 0 && p.usdcPerXlm.isFinite) {
          final oldPrice = _lastUsdcPerXlm;
          _lastUsdcPerXlm = p.usdcPerXlm;
          _ratesUnavailable = false;
          _usingFallbackRates = false;
          _recomputeXlmFiat();
          _saveLatestPricesToCache();

          if ((oldPrice - p.usdcPerXlm).abs() > 0.0001) {
            debugPrint(
              'CurrencyVM: Stream updated: '
              '${p.usdcPerXlm} USDC/XLM -> '
              '${_xlmRate.toStringAsFixed(4)} $_fiat/XLM',
            );
          }
        }
      },
      onError: (Object e) {
        debugPrint('CurrencyVM: Stream error: $e');
        _pairSub = null;
        _streamConsecutiveErrors++;
        if (_streamConsecutiveErrors >= _maxConsecutiveErrors) {
          debugPrint(
            'CurrencyVM: ${'$_streamConsecutiveErrors'} consecutive stream errors - preserving last valid rates if available',
          );
          _handleRateFailure('pair stream reconnect error');
          if (!_disposed) notifyListeners();
        }
      },
      onDone: () {
        _pairSub = null;
      },
      cancelOnError: false,
    );
  }

  Future<void> _recoverAfterReconnect() async {
    if (_disposed || _reconnectRecoveryInFlight) return;
    _reconnectRecoveryInFlight = true;
    debugPrint('CurrencyVM: Network restored, recovering rates and stream');

    try {
      _subscribeToPairStream();
      await Future.wait([
        refreshRates(force: true),
        refreshHistory(force: true),
      ]);
    } finally {
      _reconnectRecoveryInFlight = false;
    }
  }

  void _zeroRates(String reason) {
    if (_disposed) return;
    _usdcRate = 0;
    _xlmRate = 0;
    _lastUsdcPerXlm = 0;
    _ratesUnavailable = true;
    _usingFallbackRates = false;
    debugPrint('CurrencyVM: Rates zeroed ($reason) - UI should show N/A');
  }

  bool _hasUsableRatesInMemory() {
    return _usdcRate > 0 &&
        _xlmRate > 0 &&
        _lastUsdcPerXlm > 0 &&
        _usdcRate.isFinite &&
        _xlmRate.isFinite &&
        _lastUsdcPerXlm.isFinite;
  }

  void _handleRateFailure(String reason) {
    if (_disposed) return;

    if (_hasUsableRatesInMemory()) {
      _ratesUnavailable = true;
      _usingFallbackRates = true;
      debugPrint(
        'CurrencyVM: Preserving last good in-memory rates after failure ($reason)',
      );
      return;
    }

    final restored = _tryRestoreRatesFromRecentCache();
    if (restored) {
      _ratesUnavailable = true;
      _usingFallbackRates = true;
      debugPrint('CurrencyVM: Restored cached rates after failure ($reason)');
      return;
    }

    _zeroRates(reason);
  }

  Future<void> _refreshUsdToFiat({bool force = false}) async {
    if (_disposed) return;
    _setLoading(true);

    try {
      final summary = await _fetchBackendWalletSummary(force: force);
      final fx = _toD(summary['usdToFiat']);
      final xlmUsdc = _toD(summary['xlmUsdc']);
      final history = _parseBackendDailyHistory(summary);
      if (_disposed) return;

      if (fx != null && fx.isFinite && fx > 0) {
        _usdcRate = fx;
        if (xlmUsdc != null && xlmUsdc.isFinite && xlmUsdc > 0) {
          _lastUsdcPerXlm = xlmUsdc;
        } else if (_lastUsdcPerXlm <= 0 && history.length >= 2) {
          _lastUsdcPerXlm = history.last;
        }
        _ratesForFiat = _fiat;
        _ratesUnavailable = false;
        _usingFallbackRates = false;
        _lastRateRefresh = DateTime.now().toUtc();
        if (!_usdcCtrl.isClosed) _usdcCtrl.add(_usdcRate);
        _recomputeXlmFiat();
        await _saveLatestPricesToCache();

        debugPrint(
          'CurrencyVM: Rates refreshed - '
          'USDC: $_usdcRate $_fiat, '
          'XLM: ${_xlmRate.toStringAsFixed(4)} $_fiat '
          '(USDC/XLM: $_lastUsdcPerXlm)',
        );
      } else {
        throw Exception('Invalid exchange rate returned: $fx');
      }
    } catch (e) {
      if (_disposed) return;
      debugPrint('CurrencyVM: Error refreshing rates: $e');
      _handleRateFailure('fetch failed');
    } finally {
      _setLoading(false);
      if (!_disposed) notifyListeners();
    }
  }

  void _recomputeXlmFiat() {
    if (_disposed) return;
    if (_lastUsdcPerXlm > 0 &&
        _usdcRate > 0 &&
        _lastUsdcPerXlm.isFinite &&
        _usdcRate.isFinite) {
      _xlmRate = _lastUsdcPerXlm * _usdcRate;
      if (!_xlmCtrl.isClosed) _xlmCtrl.add(_xlmRate);
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _refreshXlmHistoriesWithFallbacks({bool force = false}) async {
    if (_disposed) return;

    try {
      final summary = await _fetchBackendWalletSummary(force: force);
      final history = _parseBackendDailyHistory(summary);
      final xlmUsdc = _toD(summary['xlmUsdc']);
      if (!_disposed && history.length >= 2) {
        if (xlmUsdc != null && xlmUsdc.isFinite && xlmUsdc > 0) {
          _lastUsdcPerXlm = xlmUsdc;
        }
        _applyDailySeries(history);
        _lastGoodHistoryCache = history;
        _lastHistoryRefresh = DateTime.now().toUtc();
        await _saveHistoryToCache(history);
        debugPrint(
          'CurrencyVM: Loaded ${history.length} daily closes from backend',
        );
        return;
      }

      await _useCachedHistoryAsFallback();
      debugPrint('CurrencyVM: Using cached history as fallback');
    } catch (e) {
      debugPrint('CurrencyVM: Error refreshing history: $e');
      await _useCachedHistoryAsFallback();
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  void _applyDailySeries(List<double> dailyCloses) {
    if (_disposed || dailyCloses.isEmpty) return;

    final valid = dailyCloses.where((c) => c.isFinite && c > 0).toList();
    if (valid.isEmpty) {
      debugPrint('CurrencyVM: No valid close prices after filtering');
      _applyDailyCacheFallbackAsync();
      return;
    }

    final capped = valid.length > _maxHistoryDays
        ? valid.sublist(valid.length - _maxHistoryDays)
        : valid;

    _xlmHistAll = capped;
    _xlmHist365 = _tail(capped, 365);
    _xlmHist30 = _tail(capped, 30);
    _xlmHist7 = _tail(capped, 7);
    _xlmHist24h = _tail(capped, 2);

    if (_lastUsdcPerXlm <= 0 && capped.isNotEmpty) {
      _lastUsdcPerXlm = capped.last;
      _recomputeXlmFiat();
    }
  }

  void _applyDailyCacheFallbackAsync() {
    _useCachedHistoryAsFallback();
  }

  Future<void> _saveLatestPricesToCache() async {
    if (_ratesForFiat != _fiat) return;
    if (_usdcRate <= 0 || _xlmRate <= 0 || _lastUsdcPerXlm <= 0) return;
    try {
      final data = {
        'fiat': _fiat,
        'usdcRate': _usdcRate,
        'xlmRate': _xlmRate,
        'lastUsdcPerXlm': _lastUsdcPerXlm,
        'ts': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      };
      _lastGoodRatesCache = data;
      _lastRateRefresh = DateTime.now().toUtc();
      await CurrencySecureStorage.saveLastGoodRates(data);
    } catch (e) {
      debugPrint('CurrencyVM: Error saving rates to cache: $e');
    }
  }

  Future<void> _saveHistoryToCache(List<double> history) async {
    try {
      await CurrencySecureStorage.saveLastGoodHistory({
        'history': history,
        'ts': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      });
    } catch (e) {
      debugPrint('CurrencyVM: Error saving history to cache: $e');
    }
  }

  Future<List<double>?> _loadHistoryFromCache() async {
    try {
      final cache = await CurrencySecureStorage.readLastGoodHistory();
      if (cache == null) return null;
      final raw = cache['history'];
      if (raw is List && raw.isNotEmpty) {
        final result = <double>[];
        for (final e in raw) {
          if (e is num && e.isFinite && e > 0) result.add(e.toDouble());
        }
        return result.isEmpty ? null : result;
      }
    } catch (e) {
      debugPrint('CurrencyVM: Error loading history from cache: $e');
    }
    return null;
  }

  Future<void> _useCachedHistoryAsFallback() async {
    if (_lastGoodHistoryCache != null && _lastGoodHistoryCache!.isNotEmpty) {
      _applyDailySeries(_lastGoodHistoryCache!);
      debugPrint(
        'CurrencyVM: Applied in-memory history cache '
        '(${_lastGoodHistoryCache!.length} days)',
      );
    } else {
      final stored = await _loadHistoryFromCache();
      if (stored != null && stored.isNotEmpty) {
        _lastGoodHistoryCache = stored;
        _applyDailySeries(stored);
        debugPrint(
          'CurrencyVM: Applied stored history (${stored.length} days)',
        );
      } else {
        debugPrint('CurrencyVM: No cached history available');
      }
    }
  }

  Future<Map<String, dynamic>> _fetchBackendWalletSummary({
    bool force = false,
  }) async {
    final now = DateTime.now().toUtc();
    final cached = _backendWalletSummaryCache;
    final cachedFiat = (cached?['fiat'] as String?)?.trim().toLowerCase();
    if (!force &&
        cached != null &&
        cachedFiat == _fiat &&
        _backendWalletSummaryAt != null &&
        now.difference(_backendWalletSummaryAt!) <
            _backendWalletSummaryCacheTtl) {
      return cached;
    }

    final inFlight = _backendWalletSummaryInFlight;
    if (inFlight != null) return inFlight;

    final uri = Uri.parse(
      '$centralizedBaseUrl/market-data/wallet-summary',
    ).replace(queryParameters: <String, String>{'fiat': _fiat.toUpperCase()});

    final future = _json(uri)
        .then((payload) {
          _backendWalletSummaryCache = payload;
          _backendWalletSummaryAt = DateTime.now().toUtc();
          return payload;
        })
        .whenComplete(() {
          _backendWalletSummaryInFlight = null;
        });

    _backendWalletSummaryInFlight = future;
    return future;
  }

  List<double> _parseBackendDailyHistory(Map<String, dynamic> payload) {
    final raw = payload['xlmHistoryDaily'];
    if (raw is! List) return const <double>[];
    return raw
        .whereType<num>()
        .map((value) => value.toDouble())
        .where((value) => value.isFinite && !value.isNaN && value > 0)
        .toList(growable: false);
  }

  bool _tryRestoreRatesFromRecentCache() {
    final cache = _lastGoodRatesCache;
    if (cache == null) return false;

    final cachedFiat = (cache['fiat'] as String?)?.toLowerCase();
    if (cachedFiat != _fiat) return false;

    final age = _getCacheAge(cache);
    final maxAge = rateCacheDuration * 3;
    if (age == null || age > maxAge) {
      debugPrint(
        'CurrencyVM: Cached rates too old '
        '(${age?.inMinutes ?? "unknown"}m > ${maxAge.inMinutes}m)',
      );
      return false;
    }

    final usdc = (cache['usdcRate'] as num?)?.toDouble() ?? 0.0;
    final xlm = (cache['xlmRate'] as num?)?.toDouble() ?? 0.0;
    final usdcPerXlm = (cache['lastUsdcPerXlm'] as num?)?.toDouble();

    if (usdc <= 0 || xlm <= 0 || !usdc.isFinite || !xlm.isFinite) return false;
    if (_isSuspiciousRateCache(
      fiat: _fiat,
      usdcRate: usdc,
      xlmRate: xlm,
      usdcPerXlm: usdcPerXlm,
    )) {
      debugPrint('CurrencyVM: Rejected suspicious cached rates for $_fiat');
      return false;
    }

    _usdcRate = usdc;
    _xlmRate = xlm;
    _lastUsdcPerXlm =
        (usdcPerXlm != null && usdcPerXlm > 0 && usdcPerXlm.isFinite)
        ? usdcPerXlm
        : (xlm / usdc);
    _ratesForFiat = _fiat;
    _ratesUnavailable = false;
    _usingFallbackRates = true;
    debugPrint('CurrencyVM: Restored cached rates (${age.inMinutes}m old)');
    return true;
  }

  bool _isSuspiciousRateCache({
    required String fiat,
    required double usdcRate,
    required double xlmRate,
    required double? usdcPerXlm,
  }) {
    final normalizedFiat = fiat.trim().toLowerCase();
    if (normalizedFiat == 'usd') return false;

    final peggedUsdFiats = <String>{'bmd', 'bsd', 'pab'};
    if (peggedUsdFiats.contains(normalizedFiat)) return false;

    final quote = usdcPerXlm ?? (usdcRate > 0 ? xlmRate / usdcRate : 0.0);
    if (quote <= 0 || !quote.isFinite) return false;

    final rateLooksUsd = (usdcRate - 1.0).abs() <= 0.02;
    final xlmMatchesUsdQuote = ((xlmRate - quote).abs() / quote) <= 0.02;
    return rateLooksUsd && xlmMatchesUsdQuote;
  }

  bool _isSingleSourceRateReasonable(double value, String tgt) {
    if (!value.isFinite || value <= 0 || value > 1_000_000) return false;
    final cache = _lastGoodRatesCache;
    if (cache == null) return true;
    final cachedFiat = (cache['fiat'] as String?)?.toUpperCase();
    if (cachedFiat != tgt.toUpperCase()) {
      return true;
    }
    final cached = (cache['usdcRate'] as num?)?.toDouble();
    if (cached == null || !cached.isFinite || cached <= 0) return true;
    final diffPct = ((value - cached).abs() / cached) * 100.0;
    return diffPct <= _maxSingleSourceJumpPct;
  }

  // ignore: unused_element
  Future<double?> _usdToFiat(String fiat) async {
    final tgt = fiat.toUpperCase();
    if (tgt == 'USD') return 1.0;
    return _withRetry(() => _fetchFiatRate(tgt), maxRetries: _maxRetries);
  }

  Future<double?> _fetchFiatRate(String tgt) async {
    final quotes = <_FxSourceQuote>[];
    final fetchers = <({String source, Future<double?> Function() run})>[
      (source: 'exchangerate.host', run: () => _fetchFromExchangeRateHost(tgt)),
      (source: 'fixer.io', run: () => _fetchFromFixerIo(tgt)),
      (
        source: 'openexchangerates',
        run: () => _fetchFromOpenExchangeRates(tgt),
      ),
      (source: 'frankfurter', run: () => _fetchFromFrankfurter(tgt)),
    ];

    for (final fetcher in fetchers) {
      final value = await _safeFxSource(fetcher.source, fetcher.run);
      if (value == null || !value.isFinite || value <= 0) continue;

      quotes.add(_FxSourceQuote(source: fetcher.source, value: value));
      final consensus = _selectConsensusFxRate(quotes);
      if (consensus != null) {
        debugPrint(
          'CurrencyVM: FX consensus for $tgt locked from ${quotes.length} source(s) at $consensus',
        );
        return consensus;
      }
    }

    if (quotes.isEmpty) return null;

    if (quotes.length == 1 &&
        (_isSingleSourceRateReasonable(quotes.first.value, tgt) ||
            _shouldTrustSingleLiveFxQuote(quotes.first, tgt))) {
      return quotes.first.value;
    }

    final fallback = _bestReasonableFxFallback(quotes, tgt);
    if (fallback != null) {
      debugPrint(
        'CurrencyVM: FX fallback for $tgt selected ${fallback.source} at ${fallback.value}',
      );
      return fallback.value;
    }

    debugPrint(
      'CurrencyVM: FX sources diverged for $tgt: ${quotes.map((q) => '${q.source}=${q.value}').join(', ')}',
    );
    return null;
  }

  Future<double?> _safeFxSource(
    String source,
    Future<double?> Function() fetcher,
  ) async {
    try {
      final value = await fetcher();
      if (value != null && value.isFinite && value > 0) {
        debugPrint('CurrencyVM: FX source $source returned $value');
      }
      return value;
    } catch (e) {
      debugPrint('CurrencyVM: FX source $source failed: $e');
      return null;
    }
  }

  double? _selectConsensusFxRate(List<_FxSourceQuote> quotes) {
    if (quotes.length < 2) return null;

    List<_FxSourceQuote> bestCluster = const <_FxSourceQuote>[];
    for (final anchor in quotes) {
      final cluster = quotes
          .where((quote) {
            final pct =
                ((quote.value - anchor.value).abs() / anchor.value) * 100.0;
            return pct <= _maxFxSpreadPct;
          })
          .toList(growable: false);
      if (cluster.length > bestCluster.length) {
        bestCluster = cluster;
      }
    }

    if (bestCluster.length < 2) return null;
    final total = bestCluster.fold<double>(
      0.0,
      (sum, quote) => sum + quote.value,
    );
    return total / bestCluster.length;
  }

  _FxSourceQuote? _bestReasonableFxFallback(
    List<_FxSourceQuote> quotes,
    String tgt,
  ) {
    for (final quote in quotes) {
      if (_isSingleSourceRateReasonable(quote.value, tgt) ||
          _shouldTrustSingleLiveFxQuote(quote, tgt)) {
        return quote;
      }
    }
    return null;
  }

  bool _shouldTrustSingleLiveFxQuote(_FxSourceQuote quote, String tgt) {
    final trustedSources = <String>{'frankfurter', 'exchangerate.host'};
    if (!trustedSources.contains(quote.source)) return false;

    final cache = _lastGoodRatesCache;
    if (cache == null) return true;

    final cachedFiat = (cache['fiat'] as String?)?.toLowerCase();
    if (cachedFiat != tgt.toLowerCase()) return true;

    final cachedUsdc = (cache['usdcRate'] as num?)?.toDouble() ?? 0.0;
    final cachedXlm = (cache['xlmRate'] as num?)?.toDouble() ?? 0.0;
    final cachedUsdcPerXlm = (cache['lastUsdcPerXlm'] as num?)?.toDouble();

    return _isSuspiciousRateCache(
      fiat: tgt,
      usdcRate: cachedUsdc,
      xlmRate: cachedXlm,
      usdcPerXlm: cachedUsdcPerXlm,
    );
  }

  Future<double?> _fetchFromFrankfurter(String tgt) async {
    final m = await _json(
      Uri.parse('https://api.frankfurter.app/latest?from=USD&to=$tgt'),
    );
    final v = (m['rates'] as Map?)?[tgt];
    return (v is num && v.isFinite && v > 0) ? v.toDouble() : null;
  }

  Future<double?> _fetchFromExchangeRateHost(String tgt) async {
    final m = await _json(
      Uri.parse('https://api.exchangerate.host/latest?base=USD&symbols=$tgt'),
    );
    if (m['success'] == false) return null;
    final v = (m['rates'] as Map?)?[tgt];
    return (v is num && v.isFinite && v > 0) ? v.toDouble() : null;
  }

  Future<double?> _fetchFromFixerIo(String tgt) async {
    final apiKey = AppEnv.fixerApiKey;
    if (apiKey == null || apiKey.isEmpty) return null;
    final m = await _json(
      Uri.parse(
        'https://data.fixer.io/api/latest'
        '?access_key=${Uri.encodeQueryComponent(apiKey)}'
        '&symbols=USD,$tgt',
      ),
    );
    if (m['success'] == false) return null;
    final rates = (m['rates'] as Map?) ?? const {};
    final usd = _toD(rates['USD']);
    final target = _toD(rates[tgt]);
    if (usd == null || target == null) return null;
    return target / usd;
  }

  Future<double?> _fetchFromOpenExchangeRates(String tgt) async {
    final appId = AppEnv.openExchangeRatesAppId;
    if (appId == null || appId.isEmpty) return null;
    final m = await _json(
      Uri.parse(
        'https://openexchangerates.org/api/latest.json'
        '?app_id=${Uri.encodeQueryComponent(appId)}'
        '&symbols=$tgt',
      ),
    );
    final v = (m['rates'] as Map?)?[tgt];
    return (v is num && v.isFinite && v > 0) ? v.toDouble() : null;
  }

  // ignore: unused_element
  Future<List<double>?> _fetchXlmUsdcDailyAllFromCex() async {
    return _firstNonNull<List<double>>([
      _cexBinanceDailyAll,
      _cexCoinbaseDailyAll,
      _cexKucoinDailyAll,
    ]);
  }

  Future<List<double>?> _cexBinanceDailyAll() async {
    const limit = 1000;
    int? endMs;
    final closes = <double>[];
    int guard = 0;

    while (guard++ < 10 && !_disposed) {
      final url = Uri.parse(
        'https://api.binance.com/api/v3/klines'
        '?symbol=XLMUSDT&interval=1d&limit=$limit'
        '${endMs != null ? '&endTime=$endMs' : ''}',
      );
      final batch = await _jsonList(url);
      if (batch.isEmpty) break;

      int? firstOpenTime;
      for (final item in batch) {
        if (item is! List || item.length < 5) continue;
        final close = _toD(item[4]);
        if (close != null) closes.add(close);
        firstOpenTime ??= item[0] is int ? item[0] as int : null;
      }

      if (firstOpenTime == null || batch.length < limit) break;

      final newEnd = firstOpenTime - 1;
      if (endMs != null && newEnd >= endMs) break;
      endMs = newEnd;
    }

    return closes.isEmpty ? null : closes;
  }

  Future<List<double>?> _cexCoinbaseDailyAll() async {
    final closes = <double>[];
    DateTime end = DateTime.now().toUtc();
    const chunkDays = 300;
    int guard = 0;

    while (guard++ < 15 && !_disposed) {
      final start = end.subtract(const Duration(days: chunkDays));

      if (start.isBefore(DateTime.utc(2019, 5, 1))) break;

      final url = Uri.parse(
        'https://api.exchange.coinbase.com/products/XLM-USD/candles'
        '?granularity=86400'
        '&start=${start.toIso8601String()}'
        '&end=${end.toIso8601String()}',
      );
      final arr = await _jsonList(url);
      if (arr.isEmpty) break;

      final batch = <double>[];
      for (final item in arr) {
        if (item is! List || item.length < 5) continue;
        final close = _toD(item[4]);
        if (close != null) batch.add(close);
      }
      if (batch.isEmpty) break;

      closes.insertAll(0, batch.reversed);

      if (arr.length < chunkDays) break;

      final newEnd = start.subtract(const Duration(seconds: 1));
      if (!newEnd.isBefore(end)) break;
      end = newEnd;
    }

    return closes.isEmpty ? null : closes;
  }

  Future<List<double>?> _cexKucoinDailyAll() async {
    final closes = <double>[];
    int endAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final listingEpoch =
        DateTime.utc(2018, 1, 1).millisecondsSinceEpoch ~/ 1000;
    const chunkSec = 300 * 86400;
    int guard = 0;

    while (guard++ < 15 && !_disposed) {
      final startAt = endAt - chunkSec;

      if (startAt < listingEpoch) break;

      final url = Uri.parse(
        'https://api.kucoin.com/api/v1/market/candles'
        '?type=1day&symbol=XLM-USDT'
        '&startAt=$startAt&endAt=$endAt',
      );
      final m = await _json(url);
      final arr = (m['data'] as List?) ?? [];
      if (arr.isEmpty) break;

      final batch = <double>[];
      for (final item in arr) {
        if (item is! List || item.length < 3) continue;
        final close = _toD(item[2]);
        if (close != null) batch.add(close);
      }
      if (batch.isEmpty) break;

      closes.insertAll(0, batch.reversed);

      if (arr.length < chunkSec ~/ 86400) break;

      final newEnd = startAt - 1;
      if (newEnd >= endAt) break;
      endAt = newEnd;
    }

    return closes.isEmpty ? null : closes;
  }

  // ignore: unused_element
  Future<List<double>?> _fetchXlmUsdcDailyFromCex() async {
    return _firstNonNull<List<double>>([
      _cexBinanceDailyRecent,
      _cexCoinbaseDailyRecent,
      _cexKucoinDailyRecent,
      _cexOkxDailyRecent,
      _cexKrakenDailyRecent,
      _cexBitstampDailyRecent,
    ]);
  }

  Future<List<double>?> _cexBinanceDailyRecent() async {
    final data = await _jsonList(
      Uri.parse(
        'https://api.binance.com/api/v3/klines?symbol=XLMUSDT&interval=1d&limit=400',
      ),
    );
    return _extractCloses(data, closeIndex: 4);
  }

  Future<List<double>?> _cexCoinbaseDailyRecent() async {
    final data = await _jsonList(
      Uri.parse(
        'https://api.exchange.coinbase.com/products/XLM-USD/candles?granularity=86400&limit=370',
      ),
    );
    final closes = _extractCloses(data, closeIndex: 4);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _cexKucoinDailyRecent() async {
    final m = await _json(
      Uri.parse(
        'https://api.kucoin.com/api/v1/market/candles?type=1day&symbol=XLM-USDT',
      ),
    );
    final data = (m['data'] as List?) ?? [];
    final closes = _extractCloses(data, closeIndex: 2);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _cexOkxDailyRecent() async {
    final m = await _json(
      Uri.parse(
        'https://www.okx.com/api/v5/market/candles?instId=XLM-USDT&bar=1D&limit=400',
      ),
    );
    final data = (m['data'] as List?) ?? [];
    final closes = _extractCloses(data, closeIndex: 4);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _cexKrakenDailyRecent() async {
    final m = await _json(
      Uri.parse(
        'https://api.kraken.com/0/public/OHLC?pair=XLMUSD&interval=1440',
      ),
    );
    final result = (m['result'] as Map?) ?? {};
    String? dataKey;
    for (final key in result.keys.cast<String>()) {
      if (key != 'last') {
        dataKey = key;
        break;
      }
    }
    if (dataKey == null) return null;
    final data = (result[dataKey] as List?) ?? [];
    return _extractCloses(data, closeIndex: 4);
  }

  Future<List<double>?> _cexBitstampDailyRecent() async {
    final m = await _json(
      Uri.parse(
        'https://www.bitstamp.net/api/v2/ohlc/xlmusd/?step=86400&limit=400',
      ),
    );
    final ohlcList = ((m['data'] as Map?)?['ohlc'] as List?) ?? [];
    if (ohlcList.isEmpty) return null;

    final sorted = List<dynamic>.from(ohlcList)
      ..sort((a, b) {
        final tsA =
            int.tryParse((a as Map)['timestamp']?.toString() ?? '') ?? 0;
        final tsB =
            int.tryParse((b as Map)['timestamp']?.toString() ?? '') ?? 0;
        return tsA.compareTo(tsB);
      });

    final closes = <double>[];
    for (final item in sorted) {
      final close = _toD((item as Map)['close']);
      if (close != null) closes.add(close);
    }
    return closes.isEmpty ? null : closes;
  }

  // ignore: unused_element
  Future<List<double>?> _fetchXlmUsdcDailyAllFromDex() async {
    final issuer = _stellar.usdcIssuer;
    final now = DateTime.now().toUtc();
    DateTime start = DateTime.utc(2015, 9, 1);
    final closes = <double>[];

    while (start.isBefore(now) && !_disposed) {
      final end = start.add(const Duration(days: 200));
      final url = Uri.parse(
        'https://horizon.stellar.org/trade_aggregations'
        '?base_asset_type=native'
        '&counter_asset_type=credit_alphanum12'
        '&counter_asset_code=USDC'
        '&counter_asset_issuer=$issuer'
        '&resolution=86400000'
        '&start_time=${start.millisecondsSinceEpoch}'
        '&end_time=${end.millisecondsSinceEpoch}'
        '&order=asc'
        '&limit=200',
      );
      final m = await _json(url);
      final records =
          (m['_embedded']?['records'] as List?) ??
          (m['records'] as List?) ??
          [];
      if (records.isEmpty) break;

      for (final r in records) {
        final close = _toD((r as Map)['close']);
        if (close != null) closes.add(close);
      }

      start = end;
      if (closes.length > _maxHistoryDays) break;
    }

    return closes.isEmpty ? null : closes;
  }

  // ignore: unused_element
  Future<List<double>?> _fetchXlmUsdcDailyFromDex() async {
    final issuer = _stellar.usdcIssuer;
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 400));

    final url = Uri.parse(
      'https://horizon.stellar.org/trade_aggregations'
      '?base_asset_type=native'
      '&counter_asset_type=credit_alphanum12'
      '&counter_asset_code=USDC'
      '&counter_asset_issuer=$issuer'
      '&resolution=86400000'
      '&start_time=${start.millisecondsSinceEpoch}'
      '&end_time=${now.millisecondsSinceEpoch}'
      '&order=asc'
      '&limit=200',
    );

    final m = await _json(url);
    final records =
        (m['_embedded']?['records'] as List?) ?? (m['records'] as List?) ?? [];
    if (records.isEmpty) return null;

    final closes = <double>[];
    for (final r in records) {
      final close = _toD((r as Map)['close']);
      if (close != null) closes.add(close);
    }
    return closes.isEmpty ? null : closes;
  }

  Future<Map<String, dynamic>> _json(Uri url) async {
    final resp = await _client
        .get(url, headers: {'User-Agent': _userAgent})
        .timeout(httpTimeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode} for ${url.host}', uri: url);
    }

    final body = _capBody(resp.body, url);
    final decoded = jsonDecode(body.isEmpty ? '{}' : body);
    return decoded is Map<String, dynamic> ? decoded : {'_data': decoded};
  }

  Future<List<dynamic>> _jsonList(Uri url) async {
    final resp = await _client
        .get(url, headers: {'User-Agent': _userAgent})
        .timeout(httpTimeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode} for ${url.host}', uri: url);
    }

    final body = _capBody(resp.body, url);
    final decoded = jsonDecode(body.isEmpty ? '[]' : body);
    return decoded is List ? decoded : [];
  }

  String _capBody(String body, Uri url) {
    if (body.length <= _maxResponseBytes) return body;
    debugPrint(
      'CurrencyVM: Response from ${url.host} truncated '
      '(${body.length} > $_maxResponseBytes bytes)',
    );
    return body.substring(0, _maxResponseBytes);
  }

  List<double> _tail(List<double> series, int n) {
    if (series.isEmpty) return const [];
    if (series.length <= n) return List<double>.from(series);
    return series.sublist(series.length - n);
  }

  double _pct(List<double> series) {
    if (series.length < 2) return 0.0;
    final first = series.first;
    final last = series.last;
    if (first <= 0 || !first.isFinite || !last.isFinite) return 0.0;
    return ((last - first) / first) * 100.0;
  }

  List<double>? _extractCloses(List<dynamic> data, {required int closeIndex}) {
    if (data.isEmpty) return null;
    final closes = <double>[];
    for (final item in data) {
      if (item is! List || item.length <= closeIndex) continue;
      final close = _toD(item[closeIndex]);
      if (close != null) closes.add(close);
    }
    return closes.isEmpty ? null : closes;
  }

  Duration? _getCacheAge(Map<dynamic, dynamic> cache) {
    final ts = cache['ts'];
    if (ts is! int) return null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(
      ts * 1000,
      isUtc: true,
    );
    return DateTime.now().toUtc().difference(cachedAt);
  }

  double? _toD(dynamic v) {
    if (v == null) return null;
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else if (v is String) {
      d = double.tryParse(v);
    }
    return (d != null && d.isFinite && d > 0) ? d : null;
  }

  Future<T?> _firstNonNull<T>(List<Future<T?> Function()> attempts) async {
    for (final fetcher in attempts) {
      if (_disposed) return null;
      try {
        final result = await fetcher();
        if (result != null) return result;
      } catch (e) {
        debugPrint('CurrencyVM: Source attempt failed: $e');
      }
    }
    return null;
  }

  Future<T?> _withRetry<T>(
    Future<T?> Function() operation, {
    int maxRetries = 3,
  }) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (_disposed) return null;
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxRetries - 1) {
          debugPrint('CurrencyVM: Max retries ($maxRetries) reached: $e');
          rethrow;
        }
        final delay = _retryDelay * (1 << attempt);
        debugPrint(
          'CurrencyVM: Retry ${attempt + 1}/$maxRetries after ${delay.inMilliseconds}ms',
        );
        await Future.delayed(delay);
      }
    }
    return null;
  }

  void _setLoading(bool v) {
    if (_disposed || _loading == v) return;
    _loading = v;
    notifyListeners();
  }
}
