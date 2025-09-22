import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';

class ScheduleWindowField extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTimeRange?> onChanged; // null = cleared
  final double radius;
  final EdgeInsetsGeometry padding;
  final String label;
  final bool dense;

  const ScheduleWindowField({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.label = 'Execute window',
    this.dense = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final hasRange = start != null || end != null;

    String niceDate(DateTime v) => DateFormat('EEE, MMM d').format(v.toLocal());
    String niceTime(DateTime v) => DateFormat('h:mm a').format(v.toLocal());
    String nice(DateTime v) => '${niceDate(v)} • ${niceTime(v)}';

    final summary = (start == null && end == null)
        ? 'Not set'
        : '${start != null ? nice(start!) : '—'}  →  ${end != null ? nice(end!) : '—'}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: () async {
          final picked = await _openEditor(context, start: start, end: end, radius: radius);
          if (picked == _EditorResult.cleared) {
            onChanged(null);
          } else if (picked is DateTimeRange) {
            onChanged(picked);
          }
        },
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: c.border.withOpacity(.6), width: 1),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.calendarClock, size: 18, color: c.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: dense ? 12 : 13, color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: dense ? 13 : 14, color: hasRange ? c.textPrimary : c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (hasRange) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: CustomButton(
                    text: '',
                    icon: LucideIcons.xCircle,
                    type: ButtonType.outlined,
                    fullWidth: true,
                    onPressed: () => onChanged(null),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronDown, size: 18, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Future<Object?> _openEditor(
      BuildContext context, {
        required DateTime? start,
        required DateTime? end,
        required double radius,
      }) async {
    final c = AppColor.of(context);
    final now = DateTime.now();

    DateTime? workStart = start ?? now.add(const Duration(minutes: 10));
    DateTime? workEnd   = end   ?? (workStart?.add(const Duration(minutes: 30)));

    String dLong(DateTime v) => DateFormat('EEE, MMM d, y').format(v.toLocal());
    String t12(DateTime v) => DateFormat('h:mm a').format(v.toLocal());

    Future<void> pickDate({required bool forStart}) async {
      final base = forStart ? (workStart ?? now) : (workEnd ?? (workStart ?? now));
      final picked = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        initialDate: base,
      );
      if (picked == null) return;
      final ref = forStart ? (workStart ?? now) : (workEnd ?? (workStart ?? now));
      final newDt = DateTime(picked.year, picked.month, picked.day, ref.hour, ref.minute);
      if (forStart) {
        workStart = newDt;
        if (workEnd != null && workEnd!.isBefore(newDt)) workEnd = newDt.add(const Duration(minutes: 5));
      } else {
        workEnd = newDt;
        if (workStart != null && newDt.isBefore(workStart!)) workStart = newDt.subtract(const Duration(minutes: 5));
      }
    }

    Future<void> pickTime({required bool forStart}) async {
      final base = forStart ? (workStart ?? now) : (workEnd ?? (workStart ?? now));
      final tPicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(base),
        builder: (ctx, child) {
          final mq = MediaQuery.of(ctx);
          return MediaQuery(data: mq.copyWith(alwaysUse24HourFormat: false), child: child ?? const SizedBox.shrink());
        },
      );
      if (tPicked == null) return;
      final ref = forStart ? (workStart ?? now) : (workEnd ?? (workStart ?? now));
      final newDt = DateTime(ref.year, ref.month, ref.day, tPicked.hour, tPicked.minute);
      if (forStart) {
        workStart = newDt;
        if (workEnd != null && workEnd!.isBefore(newDt)) workEnd = newDt.add(const Duration(minutes: 5));
      } else {
        workEnd = newDt;
        if (workStart != null && newDt.isBefore(workStart!)) workStart = newDt.subtract(const Duration(minutes: 5));
      }
    }

    return showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radius + 6))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Widget valueLine({required String title, required DateTime? v}) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(v == null ? '—' : '${dLong(v)}  •  ${t12(v)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: c.border.withOpacity(.7), borderRadius: BorderRadius.circular(99)),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Text('Execute window', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        SizedBox(
                          width: 92,
                          child: CustomButton(
                            text: 'Reset',
                            icon: LucideIcons.x,
                            type: ButtonType.outlined,
                            onPressed: () => Navigator.of(ctx).pop(_EditorResult.cleared),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Align(alignment: Alignment.centerLeft, child: valueLine(title: 'Start', v: workStart)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Pick date',
                            icon: LucideIcons.calendar,
                            type: ButtonType.outlined,
                            onPressed: () async { await pickDate(forStart: true); setSheetState(() {}); },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomButton(
                            text: 'Pick time',
                            icon: LucideIcons.clock3,
                            type: ButtonType.outlined,
                            onPressed: () async { await pickTime(forStart: true); setSheetState(() {}); },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Align(alignment: Alignment.centerLeft, child: valueLine(title: 'End', v: workEnd)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Pick date',
                            icon: LucideIcons.calendarDays,
                            type: ButtonType.outlined,
                            onPressed: () async { await pickDate(forStart: false); setSheetState(() {}); },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomButton(
                            text: 'Pick time',
                            icon: LucideIcons.alarmClock,
                            type: ButtonType.outlined,
                            onPressed: () async { await pickTime(forStart: false); setSheetState(() {}); },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Cancel',
                            icon: LucideIcons.x,
                            type: ButtonType.outlined,
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomButton(
                            text: 'Apply',
                            icon: LucideIcons.check,
                            type: ButtonType.filled,
                            onPressed: () {
                              if (workStart == null || workEnd == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: const Text('Please set both Start and End'), backgroundColor: c.primary),
                                );
                                return;
                              }
                              Navigator.of(ctx).pop(DateTimeRange(start: workStart!, end: workEnd!));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

enum _EditorResult { cleared }
