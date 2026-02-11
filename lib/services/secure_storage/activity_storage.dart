// lib/services/storage/activity_storage.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:next_fi/features/activity/model/activity_log.dart';

/// Secure storage service for activity logs
class ActivityStorage {
  final FlutterSecureStorage _storage;

  static const String _activityLogsKey = 'activity_logs';
  static const String _activitySettingsKey = 'activity_settings';
  static const int _maxLogs = 100;

  ActivityStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // ──────────────────────────────────────────────────────────────────────────
  // Activity Logs CRUD
  // ──────────────────────────────────────────────────────────────────────────

  /// Save activity logs to secure storage
  Future<void> saveLogs(List<ActivityLog> logs) async {
    try {
      // Trim to max logs before saving
      final logsToSave = logs.length > _maxLogs
          ? logs.sublist(0, _maxLogs)
          : logs;

      final jsonList = logsToSave.map((log) => log.toJson()).toList();
      final jsonString = json.encode(jsonList);

      await _storage.write(
        key: _activityLogsKey,
        value: jsonString,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error saving logs: $e');
      }
      rethrow;
    }
  }

  /// Load activity logs from secure storage
  Future<List<ActivityLog>> loadLogs() async {
    try {
      final jsonString = await _storage.read(key: _activityLogsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = json.decode(jsonString) as List;

      return jsonList
          .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error loading logs: $e');
      }
      // Return empty list on error to prevent app crashes
      return [];
    }
  }

