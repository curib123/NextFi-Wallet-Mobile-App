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

    // Try to extract unlock time from predicates
    DateTime? unlockTime;
    for (final claimant in response.claimants) {
      if (claimant.destination == currentAccountId) {
        unlockTime = _extractUnlockTime(claimant.predicate);
        break;
      }
    }

    // Determine status
    ClaimableBalanceStatus status;
    if (unlockTime != null && DateTime.now().isBefore(unlockTime)) {
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
      status: status,
      clawbackEnabled: response.flags.clawbackEnabled,
    );
  }

  /// Extract unlock time from predicate response
  static DateTime? _extractUnlockTime(ClaimantPredicateResponse? predicate) {
    if (predicate == null) return null;

    // Handle unconditional - no unlock time
    if (predicate.unconditional == true) {
      return null;
    }

    // Handle NOT predicate (common for time locks: NOT(before X) means "after X")
    if (predicate.not != null) {
      final inner = predicate.not!;
      if (inner.beforeAbsoluteTime != null) {
        // Parse ISO 8601 timestamp
        try {
          return DateTime.parse(inner.beforeAbsoluteTime!);
        } catch (e) {
          return null;
        }
      }
      if (inner.beforeRelativeTime != null) {
        // Relative time predicates need the creation time
        // We don't have access to that here, so we can't calculate exact time
        return null;
      }
    }

    // Handle direct absolute time predicate (can claim BEFORE this time)
    if (predicate.beforeAbsoluteTime != null) {
      try {
        return DateTime.parse(predicate.beforeAbsoluteTime!);
      } catch (e) {
        return null;
      }
    }

    // Handle AND predicates recursively
    if (predicate.and != null) {
      for (final p in predicate.and!) {
        final time = _extractUnlockTime(p);
        if (time != null) return time;
      }
    }

    // Handle OR predicates recursively
    if (predicate.or != null) {
      for (final p in predicate.or!) {
        final time = _extractUnlockTime(p);
        if (time != null) return time;
      }
    }

    return null;
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
      case ClaimableBalanceStatus.other:
        return 'Not Claimable';
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

/// Status of a claimable balance
enum ClaimableBalanceStatus {
  /// Can be claimed by current account
  claimable,

  /// Time-locked, not yet claimable
  locked,

  /// Sent by current account
  sent,

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

  ClaimableBalanceCategories({
    required this.readyToClaim,
    required this.locked,
    required this.sent,
  });

  /// Organize a list of balances into categories
  static ClaimableBalanceCategories organize(
      List<ClaimableBalanceInfo> balances,
      ) {
    final readyToClaim = <ClaimableBalanceInfo>[];
    final locked = <ClaimableBalanceInfo>[];
    final sent = <ClaimableBalanceInfo>[];

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
        case ClaimableBalanceStatus.other:
        // Don't include in any category
          break;
      }
    }

    return ClaimableBalanceCategories(
      readyToClaim: readyToClaim,
      locked: locked,
      sent: sent,
    );
  }

  /// Get total count across all categories
  int get totalCount => readyToClaim.length + locked.length + sent.length;

  /// Check if there are any balances
  bool get hasAny => totalCount > 0;

  /// Check if there are any ready to claim
  bool get hasReadyToClaim => readyToClaim.isNotEmpty;

  /// Check if there are any locked
  bool get hasLocked => locked.isNotEmpty;

  /// Check if there are any sent
  bool get hasSent => sent.isNotEmpty;
}

/// Helper extension for ClaimableBalanceResponse list
extension ClaimableBalanceListExtension on List<ClaimableBalanceResponse> {
  /// Convert to ClaimableBalanceInfo list
  List<ClaimableBalanceInfo> toInfoList(String currentAccountId) {
    return map((r) => ClaimableBalanceInfo.fromResponse(r, currentAccountId)).toList();
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
      countByStatus[balance.status] = (countByStatus[balance.status] ?? 0) + 1;

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
  int get totalCount => countByStatus.values.fold(0, (sum, count) => sum + count);
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

    // Check absolute time predicates
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

    if (predicate.beforeAbsoluteTime != null) {
      try {
        final deadline = DateTime.parse(predicate.beforeAbsoluteTime!);
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