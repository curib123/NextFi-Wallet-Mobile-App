// lib/features/wallet_settings/view/widgets/header_card.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class HeaderCard extends StatelessWidget {
  const HeaderCard({
    super.key,
    required this.walletName,
    required this.obscured,
    required this.onImport,
    required this.onSwitch,
    required this.onRename,
  });

  final String walletName;
  final bool obscured;
  final VoidCallback onImport;
  final VoidCallback onSwitch;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withOpacity(0.22)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border.withOpacity(.25)),
                ),
                child: Icon(LucideIcons.wallet, color: colors.textPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(walletName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: .2),
                ),
              ),
              const SizedBox(width: 6),
              _StatusPill(
                icon: obscured ? LucideIcons.lock : LucideIcons.unlock,
                label: obscured ? 'Hidden' : 'Visible',
                color: obscured ? colors.warning : colors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _QuickAction(icon: LucideIcons.download, label: 'Import', onTap: onImport)),
              const SizedBox(width: 8),
              Expanded(child: _QuickAction(icon: LucideIcons.shuffle, label: 'Switch', onTap: onSwitch)),
              const SizedBox(width: 8),
              Expanded(child: _QuickAction(icon: LucideIcons.pencil, label: 'Rename', onTap: onRename)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colors.border.withOpacity(.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: colors.textPrimary),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary, fontSize: 12)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label, required this.color});
  final IconData icon; final String label; final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, letterSpacing: .2, fontSize: 12)),
        ],
      ),
    );
  }
}
