import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CurrencyProvider extends ChangeNotifier {
  /// Default base fiat
  String _fiat = "usd";

  /// Latest rates (current)
  double _usdtRate = 0;   // fallback so test mode isn't zero
  double _trxRate  = 0;  // fallback so test mode isn't zero

  /// Previous good rates (used as fallback on failures)
  double _prevUsdtRate = 0;
  double _prevTrxRate  = 0;

  /// Price history (for charts)
  List<double> _trxHistory = [];
  List<double> _usdtHistory = [];

  /// Loading state
  bool _loading = true;

  Timer? _pollingTimer;

  /// Streams for realtime updates
  final StreamController<double> _trxPriceController = StreamController.broadcast();
  final StreamController<double> _usdtPriceController = StreamController.broadcast();

  String get fiat => _fiat;
  double get usdtRate => _usdtRate;
  double get trxRate => _trxRate;
  bool get loading => _loading;

  List<double> get trxHistory => _trxHistory;
  List<double> get usdtHistory => _usdtHistory;

  Stream<double> get trxPriceStream => _trxPriceController.stream;
  Stream<double> get usdtPriceStream => _usdtPriceController.stream;

  CurrencyProvider() {
    fetchRates();
    fetchHistory();
    _startPolling();
  }

  void setFiat(String newFiat) {
    final lower = newFiat.toLowerCase();
    if (lower != _fiat) {
      _fiat = lower;
      // Keep current/previous as is; fetch will replace them atomically when ready.
      fetchRates();
      fetchHistory();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchRates();
      fetchHistory();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _trxPriceController.close();
    _usdtPriceController.close();
    super.dispose();
  }

  /// Fetch latest rates with "previous-as-fallback" semantics
  Future<void> fetchRates() async {
    _loading = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=tether,tron&vs_currencies=$_fiat',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;

        final tether = (data?['tether'] as Map?)?.cast<String, dynamic>();
        final tron   = (data?['tron']   as Map?)?.cast<String, dynamic>();

        final double? usdtVal = (tether?[_fiat] as num?)?.toDouble();
        final double? trxVal  = (tron?[_fiat]   as num?)?.toDouble();

        bool gotAny = false;

        if (usdtVal != null && usdtVal > 0) {
          // move current → previous, then apply new as current
          _prevUsdtRate = _usdtRate;
          _usdtRate = usdtVal;
          gotAny = true;
        }
        if (trxVal != null && trxVal > 0) {
          _prevTrxRate = _trxRate;
          _trxRate = trxVal;
          gotAny = true;
        }

        // If API returned nothing usable, fall back to previous/current (do nothing).
        if (!gotAny) {
          // no-op: keep current; they already hold last good or fallback values
        }
      } else {
        // Non-200: keep current; if somehow current is bad, revert to previous
        _applyPreviousIfCurrentInvalid();
      }
    } on TimeoutException {
      _applyPreviousIfCurrentInvalid();
    } catch (e) {
      debugPrint("fetchRates error: $e");
      _applyPreviousIfCurrentInvalid();
    } finally {
      _loading = false;

      // push whatever we ended up with (new/current or previous/fallback) to streams
      _trxPriceController.add(_trxRate);
      _usdtPriceController.add(_usdtRate);

      notifyListeners();
    }
  }

  void _applyPreviousIfCurrentInvalid() {
    if (_usdtRate <= 0 && _prevUsdtRate > 0) {
      _usdtRate = _prevUsdtRate;
    }
    if (_trxRate <= 0 && _prevTrxRate > 0) {
      _trxRate = _prevTrxRate;
    }
    // If both current and previous were invalid (shouldn't happen with our seeded fallbacks),
    // keep the seeded fallbacks already in _usdtRate/_trxRate.
  }

  /// Fetch 7-day history for charts
  Future<void> fetchHistory() async {
    try {
      // TRX history
      final trxUrl = Uri.parse(
          'https://api.coingecko.com/api/v3/coins/tron/market_chart?vs_currency=$_fiat&days=7');
      final trxResponse = await http.get(trxUrl).timeout(const Duration(seconds: 12));
      if (trxResponse.statusCode == 200) {
        final data = jsonDecode(trxResponse.body) as Map<String, dynamic>?;
        final prices = (data?['prices'] as List?) ?? const [];
        _trxHistory = prices
            .map((e) => (e is List && e.length > 1) ? (e[1] as num?)?.toDouble() : null)
            .whereType<double>()
            .toList();
      }

      // USDT history
      final usdtUrl = Uri.parse(
          'https://api.coingecko.com/api/v3/coins/tether/market_chart?vs_currency=$_fiat&days=7');
      final usdtResponse = await http.get(usdtUrl).timeout(const Duration(seconds: 12));
      if (usdtResponse.statusCode == 200) {
        final data = jsonDecode(usdtResponse.body) as Map<String, dynamic>?;
        final prices = (data?['prices'] as List?) ?? const [];
        _usdtHistory = prices
            .map((e) => (e is List && e.length > 1) ? (e[1] as num?)?.toDouble() : null)
            .whereType<double>()
            .toList();
      }

      notifyListeners();
    } on TimeoutException catch (e) {
      debugPrint("History timeout: $e");
    } catch (e) {
      debugPrint("Failed to fetch history: $e");
    }
  }

  /// Convert TRX amount to selected fiat
  double trxToFiat(double trxAmount) => trxAmount * _trxRate;

  /// Convert USDT amount to selected fiat
  double usdtToFiat(double usdtAmount) => usdtAmount * _usdtRate;

  /// Convert fiat amount to USDT
  double fiatToUsdt(double fiatAmount) =>
      (_usdtRate != 0) ? fiatAmount / _usdtRate : 0.0;

  /// Convert fiat amount to TRX
  double fiatToTrx(double fiatAmount) =>
      (_trxRate != 0) ? fiatAmount / _trxRate : 0.0;

  /// Convert TRX amount to USDT
  double trxToUsdt(double trxAmount) =>
      (_trxRate != 0 && _usdtRate != 0) ? (trxAmount * _trxRate) / _usdtRate : 0.0;

  /// Convert USDT amount to TRX
  double usdtToTrx(double usdtAmount) =>
      (_usdtRate != 0 && _trxRate != 0) ? (usdtAmount * _usdtRate) / _trxRate : 0.0;
}
