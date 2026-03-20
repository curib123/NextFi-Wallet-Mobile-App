import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/core/services/countries/models/country_model.dart';

class CountryService {
  CountryService._();

  static final CountryService I = CountryService._();

  static const _apiUrl =
      'https://restcountries.com/v3.1/all?fields=name,flag,cca2';

  static const _cacheTtl = Duration(hours: 24);

  List<CountryModel>? _cache;
  DateTime? _cachedAt;

  bool get _isCacheValid =>
      _cache != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _cacheTtl;

  Future<List<CountryModel>> getAll() async {
    if (_isCacheValid) return _cache!;

    final response = await http
        .get(Uri.parse(_apiUrl))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to load countries (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    final countries =
        data
            .map((e) => CountryModel.fromJson(e as Map<String, dynamic>))
            .where((c) => c.name.isNotEmpty)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    _cache = countries;
    _cachedAt = DateTime.now();
    return countries;
  }

  void clearCache() {
    _cache = null;
    _cachedAt = null;
  }
}
