// lib/features/activity/view_model/activity_log_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:next_fi/services/secure_storage/activity_storage.dart';

import '../model/activity_log.dart';

/// View model for managing activity logs and notifications
class ActivityLogVM extends ChangeNotifier {
  ActivityLogVM({
    ActivityStorage? storage,
  }) : _storage = storage ?? ActivityStorage();

  final ActivityStorage _storage;

  // ──────────────────────────────────────────────────────────────────────────
  // State
  // ──────────────────────────────────────────────────────────────────────────

  final List<ActivityLog> _logs = [];
  List<ActivityLog> get logs => List.unmodifiable(_logs);

  /// Stream controller for real-time activity updates
  final StreamController<ActivityLog> _activityStream =
  StreamController<ActivityLog>.broadcast();
  Stream<ActivityLog> get activityStream => _activityStream.stream;

  bool _disposed = false;
  bool _initialized = false;
  bool _loading = false;
  bool get loading => _loading;

  ActivitySettings _settings = ActivitySettings.defaults();
  ActivitySettings get settings => _settings;

  ActivityStats _stats = ActivityStats.empty();
  ActivityStats get stats => _stats;

  // ──────────────────────────────────────────────────────────────────────────
  // Computed Properties
  // ──────────────────────────────────────────────────────────────────────────

  /// Get recent activities (last N)
  List<ActivityLog> getRecent([int count = 10]) {
    return _logs.take(count).toList();
  }

  /// Get activities by type
  List<ActivityLog> getByType(ActivityType type) {
    return _logs.where((log) => log.type == type).toList();
  }

  /// Get activities by status
  List<ActivityLog> getByStatus(ActivityStatus status) {
    return _logs.where((log) => log.status == status).toList();
  }

  /// Get pending activities
  List<ActivityLog> get pendingActivities {
    return _logs
        .where((log) =>
    log.status == ActivityStatus.pending ||
        log.status == ActivityStatus.processing)
        .toList();
  }

  /// Get failed activities
  List<ActivityLog> get failedActivities {
    return _logs.where((log) => log.status == ActivityStatus.failed).toList();
  }

  /// Get completed activities
  List<ActivityLog> get completedActivities {
    return _logs.where((log) => log.status == ActivityStatus.completed).toList();
  }

  /// Get activities from today
  List<ActivityLog> get todayActivities {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _logs.where((log) => log.timestamp.isAfter(todayStart)).toList();
  }

  /// Get activities from this week
  List<ActivityLog> get weekActivities {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _logs.where((log) => log.timestamp.isAfter(weekStartDay)).toList();
  }

  /// Get activities grouped by date
  Map<String, List<ActivityLog>> get groupedByDate {
    final grouped = <String, List<ActivityLog>>{};
    for (final log in _logs) {
      final dateKey = _formatDateKey(log.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(log);
    }
    return grouped;
  }

  /// Count of unread notifications (failed activities)
  int get unreadCount => failedActivities.length;

  /// Whether there are any pending activities
  bool get hasPendingActivities => pendingActivities.isNotEmpty;

  /// Whether there are any failed activities
  bool get hasFailedActivities => failedActivities.isNotEmpty;

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  /// Initialize the view model
  Future<void> init() async {
    if (_initialized) return;

    _loading = true;
    _safeNotify();

    try {
      // Load logs from secure storage
      await _loadFromStorage();

      // Load settings
      await _loadSettings();

      // Calculate stats
      await _updateStats();

      // Auto-cleanup if enabled
      if (_settings.autoCleanup) {
        await _autoCleanup();
      }

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Init error: $e');
      }
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _activityStream.close();
    super.dispose();
  }

  void _safeNotify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CRUD Operations
  // ──────────────────────────────────────────────────────────────────────────

  /// Add a new activity log
  Future<void> addLog(ActivityLog log) async {
    try {
      // Add to local list
      _logs.insert(0, log);

      // Emit to stream
      _activityStream.add(log);

      // Save to storage
      await _storage.saveLogs(_logs);

      // Update stats
      await _updateStats();

      _safeNotify();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error adding log: $e');
      }
      rethrow;
    }
  }

