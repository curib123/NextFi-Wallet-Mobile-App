class ClaimableItem {
  final String balanceId;

  final String assetCode;

  final String? assetIssuer;

  final double amount;

  final String sponsorId;

  final DateTime? lastModified;

  final DateTime? unlockTime;

  final DateTime? expiryTime;

  final bool canClaimNow;

  const ClaimableItem({
    required this.balanceId,
    required this.assetCode,
    this.assetIssuer,
    required this.amount,
    required this.sponsorId,
    this.lastModified,
    this.unlockTime,
    this.expiryTime,
    required this.canClaimNow,
  });

  bool get isNative => assetCode == 'native' || assetCode == 'XLM';

  String get displayAsset {
    if (isNative) return 'XLM';
    return assetCode;
  }

  String get shortSponsor {
    if (sponsorId.length <= 12) return sponsorId;
    return '${sponsorId.substring(0, 6)}…${sponsorId.substring(sponsorId.length - 6)}';
  }

  String get shortBalanceId {
    if (balanceId.length <= 16) return balanceId;
    return '${balanceId.substring(0, 8)}…${balanceId.substring(balanceId.length - 8)}';
  }

  bool get hasExpiry => expiryTime != null;

  bool get isExpired =>
      expiryTime != null && DateTime.now().isAfter(expiryTime!);

  Duration? get timeUntilExpiry {
    if (expiryTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiryTime!)) return null;
    return expiryTime!.difference(now);
  }

  String? get expiryTimeRemaining {
    final duration = timeUntilExpiry;
    if (duration == null) return null;

    if (duration.inDays > 0) {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      return '${days}d ${hours}h';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'moments';
    }
  }

  Duration? get timeUntilUnlock {
    if (canClaimNow || unlockTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(unlockTime!)) return null;
    return unlockTime!.difference(now);
  }

  String? get unlockTimeRemaining {
    final duration = timeUntilUnlock;
    if (duration == null) return null;

    if (duration.inDays > 0) {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      return '${days}d ${hours}h';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'moments';
    }
  }

  String get statusLabel {
    if (isExpired) return 'Expired';
    if (canClaimNow) return 'Ready';
    if (unlockTime != null && DateTime.now().isBefore(unlockTime!)) {
      return 'Locked';
    }
    return 'Not Claimable';
  }

  ClaimableItem copyWith({
    String? balanceId,
    String? assetCode,
    String? assetIssuer,
    double? amount,
    String? sponsorId,
    DateTime? lastModified,
    DateTime? unlockTime,
    DateTime? expiryTime,
    bool? canClaimNow,
  }) {
    return ClaimableItem(
      balanceId: balanceId ?? this.balanceId,
      assetCode: assetCode ?? this.assetCode,
      assetIssuer: assetIssuer ?? this.assetIssuer,
      amount: amount ?? this.amount,
      sponsorId: sponsorId ?? this.sponsorId,
      lastModified: lastModified ?? this.lastModified,
      unlockTime: unlockTime ?? this.unlockTime,
      expiryTime: expiryTime ?? this.expiryTime,
      canClaimNow: canClaimNow ?? this.canClaimNow,
    );
  }

  @override
  String toString() {
    return 'ClaimableItem('
        'id: $shortBalanceId, '
        'asset: $displayAsset, '
        'amount: $amount, '
        'canClaim: $canClaimNow, '
        'locked: ${unlockTime != null && !canClaimNow}, '
        'expired: $isExpired'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClaimableItem && other.balanceId == balanceId;
  }

  @override
  int get hashCode => balanceId.hashCode;
}

enum ClaimableMode {
  unconditional,

  timeLocked;

  String get label {
    switch (this) {
      case ClaimableMode.unconditional:
        return 'Immediate';
      case ClaimableMode.timeLocked:
        return 'Time-Locked';
    }
  }

  String get description {
    switch (this) {
      case ClaimableMode.unconditional:
        return 'Recipient can claim anytime';
      case ClaimableMode.timeLocked:
        return 'Locked until specific date/time';
    }
  }
}

extension ClaimableItemListExtension on List<ClaimableItem> {
  List<ClaimableItem> byAsset(String assetCode) {
    return where(
      (item) =>
          item.assetCode.toUpperCase() == assetCode.toUpperCase() ||
          (assetCode.toUpperCase() == 'XLM' && item.isNative),
    ).toList();
  }

  List<ClaimableItem> get ready {
    return where((item) => item.canClaimNow && !item.isExpired).toList();
  }

  List<ClaimableItem> get locked {
    return where(
      (item) => item.unlockTime != null && !item.canClaimNow && !item.isExpired,
    ).toList();
  }

  List<ClaimableItem> get expired {
    return where((item) => item.isExpired).toList();
  }

  Map<String, double> get totalsByAsset {
    final totals = <String, double>{};
    for (final item in this) {
      final asset = item.displayAsset;
      totals[asset] = (totals[asset] ?? 0.0) + item.amount;
    }
    return totals;
  }

  List<ClaimableItem> sortByAmount() {
    final sorted = List<ClaimableItem>.from(this);
    sorted.sort((a, b) => b.amount.compareTo(a.amount));
    return sorted;
  }

  List<ClaimableItem> sortByUnlockTime() {
    final sorted = List<ClaimableItem>.from(this);
    sorted.sort((a, b) {
      if (a.unlockTime == null && b.unlockTime == null) return 0;
      if (a.unlockTime == null) return 1;
      if (b.unlockTime == null) return -1;
      return a.unlockTime!.compareTo(b.unlockTime!);
    });
    return sorted;
  }

  List<ClaimableItem> sortByExpiryTime() {
    final sorted = List<ClaimableItem>.from(this);
    sorted.sort((a, b) {
      if (a.expiryTime == null && b.expiryTime == null) return 0;
      if (a.expiryTime == null) return 1;
      if (b.expiryTime == null) return -1;
      return a.expiryTime!.compareTo(b.expiryTime!);
    });
    return sorted;
  }
}
