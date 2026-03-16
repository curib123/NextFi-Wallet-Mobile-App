import 'package:flutter/material.dart';

import 'package:next_fi/app/theme/app_color.dart';

Future<T?> showAppModalBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

class AppModalBase extends StatelessWidget {
  const AppModalBase({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 12),
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(28)),
    this.backgroundColor,
    this.borderColor,
    this.showHandle = true,
    this.handleBottomSpacing = 16,
    this.animateInsets = true,
    this.safeAreaTop = false,
    this.maxHeightFactor,
    this.maxWidth = 680,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showHandle;
  final double handleBottomSpacing;
  final bool animateInsets;
  final bool safeAreaTop;
  final double? maxHeightFactor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final media = MediaQuery.of(context);
    final defaultMargin = margin == const EdgeInsets.fromLTRB(12, 0, 12, 12);
    final horizontalMargin = media.size.width >= 1200
        ? 32.0
        : media.size.width >= 720
        ? 24.0
        : 12.0;
    final modal = Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeightFactor == null
              ? media.size.height * 0.94
              : media.size.height * maxHeightFactor!,
        ),
        child: Container(
          margin: defaultMargin
              ? EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 12)
              : margin,
          decoration: BoxDecoration(
            color: backgroundColor ?? colors.surface,
            borderRadius: borderRadius,
            border: Border.all(
              color: borderColor ?? colors.border.withValues(alpha: 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 32,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: safeAreaTop,
            bottom: false,
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (showHandle)
                    Container(
                      width: 36,
                      height: 4,
                      margin: EdgeInsets.only(bottom: handleBottomSpacing),
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!animateInsets) {
      return modal;
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: modal,
    );
  }
}
