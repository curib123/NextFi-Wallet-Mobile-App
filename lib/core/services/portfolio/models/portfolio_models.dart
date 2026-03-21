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
      totalValue: _toDouble(json['totalValue']),
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
      code: json['code']?.toString() ?? '',
      issuer: json['issuer']?.toString(),
      balance: _toDouble(json['balance']),
      price: _toDouble(json['price']),
      fiatValue: _toDouble(json['fiatValue']),
      allocationPercent: _toDouble(json['allocationPercent']),
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
      trigger: walletSnapshotTriggerFromApi(json['trigger']?.toString()),
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      totalValue: _toDouble(json['totalValue']),
      fiatCurrency: json['fiatCurrency']?.toString() ?? 'USD',
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
      totalValue: _toDouble(json['totalValue']),
      fiatCurrency: json['fiatCurrency']?.toString() ?? 'USD',
      absoluteChange: _toDouble(json['absoluteChange']),
      percentChange: _toDouble(json['percentChange']),
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
    final wallet = (json['wallet'] as Map?)?.cast<String, dynamic>() ?? const {};
    return WalletPortfolioData(
      walletId: wallet['id']?.toString() ?? '',
      walletAddress: wallet['address']?.toString() ?? '',
      walletLabel: wallet['label']?.toString(),
      range: portfolioRangeFromApi(json['range']?.toString()),
      summary: json['summary'] is Map<String, dynamic>
          ? PortfolioSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : json['summary'] is Map
          ? PortfolioSummary.fromJson(
              (json['summary'] as Map).cast<String, dynamic>(),
            )
          : null,
      chart: ((json['chart'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => PortfolioChartPoint.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      allocation: ((json['allocation'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => PortfolioAllocationItem.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      activity: ((json['activity'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                PortfolioActivityItem.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
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

String walletSnapshotTriggerToApi(WalletSnapshotTrigger trigger) {
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

WalletSnapshotTrigger walletSnapshotTriggerFromApi(String? value) {
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

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
