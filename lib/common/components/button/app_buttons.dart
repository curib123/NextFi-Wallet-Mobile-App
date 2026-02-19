import 'package:flutter/material.dart';

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
    this.icon, this.label,
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
    final button = child != null
        ? ElevatedButton(
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            child: child!,
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            icon: icon!,
            label: label!,
          );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
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
    this.icon, this.label,
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
    final button = child != null
        ? OutlinedButton(
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            child: child!,
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            icon: icon!,
            label: label!,
          );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
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
    this.icon, this.label,
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
    final button = child != null
        ? TextButton(
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            child: child!,
          )
        : TextButton.icon(
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            icon: icon!,
            label: label!,
          );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
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
    this.icon, this.label,
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
    final button = child != null
        ? FilledButton(
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            child: child!,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: clipBehavior,
            icon: icon!,
            label: label!,
          );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