  /// Update an existing activity log
  Future<void> updateLog(
      String id, {
        ActivityStatus? status,
        String? txHash,
        String? errorMessage,
        String? errorAdvice,
        String? description,
        Map<String, dynamic>? metadata,
      }) async {
    try {
      final index = _logs.indexWhere((log) => log.id == id);
      if (index == -1) return;

      final oldLog = _logs[index];
      final updatedLog = oldLog.copyWith(
        status: status,
        txHash: txHash,
        errorMessage: errorMessage,
        errorAdvice: errorAdvice,
        description: description,
        metadata: metadata,
      );

      // Update local list
      _logs[index] = updatedLog;

      // Emit to stream if status changed
      if (status != null && status != oldLog.status) {
        _activityStream.add(updatedLog);
      }

      // Save to storage
      await _storage.saveLogs(_logs);

      // Update stats
      await _updateStats();

      _safeNotify();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error updating log: $e');
      }
      rethrow;
    }
  }

  /// Remove an activity log
  Future<void> removeLog(String id) async {
    try {
      _logs.removeWhere((log) => log.id == id);
      await _storage.saveLogs(_logs);
      await _updateStats();
      _safeNotify();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error removing log: $e');
      }
      rethrow;
    }
  }

  /// Clear all activity logs
  Future<void> clearAll() async {
    try {
      _logs.clear();
      await _storage.clearAllLogs();
      await _updateStats();
      _safeNotify();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error clearing all logs: $e');
      }
      rethrow;
    }
  }

  /// Clear failed activities
  Future<void> clearFailed() async {
    try {
      _logs.removeWhere((log) => log.status == ActivityStatus.failed);
      await _storage.saveLogs(_logs);
      await _updateStats();
      _safeNotify();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error clearing failed logs: $e');
      }
      rethrow;
    }
  }

  /// Clear completed activities older than N days
  Future<void> clearOldCompleted([int days = 7]) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      _logs.removeWhere((log) =>
      log.status == ActivityStatus.completed &&
          log.timestamp.isBefore(cutoff));
      await _storage.saveLogs(_logs);
      await _updateStats();
      _safeNotify();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error clearing old logs: $e');
      }
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Settings Management
  // ──────────────────────────────────────────────────────────────────────────

  /// Update settings
  Future<void> updateSettings(ActivitySettings newSettings) async {
    try {
      _settings = newSettings;
      await _storage.saveSettings(newSettings);
      _safeNotify();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error updating settings: $e');
      }
      rethrow;
    }
  }

  /// Toggle notifications
  Future<void> toggleNotifications(bool enabled) async {
    await updateSettings(_settings.copyWith(showNotifications: enabled));
  }

  /// Toggle auto cleanup
  Future<void> toggleAutoCleanup(bool enabled) async {
    await updateSettings(_settings.copyWith(autoCleanup: enabled));
  }

  /// Update cleanup days
  Future<void> updateCleanupDays(int days) async {
    await updateSettings(_settings.copyWith(cleanupDays: days));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Export & Import
  // ──────────────────────────────────────────────────────────────────────────

  /// Export logs as JSON
  Future<String> exportAsJson() async {
    try {
      return await _storage.exportLogsAsJson();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error exporting JSON: $e');
      }
      rethrow;
    }
  }

  /// Export logs as CSV
  Future<String> exportAsCsv() async {
    try {
      return await _storage.exportLogsAsCsv();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error exporting CSV: $e');
      }
      rethrow;
    }
  }

  /// Import logs from JSON
  Future<void> importFromJson(String jsonString) async {
    try {
      await _storage.importLogsFromJson(jsonString);
      await _loadFromStorage();
      await _updateStats();
      _safeNotify();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error importing JSON: $e');
      }
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helper Methods
  // ──────────────────────────────────────────────────────────────────────────

  /// Generate unique ID for activity
  String generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_logs.length}';
  }

  /// Format date key for grouping
  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == yesterday) return 'Yesterday';

    final diff = today.difference(dateOnly).inDays;
    if (diff < 7) return '${diff} days ago';

    return '${date.month}/${date.day}/${date.year}';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Storage Operations
  // ──────────────────────────────────────────────────────────────────────────

  /// Load logs from storage
  Future<void> _loadFromStorage() async {
    try {
      final loadedLogs = await _storage.loadLogs();
      _logs.clear();
      _logs.addAll(loadedLogs);
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error loading logs: $e');
      }
    }
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      _settings = await _storage.loadSettings();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error loading settings: $e');
      }
    }
  }

  /// Update statistics
  Future<void> _updateStats() async {
    try {
      _stats = await _storage.getStats();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error updating stats: $e');
      }
    }
  }

  /// Auto cleanup old logs based on settings
  Future<void> _autoCleanup() async {
    try {
      if (_settings.autoCleanup) {
        await clearOldCompleted(_settings.cleanupDays);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityLogVM] Error in auto cleanup: $e');
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Convenience Methods for Common Activities
  // ──────────────────────────────────────────────────────────────────────────

  /// Log a payment activity
  Future<String> logPayment({
    required bool isSending,
    required double amount,
    required String asset,
    required String fromAddress,
    required String toAddress,
    ActivityStatus status = ActivityStatus.processing,
  }) async {
    final id = generateId();
    final log = ActivityLog.payment(
      id: id,
      isSending: isSending,
      amount: amount,
      asset: asset,
      fromAddress: fromAddress,
      toAddress: toAddress,
      status: status,
    );
    await addLog(log);
    return id;
  }

  /// Log a swap activity
  Future<String> logSwap({
    required double sendAmount,
    required String sendAsset,
    required double receiveAmount,
    required String receiveAsset,
    ActivityStatus status = ActivityStatus.processing,
  }) async {
    final id = generateId();
    final log = ActivityLog.swap(
      id: id,
      sendAmount: sendAmount,
      sendAsset: sendAsset,
      receiveAmount: receiveAmount,
      receiveAsset: receiveAsset,
      status: status,
    );
    await addLog(log);
    return id;
  }

  /// Log a claimable balance activity
  Future<String> logClaimable({
    required bool isCreating,
    required double amount,
    required String asset,
    String? recipientAddress,
    String? balanceId,
    ActivityStatus status = ActivityStatus.processing,
  }) async {
    final id = generateId();
    final log = ActivityLog.claimable(
      id: id,
      isCreating: isCreating,
      amount: amount,
      asset: asset,
      recipientAddress: recipientAddress,
      balanceId: balanceId,
      status: status,
    );
    await addLog(log);
    return id;
  }

  /// Log a success
  Future<void> logSuccess({
    required String title,
    String? description,
    String? txHash,
  }) async {
    final id = generateId();
    final log = ActivityLog.success(
      id: id,
      title: title,
      description: description,
      txHash: txHash,
    );
    await addLog(log);
  }

  /// Log an error
  Future<void> logError({
    required String title,
    required String errorMessage,
    String? errorAdvice,
    ActivityType? type,
  }) async {
    final id = generateId();
    final log = ActivityLog.error(
      id: id,
      title: title,
      errorMessage: errorMessage,
      errorAdvice: errorAdvice,
      type: type,
    );
    await addLog(log);
  }
}