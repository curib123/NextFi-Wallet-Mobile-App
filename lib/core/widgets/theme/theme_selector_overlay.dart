import 'package:flutter/material.dart';

import 'package:next_fi/app/theme/app_color.dart';

class ThemeSelectorOverlay extends StatelessWidget {
  const ThemeSelectorOverlay({
    super.key,
    required this.styleIndex,
    required this.onStyleSelected,
  });

  final int styleIndex;
  final ValueChanged<int> onStyleSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 18),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: FloatingActionButton.small(
            heroTag: 'global-theme-selector-fab',
            backgroundColor: colors.surface,
            foregroundColor: colors.textPrimary,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.border),
            ),
            onPressed: () => _showThemeSelector(context),
            child: const Icon(Icons.palette_outlined),
          ),
        ),
      ),
    );
  }

  Future<void> _showThemeSelector(BuildContext context) {
    final colors = AppColor.of(context);
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return _ThemeSelectorSheet(
          selectedIndex: styleIndex,
          onStyleSelected: (index) {
            onStyleSelected(index);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}

class _ThemeSelectorSheet extends StatelessWidget {
  const _ThemeSelectorSheet({
    required this.selectedIndex,
    required this.onStyleSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onStyleSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColor.of(context);
    final brightness = theme.brightness;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Theme Style', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Choose one of 10 accent styles.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppColor.themeStyleCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemBuilder: (context, index) {
              final selected =
                  AppColor.normalizeThemeStyleIndex(selectedIndex) ==
                  AppColor.normalizeThemeStyleIndex(index);
              final preview = AppColor.themeStylePreview(index, brightness);
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onStyleSelected(index),
                child: Ink(
                  decoration: BoxDecoration(
                    color: selected ? colors.surfaceRaised : colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? preview : colors.border,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: preview,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: preview.withValues(alpha: 0.28),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppColor.themeStyleLabel(index),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_rounded, color: preview, size: 18),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
