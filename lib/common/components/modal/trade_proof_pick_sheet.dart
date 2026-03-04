import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/modal/trade_sheet_base.dart';

class TradeProofPickSheet extends StatelessWidget {
  const TradeProofPickSheet({
    super.key,
    required this.colors,
    this.forceUpload = false,
  });

  final AppColor colors;
  final bool forceUpload;

  @override
  Widget build(BuildContext context) {
    return TradeSheetBase(
      colors: colors,
      child: Column(
        children: [
          Icon(Icons.image_rounded, color: colors.primary, size: 36),
          const SizedBox(height: 14),
          Text(
            forceUpload ? 'Upload Payment Proof' : 'Attach Payment Proof?',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            forceUpload
                ? 'Upload a screenshot or receipt now.'
                : 'Optionally attach a screenshot of your payment confirmation.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_rounded,
                    color: AppColor.of(context).onPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Choose from Gallery',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColor.of(context).onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!forceUpload) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Center(
                  child: Text(
                    'Skip for Now',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
