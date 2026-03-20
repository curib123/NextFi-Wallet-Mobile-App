import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_fi/app/theme/app_color.dart';

void main() {
  test('theme style catalog is restricted to blue variants', () {
    expect(AppColor.themeStyleCount, 4);
    expect(AppColor.themeStyleLabel(0), 'Midnight Blue');
    expect(AppColor.themeStyleLabel(1), 'Electric Blue');
    expect(AppColor.themeStyleLabel(2), 'Ocean Blue');
    expect(AppColor.themeStyleLabel(3), 'Cobalt Blue');
    expect(AppColor.normalizeThemeStyleIndex(9), 1);
    expect(
      AppColor.themeStylePreview(3, Brightness.light),
      const Color(0xFF1247D6),
    );
  });
}
