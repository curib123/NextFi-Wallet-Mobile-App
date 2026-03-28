import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_state.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/header_section.dart';

void main() {
  testWidgets(
    'wallet header shows Scan instead of Swap and triggers the scan action',
    (WidgetTester tester) async {
      late AnimationController controller;
      var scanTapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller = AnimationController(
                vsync: tester,
                duration: const Duration(milliseconds: 300),
              );
              return Scaffold(
                body: HeaderSection(
                  colors: AppColor.of(context),
                  currencyFmt: NumberFormat.simpleCurrency(decimalDigits: 2),
                  loadingBalances: false,
                  totalFiat: 1234.56,
                  lastBalancesAt: DateTime(2026, 3, 28, 10, 30),
                  onScan: () {
                    scanTapCount += 1;
                  },
                  onSend: () {},
                  onReceive: () {},
                  livePulse: controller,
                  incomingStrip: const SizedBox.shrink(),
                  selectedWindow: PriceWindow.h24,
                  onWindowChanged: (_) {},
                  reserveXlm: 1.5,
                  chartSeries: const <double>[],
                  chartDeltaFiat: 0,
                ),
              );
            },
          ),
        ),
      );
      addTearDown(controller.dispose);

      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Swap'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.scanLine).last);
      await tester.pump();

      expect(scanTapCount, 1);
    },
  );
}
