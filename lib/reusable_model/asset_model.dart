import 'package:flutter/foundation.dart';

/// What kind of asset this is.
enum AssetKind { native, token, fiat }

@immutable
class AssetModel {
  // ---- Identity -------------------------------------------------------------
  final String id;          // stable internal id, e.g. "stellar", "usdc_stellar"
  final String name;        // "Stellar Lumens"
  final String symbol;      // "XLM"
  final String chain;       // "stellar", "ethereum", "solana", ...
  final String network;     // "mainnet", "testnet", etc.
  final AssetKind kind;     // native / token / fiat

  /// For chain-specific identification (nullable when not applicable)
  final bool isNative;      // true for XLM on Stellar mainnet
  final String? assetCode;  // e.g. "USDC" on Stellar
  final String? issuer;     // e.g. Stellar issuer (G...)
  final String? contract;   // e.g. ERC-20 address
  final int? decimals;      // display/quantization precision if known

  // ---- Display & classification --------------------------------------------
  /// Primary logo followed by fallbacks (SVG/PNG/CDNs). First valid URL wins.
  final List<String> logoUris;

  /// Other names/symbols/keys you may match: ["xlm","stellar","XLM"]
  final List<String> aliases;

  /// Free-form labels: ["stablecoin", "layer1", "official", "featured"]
  final List<String> tags;

  /// External provider ids (CoinGecko, CMC, etc.)
  final Map<String, String> externalIds;

  /// Explorer templates/links; choose keys like: "asset","account","tx"
  final Map<String, String> explorer;

  /// Feature gating & ordering
  final bool enabled;
  final int sortOrder; // lower shows earlier (0..n)

  // ---- Market deltas --------------------------------------------------------
  final double priceChangePercent24h;
  final double priceChangePercent7d;
  final double priceChangePercent30d;
  final double priceChangePercent1y;

  const AssetModel({
    // identity
    required this.id,
    required this.name,
    required this.symbol,
    this.chain = 'stellar',
    this.network = 'mainnet',
    this.kind = AssetKind.token,
    this.isNative = false,
    this.assetCode,
    this.issuer,
    this.contract,
    this.decimals,

    // display & classification
    this.logoUris = const [],
    this.aliases = const [],
    this.tags = const [],
    this.externalIds = const {},
    this.explorer = const {},
    this.enabled = true,
    this.sortOrder = 0,

    // market deltas
    this.priceChangePercent24h = 0.0,
    this.priceChangePercent7d = 0.0,
    this.priceChangePercent30d = 0.0,
    this.priceChangePercent1y = 0.0,
  });

  // ---- Convenience ----------------------------------------------------------
  String get primaryLogo =>
      logoUris.firstWhere((u) => u.trim().isNotEmpty, orElse: () => '');

  bool matchesKey(String key) {
    final k = key.trim().toLowerCase();
    if (k.isEmpty) return false;
    final set = {
      id,
      name,
      symbol,
      ...aliases,
      if (assetCode != null) assetCode!,
      if (issuer != null) issuer!,
      if (contract != null) contract!,
    }.map((s) => s.toLowerCase());
    return set.contains(k);
  }

  AssetModel copyWith({
    String? id,
    String? name,
    String? symbol,
    String? chain,
    String? network,
    AssetKind? kind,
    bool? isNative,
    String? assetCode,
    String? issuer,
    String? contract,
    int? decimals,
    List<String>? logoUris,
    List<String>? aliases,
    List<String>? tags,
    Map<String, String>? externalIds,
    Map<String, String>? explorer,
    bool? enabled,
    int? sortOrder,
    double? priceChangePercent24h,
    double? priceChangePercent7d,
    double? priceChangePercent30d,
    double? priceChangePercent1y,
  }) {
    return AssetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      chain: chain ?? this.chain,
      network: network ?? this.network,
      kind: kind ?? this.kind,
      isNative: isNative ?? this.isNative,
      assetCode: assetCode ?? this.assetCode,
      issuer: issuer ?? this.issuer,
      contract: contract ?? this.contract,
      decimals: decimals ?? this.decimals,
      logoUris: logoUris ?? this.logoUris,
      aliases: aliases ?? this.aliases,
      tags: tags ?? this.tags,
      externalIds: externalIds ?? this.externalIds,
      explorer: explorer ?? this.explorer,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      priceChangePercent24h:
      priceChangePercent24h ?? this.priceChangePercent24h,
      priceChangePercent7d: priceChangePercent7d ?? this.priceChangePercent7d,
      priceChangePercent30d:
      priceChangePercent30d ?? this.priceChangePercent30d,
      priceChangePercent1y: priceChangePercent1y ?? this.priceChangePercent1y,
    );
  }

  // ---- JSON ----------------------------------------------------------------
  factory AssetModel.fromJson(Map<String, dynamic> json) {
    return AssetModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
      chain: json['chain'] ?? 'stellar',
      network: json['network'] ?? 'mainnet',
      kind: _kindFromString(json['kind']),
      isNative: json['isNative'] ?? false,
      assetCode: json['assetCode'],
      issuer: json['issuer'],
      contract: json['contract'],
      decimals: json['decimals'],
      logoUris: (json['logoUris'] as List?)?.cast<String>() ?? const [],
      aliases: (json['aliases'] as List?)?.cast<String>() ?? const [],
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      externalIds:
      (json['externalIds'] as Map?)?.cast<String, String>() ?? const {},
      explorer:
      (json['explorer'] as Map?)?.cast<String, String>() ?? const {},
      enabled: json['enabled'] ?? true,
      sortOrder: json['sortOrder'] ?? 0,
      priceChangePercent24h:
      (json['priceChangePercent24h'] ?? 0).toDouble(),
      priceChangePercent7d: (json['priceChangePercent7d'] ?? 0).toDouble(),
      priceChangePercent30d: (json['priceChangePercent30d'] ?? 0).toDouble(),
      priceChangePercent1y: (json['priceChangePercent1y'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'chain': chain,
      'network': network,
      'kind': describeEnum(kind),
      'isNative': isNative,
      'assetCode': assetCode,
      'issuer': issuer,
      'contract': contract,
      'decimals': decimals,
      'logoUris': logoUris,
      'aliases': aliases,
      'tags': tags,
      'externalIds': externalIds,
      'explorer': explorer,
      'enabled': enabled,
      'sortOrder': sortOrder,
      'priceChangePercent24h': priceChangePercent24h,
      'priceChangePercent7d': priceChangePercent7d,
      'priceChangePercent30d': priceChangePercent30d,
      'priceChangePercent1y': priceChangePercent1y,
    };
  }

  static AssetKind _kindFromString(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    switch (s) {
      case 'native':
        return AssetKind.native;
      case 'fiat':
        return AssetKind.fiat;
      case 'token':
      default:
        return AssetKind.token;
    }
  }

  // ---- Equality (by id + chain + network) ----------------------------------
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AssetModel &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              chain == other.chain &&
              network == other.network;

  @override
  int get hashCode => Object.hash(id, chain, network);

  @override
  String toString() => 'AssetModel($id $chain/$network $symbol)';
}
