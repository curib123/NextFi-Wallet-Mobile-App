// claimable_balance_helpers.dart
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Represents a claimable balance with user-friendly information
class ClaimableBalanceInfo {
  /// Unique ID of the claimable balance
  final String id;

  /// Asset being held
  final String assetCode;
  final String? assetIssuer;

  /// Amount of the asset
  final double amount;

  /// Account that created this claimable balance
  final String sponsor;

  /// List of accounts that can claim this balance
  final List<String> claimants;

  /// Whether this account can claim it
  final bool canClaim;

  /// Whether this was sent by the current account
  final bool isSent;

  /// Timestamp when it was last modified
  final DateTime? lastModifiedTime;

  /// Optional unlock time (for time-locked balances)
  final DateTime? unlockTime;

  /// Optional expiration time (balance becomes unclaimable for recipient)
  final DateTime? expiryTime;

  /// Status of the claimable balance
  final ClaimableBalanceStatus status;

  /// Flags for this balance
  final bool clawbackEnabled;

  ClaimableBalanceInfo({
    required this.id,
    required this.assetCode,
    this.assetIssuer,
    required this.amount,
    required this.sponsor,
    required this.claimants,
    required this.canClaim,
    required this.isSent,
    this.lastModifiedTime,
    this.unlockTime,
    this.expiryTime,
    required this.status,
    required this.clawbackEnabled,
  });

  /// Create from Stellar SDK response
  static ClaimableBalanceInfo fromResponse(
      ClaimableBalanceResponse response,
      String currentAccountId,
      ) {
    final asset = response.asset;
    String assetCode = 'XLM';
    String? assetIssuer;

    if (asset is AssetTypeCreditAlphaNum) {
      assetCode = asset.code;
      assetIssuer = asset.issuerId;
    }

    final amount = double.tryParse(response.amount) ?? 0.0;
    final sponsor = response.sponsor ?? '';
    final claimants = response.claimants.map((c) => c.destination).toList();
    final canClaim = claimants.contains(currentAccountId);
    final isSent = sponsor == currentAccountId;

    // Parse last modified time
    DateTime? lastModified;
    if (response.lastModifiedTime != null) {
      try {
        lastModified = DateTime.parse(response.lastModifiedTime!);
      } catch (e) {
        // Ignore parse errors
      }
    }

    // Extract unlock time AND expiry time from predicates
    DateTime? unlockTime;
    DateTime? expiryTime;
    for (final claimant in response.claimants) {
      if (claimant.destination == currentAccountId) {
        final parsed = _extractTimeBounds(claimant.predicate);
        unlockTime = parsed.unlockTime;
        expiryTime = parsed.expiryTime;
        break;
      }
    }

    // If current account is the sender, also check recipient predicates
    // to determine expiry for display purposes
    if (isSent && expiryTime == null) {
      for (final claimant in response.claimants) {
        if (claimant.destination != currentAccountId) {
          final parsed = _extractTimeBounds(claimant.predicate);
          // The recipient's beforeAbsoluteTime IS the expiry
          if (parsed.expiryTime != null) {
            expiryTime = parsed.expiryTime;
          }
          if (parsed.unlockTime != null && unlockTime == null) {
            unlockTime = parsed.unlockTime;
          }
          break;
        }
      }
    }

    // Determine status
    final now = DateTime.now();
    ClaimableBalanceStatus status;

    if (expiryTime != null && now.isAfter(expiryTime)) {
      // Past expiry — expired for recipient, reclaimable by sender
      if (isSent) {
        status = ClaimableBalanceStatus.reclaimable;
      } else {
        status = ClaimableBalanceStatus.expired;
      }
    } else if (unlockTime != null && now.isBefore(unlockTime)) {
      status = ClaimableBalanceStatus.locked;
    } else if (canClaim) {
      status = ClaimableBalanceStatus.claimable;
    } else if (isSent) {
      status = ClaimableBalanceStatus.sent;
    } else {
      status = ClaimableBalanceStatus.other;
    }

    return ClaimableBalanceInfo(
      id: response.balanceId,
      assetCode: assetCode,
      assetIssuer: assetIssuer,
      amount: amount,
      sponsor: sponsor,
      claimants: claimants,
      canClaim: canClaim,
      isSent: isSent,
      lastModifiedTime: lastModified,
      unlockTime: unlockTime,
      expiryTime: expiryTime,
      status: status,
      clawbackEnabled: response.flags.clawbackEnabled,
    );
  }

