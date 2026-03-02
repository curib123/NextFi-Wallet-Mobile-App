import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/helper/link_opener/link_opener.dart';
import 'package:next_fi/services/announcements/announcements_service.dart';

class AnnouncementModalResult {
  const AnnouncementModalResult({required this.dismissed});
  final bool dismissed;
}

Future<AnnouncementModalResult?> showAnnouncementModal(
  BuildContext context, {
  required AnnouncementItem item,
  bool forceBlocking = false,
}) {
  final blocking = forceBlocking || item.isCompulsory || item.isForceUpdate;
  return showGeneralDialog<AnnouncementModalResult>(
    context: context,
    barrierDismissible: !blocking,
    barrierLabel: 'Announcement',
    barrierColor: AppColor.of(context).textPrimary.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => _AnnouncementModal(
      item: item,
      blocking: blocking,
    ),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AnnouncementModal extends StatelessWidget {
  const _AnnouncementModal({required this.item, required this.blocking});

  final AnnouncementItem item;
  final bool blocking;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final accent = switch (item.type) {
      AnnouncementType.update => c.primary,
      AnnouncementType.maintenance => c.warning,
      AnnouncementType.announcement => c.success,
    };

    final icon = switch (item.type) {
      AnnouncementType.update => LucideIcons.rocket,
      AnnouncementType.maintenance => LucideIcons.wrench,
      AnnouncementType.announcement => LucideIcons.megaphone,
    };

    final primaryText = (item.actionLabel ?? '').trim().isNotEmpty
        ? item.actionLabel!.trim()
        : (item.type == AnnouncementType.update ? 'Update now' : 'Got it');

    return PopScope(
      canPop: !blocking,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: c.border.withValues(alpha: 0.28)),
                boxShadow: [
                  BoxShadow(
                    color: c.textPrimary.withValues(alpha: 0.18),
                    blurRadius: 40,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: .0),
                          accent,
                          accent.withValues(alpha: .0),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: accent.withValues(alpha: .28),
                                ),
                              ),
                              child: Icon(icon, color: accent, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!blocking)
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: c.textSecondary,
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).pop(
                                    const AnnouncementModalResult(dismissed: true),
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: SingleChildScrollView(
                            child: Text(
                              item.message,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 14.5,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            if (!blocking) ...[
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: AppOutlinedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(
                                        const AnnouncementModalResult(
                                          dismissed: true,
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: c.textPrimary,
                                      side: BorderSide(
                                        color: c.border.withValues(alpha: .4),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                    child: const Text(
                                      'Later',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: AppElevatedButton(
                                  onPressed: () async {
                                    final url = item.actionUrl?.trim() ?? '';
                                    if (url.isNotEmpty) {
                                      await LinkOpener.open(
                                        context,
                                        url,
                                        fallbackLabel: primaryText,
                                      );
                                    }
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop(
                                      const AnnouncementModalResult(
                                        dismissed: true,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: c.onPrimary,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                  child: Text(
                                    primaryText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
