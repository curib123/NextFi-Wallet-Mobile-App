enum PortfolioRange { h24, d7, d30, all }

enum WalletSnapshotTrigger {
  appOpen,
  send,
  swap,
  claim,
  receiveDetected,
  walletSwitch,
  manualRefresh,
}

class PortfolioChartPoint {
  const PortfolioChartPoint({
    required this.timestamp,
    required this.totalValue,
  });

  final DateTime timestamp;
  final double totalValue;

  factory PortfolioChartPoint.fromJson(Map<String, dynamic> json) {
    return PortfolioChartPoint(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      totalValue: _readDouble(json['totalValue']),
    );
  }
}

class PortfolioAllocationItem {
  const PortfolioAllocationItem({
    required this.code,
    required this.issuer,
    required this.balance,
    required this.price,
    required this.fiatValue,
    required this.allocationPercent,
  });

  final String code;
  final String? issuer;
  final double balance;
  final double price;
  final double fiatValue;
  final double allocationPercent;

  factory PortfolioAllocationItem.fromJson(Map<String, dynamic> json) {
    return PortfolioAllocationItem(
      code: (json['code']?.toString() ?? '').trim().toUpperCase(),
      issuer: json['issuer']?.toString(),
      balance: _readDouble(json['balance']),
      price: _readDouble(json['price']),
      fiatValue: _readDouble(json['fiatValue']),
      allocationPercent: _readDouble(json['allocationPercent']),
    );
  }
}

class PortfolioActivityItem {
  const PortfolioActivityItem({
    required this.id,
    required this.trigger,
    required this.timestamp,
    required this.totalValue,
    required this.fiatCurrency,
  });

  final String id;
  final WalletSnapshotTrigger trigger;
  final DateTime timestamp;
  final double totalValue;
  final String fiatCurrency;

  factory PortfolioActivityItem.fromJson(Map<String, dynamic> json) {
    return PortfolioActivityItem(
      id: json['id']?.toString() ?? '',
      trigger: portfolioTriggerFromApi(json['trigger']?.toString()),
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      totalValue: _readDouble(json['totalValue']),
      fiatCurrency: (json['fiatCurrency']?.toString() ?? 'USD')
          .trim()
          .toUpperCase(),
    );
  }
}

class PortfolioSummary {
  const PortfolioSummary({
    required this.totalValue,
    required this.fiatCurrency,
    required this.absoluteChange,
    required this.percentChange,
    required this.lastUpdated,
  });

