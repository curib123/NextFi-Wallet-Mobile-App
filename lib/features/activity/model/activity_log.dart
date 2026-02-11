// lib/features/activity/model/activity_log.dart

/// Activity types for different blockchain operations
enum ActivityType {
  // Payment activities
  sendXlm('Send XLM', '💸'),
  sendUsdc('Send USDC', '💵'),
  receiveXlm('Receive XLM', '✅'),
  receiveUsdc('Receive USDC', '✅'),

  // Swap activities
  swapXlmToUsdc('Swap XLM → USDC', '🔄'),
  swapUsdcToXlm('Swap USDC → XLM', '🔄'),

  // Claimable balance activities
  createClaimable('Create Claimable', '🎁'),
  claimBalance('Claim Payment', '🎉'),
  reclaimBalance('Reclaim Payment', '↩️'),

  // Account activities
  createTrustline('Add Asset', '➕'),
  removeTrustline('Remove Asset', '➖'),
  createAccount('Create Account', '🆕'),

  // DEX activities
  createOffer('Create Order', '📊'),
  cancelOffer('Cancel Order', '❌'),
  offerFilled('Order Filled', '✅'),

  // Wallet activities
  importWallet('Import Wallet', '📥'),
  createWallet('Create Wallet', '🔐'),
  backupWallet('Backup Wallet', '💾'),

  // System activities
  error('Error', '⚠️'),
  warning('Warning', '⚡'),
  info('Info', 'ℹ️'),
  success('Success', '✨');

  final String label;
  final String emoji;

  const ActivityType(this.label, this.emoji);
}

/// Activity status for tracking operation progress
enum ActivityStatus {
  pending('Pending', '⏳'),
  processing('Processing', '⚙️'),
  completed('Completed', '✅'),
  failed('Failed', '❌'),
  cancelled('Cancelled', '🚫');

  final String label;
  final String emoji;

  const ActivityStatus(this.label, this.emoji);
}

/// Activity log entry for audit trail
class ActivityLog {
  final String id;
  final ActivityType type;
  final ActivityStatus status;
  final DateTime timestamp;
  final String title;
  final String? description;
  final Map<String, dynamic>? metadata;
  final String? txHash;
  final String? errorMessage;
  final String? errorAdvice;
  final double? amount;
  final String? asset;
  final String? fromAddress;
  final String? toAddress;

  ActivityLog({
    required this.id,
    required this.type,
    required this.status,
    required this.timestamp,
    required this.title,
    this.description,
    this.metadata,
    this.txHash,
    this.errorMessage,
    this.errorAdvice,
    this.amount,
    this.asset,
    this.fromAddress,
    this.toAddress,
  });

