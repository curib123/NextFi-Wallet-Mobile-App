import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:next_fi/common/components/modal/announcement_modal.dart';
import 'package:next_fi/services/announcements/announcements_service.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';

class GlobalAnnouncementHost extends StatefulWidget {
  const GlobalAnnouncementHost({super.key, required this.child});
  final Widget child;

  @override
  State<GlobalAnnouncementHost> createState() => _GlobalAnnouncementHostState();
}

class _GlobalAnnouncementHostState extends State<GlobalAnnouncementHost>
    with WidgetsBindingObserver {
  final AnnouncementsService _service = AnnouncementsService();
  final TokenStorage _tokenStorage = TokenStorage();
  final Set<String> _shownIds = <String>{};
  static const Duration _minCheckGap = Duration(seconds: 30);
  bool _running = false;
  DateTime? _lastCheckAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runChecks());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runChecks();
    }
  }

  Future<void> _runChecks() async {
    if (!mounted || _running) return;

    final now = DateTime.now();
    if (_lastCheckAt != null && now.difference(_lastCheckAt!) < _minCheckGap) {
      return;
    }

    _running = true;
    _lastCheckAt = now;

    try {
      final appVersion = (await PackageInfo.fromPlatform()).version;

      VersionCheckResult? version;
      try {
        version = await _service.versionCheck(appVersion: appVersion);
      } catch (e) {
        debugPrint('[announcements] version-check failed: $e');
        version = null;
      }

      List<AnnouncementItem> active = const [];
      try {
        active = await _service.getActiveForCurrentUser(appVersion: appVersion);
      } catch (e) {
        debugPrint('[announcements] active fetch failed: $e');
        active = const [];
      }

      if (!mounted) return;

      final queue = <AnnouncementItem>[];
      if (version != null && version.updates.isNotEmpty) {
        queue.addAll(version.updates);
      }
      queue.addAll(active);
      if (version?.requiresForceUpdate == true) {
        final hasForceUpdateItem = queue.any(
          (e) => e.type == AnnouncementType.update && (e.isForceUpdate || e.isCompulsory),
        );
        if (!hasForceUpdateItem) {
          queue.insert(
            0,
            AnnouncementItem(
              id: '__local_force_update__${version?.requiredMinVersion ?? appVersion}',
              type: AnnouncementType.update,
              title: 'Update Required',
              message:
                  'A newer app version is required to continue. '
                  'Please update the app to at least ${version?.requiredMinVersion ?? appVersion}.',
              isCompulsory: true,
              requiresUpdate: true,
              isForceUpdate: true,
            ),
          );
        }
      }

      queue.sort((a, b) {
        final aScore = (a.isForceUpdate || a.isCompulsory) ? 1 : 0;
        final bScore = (b.isForceUpdate || b.isCompulsory) ? 1 : 0;
        return bScore.compareTo(aScore);
      });

      for (final item in queue) {
        if (!mounted) return;
        if (item.id.isEmpty) continue;
        if (_shownIds.contains(item.displayKey)) continue;
        if (item.acknowledged) continue;

        _shownIds.add(item.displayKey);

        final forceBlocking =
            item.isForceUpdate ||
            (version?.requiresForceUpdate == true &&
                item.type == AnnouncementType.update);

        final result = await showAnnouncementModal(
          context,
          item: item,
          forceBlocking: forceBlocking,
        );

        if (!mounted) return;
        if (result == null || !result.dismissed) continue;

        final hasToken = await _tokenStorage.accessToken != null;
        final isLocalSynthetic = item.id.startsWith('__local_');
        if (hasToken && !isLocalSynthetic) {
          try {
            await _service.acknowledge(item.id);
          } catch (e) {
            debugPrint('[announcements] acknowledge failed for ${item.id}: $e');
            // Best-effort ack to avoid blocking UX on API failure.
          }
        }
      }
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
