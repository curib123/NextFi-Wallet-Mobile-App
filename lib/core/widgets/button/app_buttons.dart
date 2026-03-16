import 'package:flutter/material.dart';

enum AppButtonVariant { elevated, outlined, text, filled }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.variant,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.fullWidth = false,
    this.maxResponsiveWidth = 460,
  }) : icon = null,
       label = null;

  const AppButton.icon({
    super.key,
    required this.variant,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.fullWidth = false,
    this.maxResponsiveWidth = 460,
  }) : child = null;

  final AppButtonVariant variant;
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final bool fullWidth;
  final double maxResponsiveWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 360;
    final resolvedStyle = (style ?? const ButtonStyle()).copyWith(
      minimumSize: WidgetStatePropertyAll(Size(0, isCompact ? 48 : 52)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 18,
          vertical: isCompact ? 12 : 14,
        ),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );

    final Widget button;
    switch (variant) {
      case AppButtonVariant.elevated:
        button = child != null
            ? ElevatedButton(
                onPressed: onPressed,
                style: resolvedStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                clipBehavior: clipBehavior,
                child: child!,
              )
            : ElevatedButton.icon(
                onPressed: onPressed,
                style: resolvedStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                clipBehavior: clipBehavior,
                icon: icon!,
                label: label!,
              );
        break;
      case AppButtonVariant.outlined:
        button = child != null
            ? OutlinedButton(
                onPressed: onPressed,
                style: resolvedStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                clipBehavior: clipBehavior,
                child: child!,
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                style: resolvedStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                clipBehavior: clipBehavior,
                icon: icon!,
                label: label!,
              );
        break;
      case AppButtonVariant.text:
        button = child != null
            ? TextButton(
                onPressed: onPressed,
                style: resolvedStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                clipBehavior: clipBehavior,
                child: child!,
              )
            : TextButton.icon(
                onPressed: onPressed,
                style: resolvedStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                clipBehavior: clipBehavior,
                icon: icon!,
                label: label!,
              );
        break;
      case AppButtonVariant.filled:
        button = child != null
            ? FilledButton(
                onPressed: onPressed,
                style: resolvedStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                clipBehavior: clipBehavior,
                child: child!,
              )
            : FilledButton.icon(
                onPressed: onPressed,
                style: resolvedStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                clipBehavior: clipBehavior,
                icon: icon!,
                label: label!,
              );
        break;
    }

    if (!fullWidth) return button;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: media.size.width >= 720
              ? maxResponsiveWidth
              : double.infinity,
        ),
        child: SizedBox(width: double.infinity, child: button),
      ),
    );
  }
}

class AppElevatedButton extends StatelessWidget {
  const AppElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.fullWidth = false,
    this.icon,
    this.label,
  });

  const AppElevatedButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.fullWidth = false,
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return child != null
        ? AppButton(
            variant: AppButtonVariant.elevated,
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            fullWidth: fullWidth,
            child: child!,
          )
        : AppButton.icon(
            variant: AppButtonVariant.elevated,
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            fullWidth: fullWidth,
            icon: icon!,
            label: label!,
          );
  }
}

class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.fullWidth = false,
    this.icon,
    this.label,
  });

  const AppOutlinedButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.fullWidth = false,
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return child != null
        ? AppButton(
            variant: AppButtonVariant.outlined,
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            fullWidth: fullWidth,
            child: child!,
          )
        : AppButton.icon(
            variant: AppButtonVariant.outlined,
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            fullWidth: fullWidth,
            icon: icon!,
            label: label!,
          );
  }
}

class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.fullWidth = false,
    this.icon,
    this.label,
  });

  const AppTextButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.fullWidth = false,
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return child != null
        ? AppButton(
            variant: AppButtonVariant.text,
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            fullWidth: fullWidth,
            child: child!,
          )
        : AppButton.icon(
            variant: AppButtonVariant.text,
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            fullWidth: fullWidth,
            icon: icon!,
            label: label!,
          );
  }
}

class AppFilledButton extends StatelessWidget {
  const AppFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.fullWidth = false,
    this.icon,
    this.label,
  });

  const AppFilledButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.fullWidth = false,
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return child != null
        ? AppButton(
            variant: AppButtonVariant.filled,
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            fullWidth: fullWidth,
            child: child!,
          )
        : AppButton.icon(
            variant: AppButtonVariant.filled,
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            fullWidth: fullWidth,
            icon: icon!,
            label: label!,
          );
  }
}