  final double totalValue;
  final String fiatCurrency;
  final double absoluteChange;
  final double percentChange;
  final DateTime lastUpdated;

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) {
    return PortfolioSummary(
      totalValue: _readDouble(json['totalValue']),
      fiatCurrency: (json['fiatCurrency']?.toString() ?? 'USD')
          .trim()
          .toUpperCase(),
      absoluteChange: _readDouble(json['absoluteChange']),
      percentChange: _readDouble(json['percentChange']),
      lastUpdated:
          DateTime.tryParse(json['lastUpdated']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class WalletPortfolioData {
  const WalletPortfolioData({
    required this.walletId,
    required this.walletAddress,
    required this.walletLabel,
    required this.range,
    required this.summary,
    required this.chart,
    required this.allocation,
    required this.activity,
  });

  final String walletId;
  final String walletAddress;
  final String? walletLabel;
  final PortfolioRange range;
  final PortfolioSummary? summary;
  final List<PortfolioChartPoint> chart;
  final List<PortfolioAllocationItem> allocation;
  final List<PortfolioActivityItem> activity;

  factory WalletPortfolioData.fromJson(Map<String, dynamic> json) {
    final wallet = (json['wallet'] is Map)
        ? Map<String, dynamic>.from(json['wallet'] as Map)
        : const <String, dynamic>{};
    final summaryJson = json['summary'];
    return WalletPortfolioData(
      walletId: wallet['id']?.toString() ?? '',
      walletAddress: wallet['address']?.toString() ?? '',
      walletLabel: wallet['label']?.toString(),
      range: portfolioRangeFromApi(json['range']?.toString()),
      summary: summaryJson is Map<String, dynamic>
          ? PortfolioSummary.fromJson(summaryJson)
          : summaryJson is Map
          ? PortfolioSummary.fromJson(Map<String, dynamic>.from(summaryJson))
          : null,
      chart: ((json['chart'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => PortfolioChartPoint.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false),
      allocation: ((json['allocation'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => PortfolioAllocationItem.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false),
      activity: ((json['activity'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => PortfolioActivityItem.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false),
    );
  }
}

class CreatePortfolioSnapshotAssetRequest {
  const CreatePortfolioSnapshotAssetRequest({
    required this.code,
    required this.issuer,
    required this.balance,
    required this.price,
    required this.fiatValue,
    required this.allocationPercent,
  });

  final String code;
  final String? issuer;
  final double balance;
  final double price;
  final double fiatValue;
  final double allocationPercent;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'issuer': issuer,
      'balance': balance,
      'price': price,
      'fiatValue': fiatValue,
      'allocationPercent': allocationPercent,
    };
  }
}

class CreatePortfolioSnapshotRequest {
  const CreatePortfolioSnapshotRequest({
    required this.walletId,
    required this.walletAddress,
    required this.timestamp,
    required this.trigger,
    required this.dedupeKey,
    required this.assets,
    required this.totalValue,
    required this.fiatCurrency,
    this.appVersion,
  });

  final String walletId;
  final String walletAddress;
  final DateTime timestamp;
  final WalletSnapshotTrigger trigger;
  final String dedupeKey;
  final List<CreatePortfolioSnapshotAssetRequest> assets;
  final double totalValue;
  final String fiatCurrency;
  final String? appVersion;

  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'walletAddress': walletAddress,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'trigger': portfolioTriggerToApi(trigger),
      'dedupeKey': dedupeKey,
      'assets': assets.map((asset) => asset.toJson()).toList(growable: false),
      'totalValue': totalValue,
      'fiatCurrency': fiatCurrency.toUpperCase(),
      if (appVersion != null && appVersion!.trim().isNotEmpty)
        'appVersion': appVersion!.trim(),
    };
  }
}

PortfolioRange portfolioRangeFromApi(String? value) {
  switch ((value ?? '').trim().toUpperCase()) {
    case '7D':
      return PortfolioRange.d7;
    case '30D':
      return PortfolioRange.d30;
    case 'ALL':
      return PortfolioRange.all;
    case '24H':
    default:
      return PortfolioRange.h24;
  }
}

String portfolioRangeToApi(PortfolioRange range) {
  switch (range) {
    case PortfolioRange.h24:
      return '24H';
    case PortfolioRange.d7:
      return '7D';
    case PortfolioRange.d30:
      return '30D';
    case PortfolioRange.all:
      return 'ALL';
  }
}

WalletSnapshotTrigger portfolioTriggerFromApi(String? value) {
  switch ((value ?? '').trim().toUpperCase()) {
    case 'SEND':
      return WalletSnapshotTrigger.send;
    case 'SWAP':
      return WalletSnapshotTrigger.swap;
    case 'CLAIM':
      return WalletSnapshotTrigger.claim;
    case 'RECEIVE_DETECTED':
      return WalletSnapshotTrigger.receiveDetected;
    case 'WALLET_SWITCH':
      return WalletSnapshotTrigger.walletSwitch;
    case 'MANUAL_REFRESH':
      return WalletSnapshotTrigger.manualRefresh;
    case 'APP_OPEN':
    default:
      return WalletSnapshotTrigger.appOpen;
  }
}

String portfolioTriggerToApi(WalletSnapshotTrigger trigger) {
  switch (trigger) {
    case WalletSnapshotTrigger.appOpen:
      return 'APP_OPEN';
    case WalletSnapshotTrigger.send:
      return 'SEND';
    case WalletSnapshotTrigger.swap:
      return 'SWAP';
    case WalletSnapshotTrigger.claim:
      return 'CLAIM';
    case WalletSnapshotTrigger.receiveDetected:
      return 'RECEIVE_DETECTED';
    case WalletSnapshotTrigger.walletSwitch:
      return 'WALLET_SWITCH';
    case WalletSnapshotTrigger.manualRefresh:
      return 'MANUAL_REFRESH';
  }
}

double _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0.0;
  return 0.0;
}