  /// Add a single log (loads, updates, saves)
  Future<void> addLog(ActivityLog log) async {
    try {
      final logs = await loadLogs();
      logs.insert(0, log);
      await saveLogs(logs);
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error adding log: $e');
      }
      rethrow;
    }
  }

  /// Update a single log
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
      final logs = await loadLogs();
      final index = logs.indexWhere((log) => log.id == id);

      if (index == -1) {
        if (kDebugMode) {
          print('[ActivityStorage] Log not found: $id');
        }
        return;
      }

      final updatedLog = logs[index].copyWith(
        status: status,
        txHash: txHash,
        errorMessage: errorMessage,
        errorAdvice: errorAdvice,
        description: description,
        metadata: metadata,
      );

      logs[index] = updatedLog;
      await saveLogs(logs);
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error updating log: $e');
      }
      rethrow;
    }
  }

  /// Remove a single log
  Future<void> removeLog(String id) async {
    try {
      final logs = await loadLogs();
      logs.removeWhere((log) => log.id == id);
      await saveLogs(logs);
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error removing log: $e');
      }
      rethrow;
    }
  }

  /// Clear all logs
  Future<void> clearAllLogs() async {
    try {
      await _storage.delete(key: _activityLogsKey);
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error clearing logs: $e');
      }
      rethrow;
    }
  }

  /// Clear logs by criteria
  Future<void> clearLogsByCriteria({
    ActivityStatus? status,
    DateTime? olderThan,
  }) async {
    try {
      final logs = await loadLogs();

      logs.removeWhere((log) {
        if (status != null && log.status != status) return false;
        if (olderThan != null && !log.timestamp.isBefore(olderThan)) return false;
        return true;
      });

      await saveLogs(logs);
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error clearing logs by criteria: $e');
      }
      rethrow;
    }
  }

  /// Clear failed activities
  Future<void> clearFailedLogs() async {
    await clearLogsByCriteria(status: ActivityStatus.failed);
  }

  /// Clear completed activities older than N days
  Future<void> clearOldCompletedLogs(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));

    try {
      final logs = await loadLogs();

      logs.removeWhere((log) =>
      log.status == ActivityStatus.completed &&
          log.timestamp.isBefore(cutoff));

      await saveLogs(logs);
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error clearing old logs: $e');
      }
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Settings
  // ──────────────────────────────────────────────────────────────────────────

  /// Save activity settings
  Future<void> saveSettings(ActivitySettings settings) async {
    try {
      final jsonString = json.encode(settings.toJson());
      await _storage.write(
        key: _activitySettingsKey,
        value: jsonString,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error saving settings: $e');
      }
      rethrow;
    }
  }

  /// Load activity settings
  Future<ActivitySettings> loadSettings() async {
    try {
      final jsonString = await _storage.read(key: _activitySettingsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return ActivitySettings.defaults();
      }

      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return ActivitySettings.fromJson(jsonData);
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error loading settings: $e');
      }
      return ActivitySettings.defaults();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Statistics
  // ──────────────────────────────────────────────────────────────────────────

  /// Get activity statistics
  Future<ActivityStats> getStats() async {
    try {
      final logs = await loadLogs();

      final total = logs.length;
      final pending = logs.where((l) =>
      l.status == ActivityStatus.pending ||
          l.status == ActivityStatus.processing).length;
      final completed = logs.where((l) =>
      l.status == ActivityStatus.completed).length;
      final failed = logs.where((l) =>
      l.status == ActivityStatus.failed).length;

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayCount = logs.where((l) =>
          l.timestamp.isAfter(todayStart)).length;

      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final weekStartDay = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final weekCount = logs.where((l) =>
          l.timestamp.isAfter(weekStartDay)).length;

      return ActivityStats(
        total: total,
        pending: pending,
        completed: completed,
        failed: failed,
        todayCount: todayCount,
        weekCount: weekCount,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error getting stats: $e');
      }
      return ActivityStats.empty();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Backup & Export
  // ──────────────────────────────────────────────────────────────────────────

  /// Export logs as JSON string
  Future<String> exportLogsAsJson() async {
    try {
      final logs = await loadLogs();
      final jsonList = logs.map((log) => log.toJson()).toList();
      return json.encode(jsonList);
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error exporting logs: $e');
      }
      rethrow;
    }
  }

  /// Import logs from JSON string
  Future<void> importLogsFromJson(String jsonString) async {
    try {
      final jsonList = json.decode(jsonString) as List;
      final logs = jsonList
          .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
          .toList();

      await saveLogs(logs);
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error importing logs: $e');
      }
      rethrow;
    }
  }

  /// Export logs as CSV
  Future<String> exportLogsAsCsv() async {
    try {
      final logs = await loadLogs();

      final buffer = StringBuffer();

      // Header
      buffer.writeln('Timestamp,Type,Status,Amount,Asset,From,To,TxHash,Error');

      // Rows
      for (final log in logs) {
        buffer.writeln([
          log.timestamp.toIso8601String(),
          log.type.label,
          log.status.label,
          log.amount?.toString() ?? '',
          log.asset ?? '',
          log.fromAddress ?? '',
          log.toAddress ?? '',
          log.txHash ?? '',
          log.errorMessage ?? '',
        ].map((e) => '"${e.replaceAll('"', '""')}"').join(','));
      }

      return buffer.toString();
    } catch (e) {
      if (kDebugMode) {
        print('[ActivityStorage] Error exporting CSV: $e');
      }
      rethrow;
    }
  }
}

/// Activity settings model
class ActivitySettings {
  final bool showNotifications;
  final bool autoCleanup;
  final int cleanupDays;
  final bool exportEnabled;

  const ActivitySettings({
    required this.showNotifications,
    required this.autoCleanup,
    required this.cleanupDays,
    required this.exportEnabled,
  });

  factory ActivitySettings.defaults() {
    return const ActivitySettings(
      showNotifications: true,
      autoCleanup: true,
      cleanupDays: 30,
      exportEnabled: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showNotifications': showNotifications,
      'autoCleanup': autoCleanup,
      'cleanupDays': cleanupDays,
      'exportEnabled': exportEnabled,
    };
  }

  factory ActivitySettings.fromJson(Map<String, dynamic> json) {
    return ActivitySettings(
      showNotifications: json['showNotifications'] as bool? ?? true,
      autoCleanup: json['autoCleanup'] as bool? ?? true,
      cleanupDays: json['cleanupDays'] as int? ?? 30,
      exportEnabled: json['exportEnabled'] as bool? ?? true,
    );
  }

  ActivitySettings copyWith({
    bool? showNotifications,
    bool? autoCleanup,
    int? cleanupDays,
    bool? exportEnabled,
  }) {
    return ActivitySettings(
      showNotifications: showNotifications ?? this.showNotifications,
      autoCleanup: autoCleanup ?? this.autoCleanup,
      cleanupDays: cleanupDays ?? this.cleanupDays,
      exportEnabled: exportEnabled ?? this.exportEnabled,
    );
  }
}

/// Activity statistics model
class ActivityStats {
  final int total;
  final int pending;
  final int completed;
  final int failed;
  final int todayCount;
  final int weekCount;

  const ActivityStats({
    required this.total,
    required this.pending,
    required this.completed,
    required this.failed,
    required this.todayCount,
    required this.weekCount,
  });

  factory ActivityStats.empty() {
    return const ActivityStats(
      total: 0,
      pending: 0,
      completed: 0,
      failed: 0,
      todayCount: 0,
      weekCount: 0,
    );
  }

  double get successRate {
    if (total == 0) return 0.0;
    return (completed / total) * 100;
  }

  double get failureRate {
    if (total == 0) return 0.0;
    return (failed / total) * 100;
  }
}