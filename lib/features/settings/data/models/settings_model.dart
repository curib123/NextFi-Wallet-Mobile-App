import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum SettingAction {
  wallet,
  changePin,
  fiatCurrency,
  biometrics,
  themeMode, // <-- NEW: used for the Light/Dark switch
}

@immutable
class SettingItem {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;
  final SettingAction action;
  final bool enabled;

  const SettingItem({
    required this.title,
    required this.action,
    this.subtitle,
    this.icon = LucideIcons.circle,
    this.accentColor,
    this.enabled = true,
  });

  SettingItem copyWith({
    String? title,
    String? subtitle,
    IconData? icon,
    Color? accentColor,
    SettingAction? action,
    bool? enabled,
  }) {
    return SettingItem(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
      accentColor: accentColor ?? this.accentColor,
      action: action ?? this.action,
      enabled: enabled ?? this.enabled,
    );
  }
}

@immutable
class SettingSection {
  final String? header; // null or empty => no header
  final List<SettingItem> items;

  const SettingSection({this.header, required this.items});

  SettingSection copyWith({
    String? header,
    List<SettingItem>? items,
  }) {
    return SettingSection(
      header: header ?? this.header,
      items: items ?? this.items,
    );
  }
}
