// lib/Screen/settings_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/showFiatPickerBottomSheet.dart';
import 'package:next_fi/Components/showPinChangeBottomSheet.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';

/// Alias — same as VoidCallback.
typedef VoiceCallback = VoidCallback;

/// Optional: onPressed that needs BuildContext
typedef VoiceCallbackWithContext = void Function(BuildContext context);

/// A single, dynamic setting row (icon-only leading; exactly one onClick required).
class SettingItem {
  final String title;
  final String? subtitle;

  /// Provide exactly one of these:
  final VoiceCallback? onPressed;
  final VoiceCallbackWithContext? onPressedWithContext;

  /// Optional visuals
  final IconData? icon;         // e.g., LucideIcons.shield
  final Color? accentColor;     // leading bg tint
  final Widget? trailing;       // e.g., a Switch or text value
  final bool enabled;

  const SettingItem({
    required this.title,
    this.subtitle,
    this.onPressed,
    this.onPressedWithContext,
    this.icon,
    this.accentColor,
    this.trailing,
    this.enabled = true,
  }) : assert(
  (onPressed != null) ^ (onPressedWithContext != null),
  'Provide exactly one: onPressed OR onPressedWithContext',
  );

  /// Convenience: simple tap handler.
  factory SettingItem.tap({
    required String title,
    String? subtitle,
    required VoiceCallback onPressed,
    IconData? icon,
    Color? accentColor,
    Widget? trailing,
    bool enabled = true,
  }) =>
      SettingItem(
        title: title,
        subtitle: subtitle,
        onPressed: onPressed,
        icon: icon,
        accentColor: accentColor,
        trailing: trailing,
        enabled: enabled,
      );

  /// Convenience: needs BuildContext (e.g., to open a sheet / navigate).
  factory SettingItem.tapWithContext({
    required String title,
    String? subtitle,
    required VoiceCallbackWithContext onPressedWithContext,
    IconData? icon,
    Color? accentColor,
    Widget? trailing,
    bool enabled = true,
  }) =>
      SettingItem(
        title: title,
        subtitle: subtitle,
        onPressedWithContext: onPressedWithContext,
        icon: icon,
        accentColor: accentColor,
        trailing: trailing,
        enabled: enabled,
      );
}

/// Optional section divider with a label.
class SettingSection {
  final String? header; // null for no header
  final List<SettingItem> items;
  const SettingSection({this.header, required this.items});

  SettingSection copyWith({String? header, List<SettingItem>? items}) =>
      SettingSection(header: header ?? this.header, items: items ?? this.items);
}

class SettingsRegistry {
  SettingsRegistry._();

  static final ValueNotifier<List<SettingSection>> _sections =
  ValueNotifier<List<SettingSection>>(
    [
      SettingSection(
        header: 'Account',
        items: [
          SettingItem.tapWithContext(
            title: 'Security',
            subtitle: 'Biometrics, PIN, and recovery',
            icon: LucideIcons.shield,
            onPressedWithContext: showPinChangeBottomSheet,
          ),
        ],
      ),
      SettingSection(
        header: 'Preferences',
        items: [
          SettingItem.tapWithContext(
            title: 'Fiat Currency',
            subtitle: 'Change display currency (PHP, USD, etc.)',
            icon: LucideIcons.banknote,
            trailing: const _FiatChip(),
            onPressedWithContext: showFiatPickerBottomSheet,
          ),
        ],
      ),
    ],
  );

  static ValueListenable<List<SettingSection>> get listenable => _sections;
  static List<SettingSection> get sections => _sections.value;

  /// Replace all sections (empty ones are dropped).
  static void setSections(List<SettingSection> sections) {
    final cleaned =
    sections.where((s) => s.items.isNotEmpty).toList(growable: false);
    _sections.value = List.unmodifiable(cleaned);
  }

  /// Remove everything.
  static void clear() => _sections.value = const [];

  /// Upsert a section by header (null/empty header treated as same bucket).
  static void upsertSection(SettingSection section) {
    final key = (section.header ?? '').trim().toLowerCase();
    final current = [..._sections.value];
    final idx = current.indexWhere(
          (s) => ((s.header ?? '').trim().toLowerCase()) == key,
    );
    if (idx >= 0) {
      current[idx] = section;
    } else {
      current.add(section);
    }
    setSections(current);
  }
}

/// Drop-in screen with a modern, card-like list.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: c.surface,
        title: Text(
          'Settings',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<SettingSection>>(
          valueListenable: SettingsRegistry.listenable,
          builder: (context, rawSections, _) {
            final sections =
            rawSections.where((s) => s.items.isNotEmpty).toList();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: sections.length,
              itemBuilder: (ctx, i) {
                final section = sections[i];
                final hasHeader = (section.header ?? '').trim().isNotEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                        child: Text(
                          section.header!.toUpperCase(),
                          style: TextStyle(
                            color: c.textSecondary.withOpacity(0.8),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    _SettingsCard(items: section.items),
                    const SizedBox(height: 12),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});
  final List<SettingItem> items;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: c.primary.withOpacity(0.08),
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (ctx, index) => _SettingTile(it: items[index]),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.it});
  final SettingItem it;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    final leadingBg = (it.accentColor ?? c.primary).withOpacity(0.10);
    final leadingBorder = (it.accentColor ?? c.primary).withOpacity(0.25);

    final IconData leadingIcon = it.icon ?? LucideIcons.circle;
    final Widget leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: leadingBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: leadingBorder),
      ),
      alignment: Alignment.center,
      child: Icon(leadingIcon, color: it.accentColor ?? c.primary, size: 18),
    );

    final Widget effectiveTrailing = it.trailing ??
        Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: it.enabled
              ? c.textSecondary.withOpacity(0.9)
              : c.textSecondary.withOpacity(0.4),
        );

    final VoidCallback? tap = it.enabled
        ? () {
      if (it.onPressedWithContext != null) {
        it.onPressedWithContext!(context);
      } else {
        // onPressed guaranteed non-null by assert
        it.onPressed!.call();
      }
    }
        : null;

    final textPrimary =
    it.enabled ? c.textPrimary : c.textSecondary.withOpacity(0.6);

    return MergeSemantics(
      child: Semantics(
        button: it.enabled,
        enabled: it.enabled,
        label: it.title,
        hint: (it.subtitle ?? '').isNotEmpty ? it.subtitle : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: tap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.title,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if ((it.subtitle ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  it.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      effectiveTrailing,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill showing the current fiat (e.g., PHP / USD)
class _FiatChip extends StatelessWidget {
  const _FiatChip();

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final fiat =
    context.select<CurrencyProvider, String>((p) => p.fiat).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (c.primary).withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (c.primary).withOpacity(0.25)),
      ),
      child: Text(
        fiat,
        style: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