  /// Parsed time bounds from a predicate
  static _TimeBounds _extractTimeBounds(ClaimantPredicateResponse? predicate) {
    if (predicate == null) return _TimeBounds();

    // Unconditional — no time bounds at all
    if (predicate.unconditional == true) {
      return _TimeBounds();
    }

    // Simple beforeAbsoluteTime → this is an expiry (claim BEFORE this time)
    if (predicate.beforeAbsoluteTime != null &&
        predicate.not == null &&
        predicate.and == null &&
        predicate.or == null) {
      try {
        final expiry = DateTime.parse(predicate.beforeAbsoluteTime!);
        return _TimeBounds(expiryTime: expiry);
      } catch (_) {}
    }

    // NOT(beforeAbsoluteTime) → this is an unlock (claim AFTER this time)
    if (predicate.not != null &&
        predicate.and == null &&
        predicate.or == null) {
      final inner = predicate.not!;
      if (inner.beforeAbsoluteTime != null) {
        try {
          final unlock = DateTime.parse(inner.beforeAbsoluteTime!);
          return _TimeBounds(unlockTime: unlock);
        } catch (_) {}
      }
    }

    // AND predicates — combine unlock + expiry
    // Typical pattern: AND(NOT(beforeAbsoluteTime(unlock)), beforeAbsoluteTime(expiry))
    if (predicate.and != null && predicate.and!.isNotEmpty) {
      DateTime? unlock;
      DateTime? expiry;

      for (final p in predicate.and!) {
        final inner = _extractTimeBounds(p);
        if (inner.unlockTime != null) unlock ??= inner.unlockTime;
        if (inner.expiryTime != null) expiry ??= inner.expiryTime;
      }

      return _TimeBounds(unlockTime: unlock, expiryTime: expiry);
    }

    // OR predicates
    if (predicate.or != null && predicate.or!.isNotEmpty) {
      for (final p in predicate.or!) {
        final inner = _extractTimeBounds(p);
        if (inner.unlockTime != null || inner.expiryTime != null) {
          return inner;
        }
      }
    }

    return _TimeBounds();
  }

  // ── Legacy helper (kept for backward compatibility) ────────────────────

  /// Extract unlock time from predicate response
  static DateTime? _extractUnlockTime(ClaimantPredicateResponse? predicate) {
    return _extractTimeBounds(predicate).unlockTime;
  }

  /// Get display name for the asset
  String get assetDisplayName => assetCode == 'native' ? 'XLM' : assetCode;

  /// Get formatted amount
  String get formattedAmount => amount.toStringAsFixed(7);

  /// Get short ID (first 8 chars)
  String get shortId => id.length > 8 ? '${id.substring(0, 8)}...' : id;

  /// Get status label
  String get statusLabel {
    switch (status) {
      case ClaimableBalanceStatus.claimable:
        return 'Ready to Claim';
      case ClaimableBalanceStatus.locked:
        return 'Locked';
      case ClaimableBalanceStatus.sent:
        return 'Sent';
      case ClaimableBalanceStatus.expired:
        return 'Expired';
      case ClaimableBalanceStatus.reclaimable:
        return 'Reclaimable';
      case ClaimableBalanceStatus.other:
        return 'Not Claimable';
    }
  }

  /// Whether this balance has an expiration
  bool get hasExpiry => expiryTime != null;

  /// Whether this balance is expired
  bool get isExpired =>
      expiryTime != null && DateTime.now().isAfter(expiryTime!);

