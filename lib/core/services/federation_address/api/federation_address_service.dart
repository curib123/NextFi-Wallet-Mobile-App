import 'dart:convert';

import 'package:http/http.dart' as http;

import '../helpers/federation_address_exceptions.dart';
import '../helpers/federation_address_helpers.dart';
import '../models/federation_address_dtos.dart';
import '../models/federation_address_models.dart';
import 'federation_address_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class FederationAddressService {
  FederationAddressService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  Future<Map<String, String>> _publicHeaders() async {
    return const {'Content-Type': 'application/json'};
  }

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Missing JWT token');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic>? _extractMap(
    dynamic data, {
    List<String> keys = const [],
  }) {
    if (data == null || data == '') return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;

    if (data is Map<String, dynamic>) {
      if (data.isEmpty) return null;
      for (final key in keys) {
        final wrapped = data[key];
        if (wrapped is Map<String, dynamic>) return wrapped;
      }
      if (keys.isNotEmpty &&
          data.length == 1 &&
          keys.contains(data.keys.first) &&
          data.values.first == null) {
        return null;
      }
      return data;
    }
    return null;
  }

  List<dynamic> _extractList(dynamic data, {List<String> keys = const []}) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final wrapped = data[key];
        if (wrapped is List) return wrapped;
      }
    }
    return const [];
  }

  Future<FederationResolveResponse> resolvePublic(
    FederationLookupQuery query,
  ) async {
    final res = await _client.get(
      FederationAddressHttp.publicUri(
        FederationAddressEndpoints.publicFederation,
        queryParams: query.toQueryMap(),
      ),
      headers: await _publicHeaders(),
    );

    FederationAddressHttp.ensureOk(res);
    final data = FederationAddressHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'result']);

    if (map != null) {
      return FederationResolveResponse.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /federation',
      body: res.body,
    );
  }

  Future<String> getPublicStellarToml() async {
    final res = await _client.get(
      FederationAddressHttp.publicUri(FederationAddressEndpoints.publicToml),
      headers: const {'Accept': 'text/plain'},
    );

    FederationAddressHttp.ensureOk(res);
    return res.body;
  }

  Future<List<FederationAddressModel>> listMine() async {
    final res = await _client.get(
      FederationAddressHttp.uri(FederationAddressEndpoints.myList()),
      headers: await _headers(),
    );

    FederationAddressHttp.ensureOk(res);
    final data = FederationAddressHttp.decodeJson<dynamic>(res);
    final list = _extractList(
      data,
      keys: const ['data', 'items', 'federationAddresses'],
    );

    return list
        .whereType<Map<String, dynamic>>()
        .map(FederationAddressModel.fromJson)
        .toList();
  }

  Future<FederationAddressModel> create(
    CreateFederationAddressRequest req,
  ) async {
    final res = await _client.post(
      FederationAddressHttp.uri(FederationAddressEndpoints.create()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    FederationAddressHttp.ensureOk(res);
    final data = FederationAddressHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'federationAddress']);

    if (map != null) {
      return FederationAddressModel.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /federation-address',
      body: res.body,
    );
  }

  Future<FederationAddressModel> update(
    String id,
    UpdateFederationAddressRequest req,
  ) async {
    final res = await _client.patch(
      FederationAddressHttp.uri(FederationAddressEndpoints.byId(id)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    FederationAddressHttp.ensureOk(res);
    final data = FederationAddressHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'federationAddress']);

    if (map != null) {
      return FederationAddressModel.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /federation-address/$id',
      body: res.body,
    );
  }

  Future<bool> delete(String id) async {
    final res = await _client.delete(
      FederationAddressHttp.uri(FederationAddressEndpoints.byId(id)),
      headers: await _headers(),
    );

    FederationAddressHttp.ensureOk(res);
    final data = FederationAddressHttp.decodeJson<dynamic>(res);
    if (data is Map<String, dynamic>) {
      final wrapped = data['data'];
      if (wrapped is Map<String, dynamic>) {
        return wrapped['success'] != false;
      }
      return data['success'] != false;
    }
    return true;
  }

  Future<FederationResolveResponse> resolveExternal(
    FederationLookupQuery query, {
    bool useLegacyPath = false,
  }) async {
    final path = useLegacyPath
        ? FederationAddressEndpoints.resolveLegacy()
        : FederationAddressEndpoints.resolveExternal();

    final res = await _client.get(
      FederationAddressHttp.uri(path, queryParams: query.toQueryMap()),
      headers: await _headers(),
    );

    FederationAddressHttp.ensureOk(res);
    final data = FederationAddressHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'result']);

    if (map != null) {
      return FederationResolveResponse.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET $path',
      body: res.body,
    );
  }
}
