// lib/common/components/avatar/user_avatar.dart

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