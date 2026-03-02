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
    if (_lastCheckAt != null && now.difference(_lastCheckAt!) < const Duration(minutes: 3)) {
      return;
    }

    _running = true;
    _lastCheckAt = now;

    try {
      final appVersion = (await PackageInfo.fromPlatform()).version;

      VersionCheckResult? version;
      try {
        version = await _service.versionCheck(appVersion: appVersion);
      } catch (_) {
        version = null;
      }

      List<AnnouncementItem> active = const [];
      try {
        active = await _service.getActiveForCurrentUser(appVersion: appVersion);
      } catch (_) {
        active = const [];
      }

      if (!mounted) return;

      final queue = <AnnouncementItem>[];
      if (version != null && version.updates.isNotEmpty) {
        queue.addAll(version.updates);
      }
      queue.addAll(active);

      queue.sort((a, b) {
        final aScore = (a.isForceUpdate || a.isCompulsory) ? 1 : 0;
        final bScore = (b.isForceUpdate || b.isCompulsory) ? 1 : 0;
        return bScore.compareTo(aScore);
      });

      for (final item in queue) {
        if (!mounted) return;
        if (item.id.isEmpty) continue;
        if (_shownIds.contains(item.id)) continue;
        if (item.acknowledged) continue;

        _shownIds.add(item.id);

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
        if (hasToken) {
          try {
            await _service.acknowledge(item.id);
          } catch (_) {
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