  /// Create a payment activity log
  factory ActivityLog.payment({
    required String id,
    required bool isSending,
    required double amount,
    required String asset,
    required String fromAddress,
    required String toAddress,
    ActivityStatus status = ActivityStatus.pending,
    String? txHash,
    String? errorMessage,
    String? errorAdvice,
  }) {
    final type = isSending
        ? (asset == 'XLM' ? ActivityType.sendXlm : ActivityType.sendUsdc)
        : (asset == 'XLM' ? ActivityType.receiveXlm : ActivityType.receiveUsdc);

    final verb = isSending ? 'Sending' : 'Receiving';
    final preposition = isSending ? 'to' : 'from';
    final address = isSending ? toAddress : fromAddress;
    final shortAddress = '${address.substring(0, 4)}...${address.substring(address.length - 4)}';

    return ActivityLog(
      id: id,
      type: type,
      status: status,
      timestamp: DateTime.now(),
      title: '$verb ${amount.toStringAsFixed(2)} $asset',
      description: '$preposition $shortAddress',
      amount: amount,
      asset: asset,
      fromAddress: fromAddress,
      toAddress: toAddress,
      txHash: txHash,
      errorMessage: errorMessage,
      errorAdvice: errorAdvice,
      metadata: {
        'direction': isSending ? 'out' : 'in',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Create a swap activity log
  factory ActivityLog.swap({
    required String id,
    required double sendAmount,
    required String sendAsset,
    required double receiveAmount,
    required String receiveAsset,
    ActivityStatus status = ActivityStatus.pending,
    String? txHash,
    String? errorMessage,
    String? errorAdvice,
  }) {
    final type = sendAsset == 'XLM'
        ? ActivityType.swapXlmToUsdc
        : ActivityType.swapUsdcToXlm;

    return ActivityLog(
      id: id,
      type: type,
      status: status,
      timestamp: DateTime.now(),
      title: 'Swap ${sendAmount.toStringAsFixed(2)} $sendAsset',
      description: 'For ~${receiveAmount.toStringAsFixed(2)} $receiveAsset',
      amount: sendAmount,
      asset: sendAsset,
      txHash: txHash,
      errorMessage: errorMessage,
      errorAdvice: errorAdvice,
      metadata: {
        'sendAmount': sendAmount,
        'sendAsset': sendAsset,
        'receiveAmount': receiveAmount,
        'receiveAsset': receiveAsset,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Create a claimable balance activity log
  factory ActivityLog.claimable({
    required String id,
    required bool isCreating,
    required double amount,
    required String asset,
    String? recipientAddress,
    String? balanceId,
    ActivityStatus status = ActivityStatus.pending,
    String? txHash,
    String? errorMessage,
    String? errorAdvice,
  }) {
    final type = isCreating ? ActivityType.createClaimable : ActivityType.claimBalance;
    final verb = isCreating ? 'Creating' : 'Claiming';

    String? description;
    if (isCreating && recipientAddress != null) {
      final shortAddress = '${recipientAddress.substring(0, 4)}...${recipientAddress.substring(recipientAddress.length - 4)}';
      description = 'For $shortAddress';
    } else if (!isCreating) {
      description = 'From claimable balance';
    }

    return ActivityLog(
      id: id,
      type: type,
      status: status,
      timestamp: DateTime.now(),
      title: '$verb ${amount.toStringAsFixed(2)} $asset',
      description: description,
      amount: amount,
      asset: asset,
      toAddress: recipientAddress,
      txHash: txHash,
      errorMessage: errorMessage,
      errorAdvice: errorAdvice,
      metadata: {
        'balanceId': balanceId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Create a trustline activity log
  factory ActivityLog.trustline({
    required String id,
    required bool isAdding,
    required String assetCode,
    required String issuer,
    ActivityStatus status = ActivityStatus.pending,
    String? txHash,
    String? errorMessage,
    String? errorAdvice,
  }) {
    final type = isAdding ? ActivityType.createTrustline : ActivityType.removeTrustline;
    final verb = isAdding ? 'Adding' : 'Removing';

    return ActivityLog(
      id: id,
      type: type,
      status: status,
      timestamp: DateTime.now(),
      title: '$verb $assetCode',
      description: isAdding ? 'Asset enabled' : 'Asset removed',
      asset: assetCode,
      txHash: txHash,
      errorMessage: errorMessage,
      errorAdvice: errorAdvice,
      metadata: {
        'assetCode': assetCode,
        'issuer': issuer,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Create an error activity log
  factory ActivityLog.error({
    required String id,
    required String title,
    required String errorMessage,
    String? errorAdvice,
    ActivityType? type,
  }) {
    return ActivityLog(
      id: id,
      type: type ?? ActivityType.error,
      status: ActivityStatus.failed,
      timestamp: DateTime.now(),
      title: title,
      description: errorMessage,
      errorMessage: errorMessage,
      errorAdvice: errorAdvice,
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Create a success activity log
  factory ActivityLog.success({
    required String id,
    required String title,
    String? description,
    String? txHash,
  }) {
    return ActivityLog(
      id: id,
      type: ActivityType.success,
      status: ActivityStatus.completed,
      timestamp: DateTime.now(),
      title: title,
      description: description,
      txHash: txHash,
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get display icon based on type and status
  String get displayIcon {
    if (status == ActivityStatus.failed) return ActivityStatus.failed.emoji;
    if (status == ActivityStatus.completed) return ActivityStatus.completed.emoji;
    if (status == ActivityStatus.processing) return ActivityStatus.processing.emoji;
    return type.emoji;
  }

  /// Get display color based on status
  String get displayColor {
    switch (status) {
      case ActivityStatus.completed:
        return 'success';
      case ActivityStatus.failed:
        return 'error';
      case ActivityStatus.processing:
        return 'info';
      case ActivityStatus.pending:
        return 'warning';
      case ActivityStatus.cancelled:
        return 'secondary';
    }
  }

  /// Check if activity is actionable (user can view tx)
  bool get isActionable => txHash != null && txHash!.isNotEmpty;

  /// Check if activity has error
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  /// Get Stellar expert URL for transaction
  String? get stellarExpertUrl {
    if (txHash == null || txHash!.isEmpty) return null;
    final network = 'public'; // TODO: Get from network config
    return 'https://stellar.expert/explorer/$network/tx/$txHash';
  }

  /// Get short transaction hash for display
  String? get shortTxHash {
    if (txHash == null || txHash!.length < 12) return txHash;
    return '${txHash!.substring(0, 6)}...${txHash!.substring(txHash!.length - 6)}';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'description': description,
      'metadata': metadata,
      'txHash': txHash,
      'errorMessage': errorMessage,
      'errorAdvice': errorAdvice,
      'amount': amount,
      'asset': asset,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
    };
  }

  /// Create from JSON
  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      type: ActivityType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => ActivityType.info,
      ),
      status: ActivityStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => ActivityStatus.pending,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      txHash: json['txHash'] as String?,
      errorMessage: json['errorMessage'] as String?,
      errorAdvice: json['errorAdvice'] as String?,
      amount: json['amount'] as double?,
      asset: json['asset'] as String?,
      fromAddress: json['fromAddress'] as String?,
      toAddress: json['toAddress'] as String?,
    );
  }

  /// Create a copy with updated fields
  ActivityLog copyWith({
    ActivityStatus? status,
    String? txHash,
    String? errorMessage,
    String? errorAdvice,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return ActivityLog(
      id: id,
      type: type,
      status: status ?? this.status,
      timestamp: timestamp,
      title: title,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      txHash: txHash ?? this.txHash,
      errorMessage: errorMessage ?? this.errorMessage,
      errorAdvice: errorAdvice ?? this.errorAdvice,
      amount: amount,
      asset: asset,
      fromAddress: fromAddress,
      toAddress: toAddress,
    );
  }
}