  /// Get time until expiry
  Duration? get timeUntilExpiry {
    if (expiryTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiryTime!)) return null;
    return expiryTime!.difference(now);
  }

  /// Get friendly expiry message
  String? get expiryMessage {
    if (expiryTime == null) return null;

    if (isExpired) return 'Expired';

    final duration = timeUntilExpiry;
    if (duration == null) return 'Expired';

    if (duration.inDays > 0) {
      return 'Expires in ${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return 'Expires in ${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return 'Expires in ${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Expires in ${duration.inSeconds} second${duration.inSeconds > 1 ? 's' : ''}';
    }
  }

  /// Get time until unlock (if locked)
  Duration? get timeUntilUnlock {
    if (unlockTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(unlockTime!)) return null;
    return unlockTime!.difference(now);
  }

  /// Get friendly unlock message
  String? get unlockMessage {
    if (unlockTime == null) return null;

    final duration = timeUntilUnlock;
    if (duration == null) return 'Unlocked';

    if (duration.inDays > 0) {
      return 'Unlocks in ${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return 'Unlocks in ${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return 'Unlocks in ${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Unlocks in ${duration.inSeconds} second${duration.inSeconds > 1 ? 's' : ''}';
    }
  }

  /// Get formatted last modified time
  String? get formattedLastModified {
    if (lastModifiedTime == null) return null;
    return lastModifiedTime!.toLocal().toString();
  }
}

/// Internal helper to hold parsed time bounds
class _TimeBounds {
  final DateTime? unlockTime;
  final DateTime? expiryTime;
  _TimeBounds({this.unlockTime, this.expiryTime});
}

/// Status of a claimable balance
enum ClaimableBalanceStatus {
  /// Can be claimed by current account
  claimable,

  /// Time-locked, not yet claimable
  locked,

  /// Sent by current account (still active)
  sent,

  /// Past expiry — recipient can no longer claim
  expired,

  /// Past expiry — sender can reclaim the funds
  reclaimable,

  /// Neither sent nor claimable by current account
  other,
}

/// Organize claimable balances by category
class ClaimableBalanceCategories {
  /// Balances ready to claim now
  final List<ClaimableBalanceInfo> readyToClaim;

  /// Balances that are time-locked
  final List<ClaimableBalanceInfo> locked;

  /// Balances sent by this account
  final List<ClaimableBalanceInfo> sent;

  /// Balances that have expired (recipient view)
  final List<ClaimableBalanceInfo> expired;

  /// Balances that are reclaimable (sender view)
  final List<ClaimableBalanceInfo> reclaimable;

  ClaimableBalanceCategories({
    required this.readyToClaim,
    required this.locked,
    required this.sent,
    required this.expired,
    required this.reclaimable,
  });

  /// Organize a list of balances into categories
  static ClaimableBalanceCategories organize(
      List<ClaimableBalanceInfo> balances,
      ) {
    final readyToClaim = <ClaimableBalanceInfo>[];
    final locked = <ClaimableBalanceInfo>[];
    final sent = <ClaimableBalanceInfo>[];
    final expired = <ClaimableBalanceInfo>[];
    final reclaimable = <ClaimableBalanceInfo>[];

    for (final balance in balances) {
      switch (balance.status) {
        case ClaimableBalanceStatus.claimable:
          readyToClaim.add(balance);
          break;
        case ClaimableBalanceStatus.locked:
          locked.add(balance);
          break;
        case ClaimableBalanceStatus.sent:
          sent.add(balance);
          break;
        case ClaimableBalanceStatus.expired:
          expired.add(balance);
          break;
        case ClaimableBalanceStatus.reclaimable:
          reclaimable.add(balance);
          break;
        case ClaimableBalanceStatus.other:
        // Don't include in any category
          break;
      }
    }

    return ClaimableBalanceCategories(
      readyToClaim: readyToClaim,
      locked: locked,
      sent: sent,
      expired: expired,
      reclaimable: reclaimable,
    );
  }

  /// Get total count across all categories
  int get totalCount =>
      readyToClaim.length +
          locked.length +
          sent.length +
          expired.length +
          reclaimable.length;

  /// Check if there are any balances
  bool get hasAny => totalCount > 0;

  /// Check if there are any ready to claim
  bool get hasReadyToClaim => readyToClaim.isNotEmpty;

  /// Check if there are any locked
  bool get hasLocked => locked.isNotEmpty;

  /// Check if there are any sent
  bool get hasSent => sent.isNotEmpty;

  /// Check if there are any expired
  bool get hasExpired => expired.isNotEmpty;

  /// Check if there are any reclaimable
  bool get hasReclaimable => reclaimable.isNotEmpty;
}

/// Helper extension for ClaimableBalanceResponse list
extension ClaimableBalanceListExtension on List<ClaimableBalanceResponse> {
  /// Convert to ClaimableBalanceInfo list
  List<ClaimableBalanceInfo> toInfoList(String currentAccountId) {
    return map(
          (r) => ClaimableBalanceInfo.fromResponse(r, currentAccountId),
    ).toList();
  }

  /// Organize into categories
  ClaimableBalanceCategories categorize(String currentAccountId) {
    final infoList = toInfoList(currentAccountId);
    return ClaimableBalanceCategories.organize(infoList);
  }
}

/// Summary statistics for claimable balances
class ClaimableBalanceSummary {
  /// Total value by asset
  final Map<String, double> totalByAsset;

  /// Count by status
  final Map<ClaimableBalanceStatus, int> countByStatus;

  /// Total XLM value (if applicable)
  final double totalXlm;

  /// Total USDC value (if applicable)
  final double totalUsdc;

  ClaimableBalanceSummary({
    required this.totalByAsset,
    required this.countByStatus,
    required this.totalXlm,
    required this.totalUsdc,
  });

  /// Create summary from list of balances
  static ClaimableBalanceSummary fromBalances(
      List<ClaimableBalanceInfo> balances,
      ) {
    final totalByAsset = <String, double>{};
    final countByStatus = <ClaimableBalanceStatus, int>{};
    double totalXlm = 0.0;
    double totalUsdc = 0.0;

    for (final balance in balances) {
      // Sum by asset
      final asset = balance.assetDisplayName;
      totalByAsset[asset] = (totalByAsset[asset] ?? 0.0) + balance.amount;

      // Count by status
      countByStatus[balance.status] =
          (countByStatus[balance.status] ?? 0) + 1;

      // Track XLM and USDC specifically
      if (asset == 'XLM') {
        totalXlm += balance.amount;
      } else if (asset == 'USDC') {
        totalUsdc += balance.amount;
      }
    }

    return ClaimableBalanceSummary(
      totalByAsset: totalByAsset,
      countByStatus: countByStatus,
      totalXlm: totalXlm,
      totalUsdc: totalUsdc,
    );
  }

  /// Get formatted total for an asset
  String formattedTotalFor(String assetCode) {
    final total = totalByAsset[assetCode] ?? 0.0;
    return total.toStringAsFixed(7);
  }

  /// Get total count
  int get totalCount =>
      countByStatus.values.fold(0, (sum, count) => sum + count);
}

/// Helper functions for working with predicates
class PredicateHelper {
  /// Check if a predicate is unconditional (always true)
  static bool isUnconditional(ClaimantPredicateResponse predicate) {
    return predicate.unconditional == true;
  }

  /// Check if a predicate allows claiming now
  static bool canClaimNow(ClaimantPredicateResponse predicate) {
    if (predicate.unconditional == true) return true;

    // Check absolute time predicates (must be BEFORE this time)
    if (predicate.beforeAbsoluteTime != null) {
      try {
        final deadline = DateTime.parse(predicate.beforeAbsoluteTime!);
        return DateTime.now().isBefore(deadline);
      } catch (e) {
        return false;
      }
    }

    // Check NOT predicate (after time)
    if (predicate.not != null) {
      final inner = predicate.not!;
      if (inner.beforeAbsoluteTime != null) {
        try {
          final unlockTime = DateTime.parse(inner.beforeAbsoluteTime!);
          return DateTime.now().isAfter(unlockTime);
        } catch (e) {
          return false;
        }
      }
    }

    // Check AND predicates - all must be true
    if (predicate.and != null) {
      return predicate.and!.every((p) => canClaimNow(p));
    }

    // Check OR predicates - at least one must be true
    if (predicate.or != null) {
      return predicate.or!.any((p) => canClaimNow(p));
    }

    // If we can't determine, assume false for safety
    return false;
  }

  /// Get a human-readable description of a predicate
  static String describe(ClaimantPredicateResponse predicate) {
    if (predicate.unconditional == true) {
      return 'Can claim immediately';
    }

    if (predicate.beforeAbsoluteTime != null &&
        predicate.not == null &&
        predicate.and == null) {
      try {
        final deadline = DateTime.parse(predicate.beforeAbsoluteTime!);
        if (DateTime.now().isAfter(deadline)) {
          return 'Expired on ${deadline.toLocal()}';
        }
        return 'Can claim before ${deadline.toLocal()}';
      } catch (e) {
        return 'Time-based claim condition';
      }
    }

    if (predicate.not != null) {
      final inner = predicate.not!;
      if (inner.beforeAbsoluteTime != null) {
        try {
          final unlockTime = DateTime.parse(inner.beforeAbsoluteTime!);
          return 'Can claim after ${unlockTime.toLocal()}';
        } catch (e) {
          return 'Time-locked';
        }
      }
      return 'Inverted condition: ${describe(inner)}';
    }

    if (predicate.and != null && predicate.and!.isNotEmpty) {
      final conditions = predicate.and!.map(describe).join(' AND ');
      return 'Must satisfy all: $conditions';
    }

    if (predicate.or != null && predicate.or!.isNotEmpty) {
      final conditions = predicate.or!.map(describe).join(' OR ');
      return 'Must satisfy any: $conditions';
    }

    return 'Complex claim condition';
  }
}