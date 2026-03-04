import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/modal/trade_sheet_base.dart';

class TradeConfirmSheet extends StatelessWidget {
  const TradeConfirmSheet({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.colors,
    this.isDestructive = false,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final AppColor colors;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final actionColor = isDestructive ? colors.error : colors.primary;
    return TradeSheetBase(
      colors: colors,
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              fontSize: 13.5,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Center(
                      child: Text(
                        'Go Back',
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: actionColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        confirmLabel,
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColor.of(context).onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
