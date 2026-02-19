import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';

Future<bool> showVerificationConsentModal(BuildContext context) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VerificationConsentSheet(),
  );
  return accepted == true;
}

class _VerificationConsentSheet extends StatefulWidget {
  const _VerificationConsentSheet();

  @override
  State<_VerificationConsentSheet> createState() =>
      _VerificationConsentSheetState();
}

class _VerificationConsentSheetState extends State<_VerificationConsentSheet> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final insets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border.withOpacity(0.32), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.gavel_rounded, color: c.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Verification Consent',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'To continue, you must consent to identity verification processing.',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.8,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.background.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border.withOpacity(0.2)),
              ),
              child: Text(
                'By proceeding, you authorize NextFi and its verification providers to collect, process, and store your personal data, including profile details, government ID images, selfie images, and payment account details, for KYC/AML compliance, fraud prevention, sanctions screening, and legal obligations. Data may be shared with regulated processors and competent authorities when required by law and retained according to applicable regulations and NextFi policy.',
                style: TextStyle(
                  color: c.textPrimary.withOpacity(0.92),
                  fontSize: 12.4,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _accepted = !_accepted),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _accepted,
                      onChanged: (v) => setState(() => _accepted = v == true),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'I confirm the information I submit is accurate and I consent to verification processing under NextFi Terms and Privacy Notice.',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border.withOpacity(0.55)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppElevatedButton(
                    onPressed: _accepted
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: c.border.withOpacity(0.2),
                      disabledForegroundColor: c.textSecondary.withOpacity(
                        0.45,
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'I Agree',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
