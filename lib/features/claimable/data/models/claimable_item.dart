// lib/features/claimable/model/claimable_item.dart

/// Parsed representation of a Stellar claimable balance for UI consumption.
class ClaimableItem {
  /// Unique identifier for this claimable balance on the Stellar network
  final String balanceId;

  /// Asset code (e.g., 'XLM', 'USDC', 'EUR')
  final String assetCode;

  /// Issuer public key for non-native assets (null for XLM)
  final String? assetIssuer;

  /// Amount of the asset that can be claimed
  final double amount;

  /// Public key of the account that created/sponsored this claimable balance
  final String sponsorId;

  /// Timestamp when this claimable balance was last modified
  final DateTime? lastModified;

  /// If the claimant predicate includes a time-lock, this is the unlock time.
  /// For NOT(before X) predicates, this is the time AFTER which claiming is allowed.
  /// For before X predicates, this is the deadline BEFORE which claiming must happen.
  final DateTime? unlockTime;

  /// Expiration time — after this, the recipient can no longer claim
  /// and the sender can reclaim the funds. Null means no expiry.
  final DateTime? expiryTime;

  /// Whether the current user can claim this balance right now.
  /// This takes into account both time-based predicates and other conditions.
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

  /// Whether this is the native Stellar asset (XLM)
  bool get isNative => assetCode == 'native' || assetCode == 'XLM';

  /// Display-friendly asset name (converts 'native' to 'XLM')
  String get displayAsset {
    if (isNative) return 'XLM';
    return assetCode;
  }

  /// Shortened sponsor address for display (first 6 + last 6 characters)
  String get shortSponsor {
    if (sponsorId.length <= 12) return sponsorId;
    return '${sponsorId.substring(0, 6)}…${sponsorId.substring(sponsorId.length - 6)}';
  }

  /// Shortened balance ID for display
  String get shortBalanceId {
    if (balanceId.length <= 16) return balanceId;
    return '${balanceId.substring(0, 8)}…${balanceId.substring(balanceId.length - 8)}';
  }

  // ── Expiry helpers ─────────────────────────────────────────────────────

  /// Whether this balance has an expiration date
  bool get hasExpiry => expiryTime != null;

  /// Whether this balance is past its expiration
  bool get isExpired =>
      expiryTime != null && DateTime.now().isAfter(expiryTime!);

  /// Time remaining until expiry (null if no expiry or already expired)
  Duration? get timeUntilExpiry {
    if (expiryTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiryTime!)) return null;
    return expiryTime!.difference(now);
  }

  /// Human-readable time remaining until expiry
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

  // ── Unlock helpers ─────────────────────────────────────────────────────

  /// Time remaining until unlock (null if not locked or already unlocked)
  Duration? get timeUntilUnlock {
    if (canClaimNow || unlockTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(unlockTime!)) return null;
    return unlockTime!.difference(now);
  }

  /// Human-readable time until unlock message
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

  // ── Status helpers ─────────────────────────────────────────────────────

  /// Status label for UI display
  String get statusLabel {
    if (isExpired) return 'Expired';
    if (canClaimNow) return 'Ready';
    if (unlockTime != null && DateTime.now().isBefore(unlockTime!)) {
      return 'Locked';
    }
    return 'Not Claimable';
  }

  /// Copy with method for creating modified instances
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

/// Mode for creating a claimable balance.
enum ClaimableMode {
  /// Recipient can claim immediately at any time
  unconditional,

  /// Recipient can only claim after a specific date/time
  timeLocked;

  /// Display label for UI
  String get label {
    switch (this) {
      case ClaimableMode.unconditional:
        return 'Immediate';
      case ClaimableMode.timeLocked:
        return 'Time-Locked';
    }
  }

  /// Description for UI
  String get description {
    switch (this) {
      case ClaimableMode.unconditional:
        return 'Recipient can claim anytime';
      case ClaimableMode.timeLocked:
        return 'Locked until specific date/time';
    }
  }
}

/// Extension methods for lists of ClaimableItems
extension ClaimableItemListExtension on List<ClaimableItem> {
  /// Filter items by asset
  List<ClaimableItem> byAsset(String assetCode) {
    return where((item) =>
    item.assetCode.toUpperCase() == assetCode.toUpperCase() ||
        (assetCode.toUpperCase() == 'XLM' && item.isNative))
        .toList();
  }

  /// Get only claimable (ready) items
  List<ClaimableItem> get ready {
    return where((item) => item.canClaimNow && !item.isExpired).toList();
  }

  /// Get only locked items (has unlock time and cannot claim now)
  List<ClaimableItem> get locked {
    return where((item) =>
    item.unlockTime != null && !item.canClaimNow && !item.isExpired)
        .toList();
  }

  /// Get only expired items
  List<ClaimableItem> get expired {
    return where((item) => item.isExpired).toList();
  }

  /// Get total amount by asset
  Map<String, double> get totalsByAsset {
    final totals = <String, double>{};
    for (final item in this) {
      final asset = item.displayAsset;
      totals[asset] = (totals[asset] ?? 0.0) + item.amount;
    }
    return totals;
  }

  /// Sort by amount (descending)
  List<ClaimableItem> sortByAmount() {
    final sorted = List<ClaimableItem>.from(this);
    sorted.sort((a, b) => b.amount.compareTo(a.amount));
    return sorted;
  }

  /// Sort by unlock time (earliest first)
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

  /// Sort by expiry time (soonest first)
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