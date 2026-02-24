// lib/common/components/avatar/user_avatar.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

/// Centralized user avatar component
/// Displays user profile image or initial letter
class UserAvatar extends StatelessWidget {
  final User user;
  final double radius;
  final AppColor? colors;
  final Color? backgroundColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 20,
    this.colors,
    this.backgroundColor,
    this.fontSize,
    this.fontWeight,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors ?? AppColor.of(context);
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;
    final bgColor = backgroundColor ?? appColors.primary;

    return Container(
      decoration: showBorder
          ? BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? Colors.white,
          width: borderWidth,
        ),
      )
          : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: hasAvatar ? NetworkImage(user.avatarUrl!) : null,
        onBackgroundImageError: hasAvatar ? (_, __) {} : null,
        child: hasAvatar
            ? null
            : Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: fontWeight ?? FontWeight.bold,
            fontSize: fontSize ?? (radius * 0.7),
          ),
        ),
      ),
    );
  }
}

/// Small avatar variant (for lists, chips, etc.)
class UserAvatarSmall extends StatelessWidget {
  final User user;
  final AppColor? colors;

  const UserAvatarSmall({
    super.key,
    required this.user,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      user: user,
      radius: 16,
      colors: colors,
      fontSize: 12,
    );
  }
}

/// Medium avatar variant (for top bars, navigation)
class UserAvatarMedium extends StatelessWidget {
  final User user;
  final AppColor? colors;
  final bool showBorder;

  const UserAvatarMedium({
    super.key,
    required this.user,
    this.colors,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      user: user,
      radius: 18,
      colors: colors,
      fontSize: 14,
      showBorder: showBorder,
    );
  }
}

/// Large avatar variant (for profile pages, modals)
class UserAvatarLarge extends StatelessWidget {
  final User user;
  final AppColor? colors;
  final bool showBorder;
  final Color? borderColor;

  const UserAvatarLarge({
    super.key,
    required this.user,
    this.colors,
    this.showBorder = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      user: user,
      radius: 40,
      colors: colors,
      fontSize: 28,
      showBorder: showBorder,
      borderColor: borderColor,
      borderWidth: 3,
    );
  }
}

/// Chat-specific avatar: accepts a raw name + optional avatarUrl.
/// Shows a CachedNetworkImage when the URL is available, otherwise
/// falls back to a coloured circle with initials.
class ChatUserAvatar extends StatelessWidget {
  const ChatUserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 42,
  });

  final String name;
  final String? avatarUrl;
  final double size;

  static const _palette = [
    Color(0xFF3A5BFF),
    Color(0xFF34C759),
    Color(0xFFFF9F0A),
    Color(0xFFFF453A),
    Color(0xFF5AC8FA),
    Color(0xFFAF52DE),
  ];

  String get _initials {
    final t = name.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return t[0].toUpperCase();
  }

  Color get _color {
    if (name.isEmpty) return _palette[0];
    return _palette[name.codeUnitAt(0) % _palette.length];
  }

  Widget _initials_(Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        ),
        child: Center(
          child: Text(
            _initials,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.36,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final color = _color;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _initials_(color),
          errorWidget: (_, __, ___) => _initials_(color),
        ),
      );
    }
    return _initials_(color);
  }
}