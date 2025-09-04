import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

/// Normalize a resource label coming from various node fields.
/// - 'NET' or values containing 'BANDWIDTH' → 'BANDWIDTH'
/// - values containing 'ENERGY' → 'ENERGY'
/// - hide/empty for anything else (e.g., TRON_POWER)
String normalizeResourceLabel(Map e) {
  final raw = ((e['type'] ?? e['resource'] ?? e['resource_type'])?.toString() ?? '').toUpperCase();
  if (raw == 'NET' || raw.contains('BANDWIDTH')) return 'BANDWIDTH';
  if (raw.contains('ENERGY')) return 'ENERGY';
  return '';
}

/// Simple fintech section card with tidy spacing & hierarchy.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
    this.leadingColor,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 10),
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final IconData? leading;
  final Color? leadingColor;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 0 : 1,
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (leading != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (leadingColor ?? colors.primary).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (leadingColor ?? colors.primary).withOpacity(0.18)),
                  ),
                  child: Icon(leading, size: 18, color: leadingColor ?? colors.primary),
                ),
              if (leading != null) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.5, height: 1.25),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// “Spendable TRX” single stat row used in main header.
class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13.5)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: colors.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

/// Current stakes list (ENERGY/BANDWIDTH aggregated).
class StakedList extends StatelessWidget {
  const StakedList({
    super.key,
    required this.items,
    required this.formatTrx,
  });

  final List<Map<String, dynamic>> items;
  final String Function(int) formatTrx;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SectionCard(
      title: 'Active stakes',
      subtitle: 'Funds currently locked for resources. Unstake to begin the ~14-day unlock.',
      leading: LucideIcons.lock,
      leadingColor: colors.primary,
      children: items.map((e) {
        final amtSun = (e['amount_sun'] as num?)?.toInt() ?? 0;
        final type = normalizeResourceLabel(e);
        final Color barColor = type == 'ENERGY' ? colors.accent : colors.primary;

        return _tile(
          context,
          icon: type == 'ENERGY' ? LucideIcons.zap : LucideIcons.activity,
          title: '${formatTrx(amtSun)} TRX',
          subtitle: type.isEmpty ? null : type, // show ENERGY or BANDWIDTH under amount
          pillText: 'Active',
          pillPrimary: false,
          barColor: barColor,
        );
      }).toList(),
    );
  }

  Widget _tile(
      BuildContext context, {
        required IconData icon,
        required String title,
        String? subtitle,
        String? pillText,
        required bool pillPrimary,
        required Color barColor,
      }) {
    final colors = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: colors.background.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            // subtle resource accent
            Container(
              width: 3.5,
              height: 36,
              decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(999)),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: colors.textPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
              ]),
            ),
            if (pillText != null) _pill(context, pillText, pillPrimary: pillPrimary),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String text, {required bool pillPrimary}) {
    final colors = AppColor.of(context);
    final bg = pillPrimary ? colors.primary.withOpacity(.12) : colors.background;
    final fg = pillPrimary ? colors.primary : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

/// Matured (ready to withdraw) list.
class ReadyList extends StatelessWidget {
  const ReadyList({
    super.key,
    required this.items,
    required this.formatTrx,
    this.onWithdrawAll,
  });

  final List<Map<String, dynamic>> items;
  final String Function(int) formatTrx;
  final VoidCallback? onWithdrawAll;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    if (items.isEmpty) return const SizedBox.shrink();

    final totalSun = items.fold<int>(0, (s, e) => s + ((e['amount_sun'] as num?)?.toInt() ?? 0));
    return SectionCard(
      title: 'Ready to withdraw',
      subtitle: 'These unstakes have matured and can be moved to your balance.',
      leading: LucideIcons.arrowDownToLine,
      leadingColor: colors.success,
      trailing: Text(
        '${formatTrx(totalSun)} TRX',
        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
      ),
      children: [
        ...items.map((e) {
          final amtSun = (e['amount_sun'] as num?)?.toInt() ?? 0;
          final type = normalizeResourceLabel(e);
          return _tile(
            context,
            icon: type == 'ENERGY' ? LucideIcons.zap : LucideIcons.activity,
            title: '${formatTrx(amtSun)} TRX${type.isEmpty ? '' : ' • $type'}',
            pillText: 'Ready',
          );
        }),
        if (onWithdrawAll != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onWithdrawAll,
              icon: const Icon(LucideIcons.arrowDownToLine, size: 18),
              label: const Text('Withdraw all'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, {required IconData icon, required String title, String? pillText}) {
    final colors = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: colors.background.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.textPrimary),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700))),
            if (pillText != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(color: colors.primary.withOpacity(.12), borderRadius: BorderRadius.circular(999)),
                child: Text(pillText, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pending unstakes (not matured yet).
class PendingList extends StatelessWidget {
  const PendingList({
    super.key,
    required this.items,
    required this.formatTrx,
  });

  final List<Map<String, dynamic>> items;
  final String Function(int) formatTrx;

  static String _timeLeft(int ms) {
    if (ms <= 0) return 'Ready';
    final s = (ms / 1000).ceil();
    final d = s ~/ 86400;
    final h = (s % 86400) ~/ 3600;
    return d > 0 ? '${d}d ${h}h' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final now = DateTime.now().millisecondsSinceEpoch;

    final pending = items.where((e) {
      final ms = (e['expire_time_ms'] as num?)?.toInt() ?? 0;
      return ms == 0 || ms > now;
    }).toList();

    if (pending.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: 'Pending unstakes',
      subtitle: 'You can withdraw these once the waiting period ends.',
      leading: LucideIcons.timer,
      leadingColor: colors.warning,
      children: pending.map((e) {
        final amtSun = (e['amount_sun'] as num?)?.toInt() ?? 0;
        final type = normalizeResourceLabel(e);
        final expireMs = (e['expire_time_ms'] as num?)?.toInt() ?? 0;
        final d = expireMs > 0 ? DateTime.fromMillisecondsSinceEpoch(expireMs) : null;
        final left = _timeLeft(expireMs - now);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: colors.background.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(type == 'ENERGY' ? LucideIcons.zap : LucideIcons.activity, size: 18, color: colors.textPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${formatTrx(amtSun)} TRX${type.isEmpty ? '' : ' • $type'}',
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    if (d != null)
                      Text(
                        'Matures: ${DateFormat('y-MM-dd HH:mm').format(d)}',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                      ),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(999)),
                  child: Text(left, style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
