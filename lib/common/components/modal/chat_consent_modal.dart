import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';

Future<bool> showChatConsentModal(BuildContext context) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColor.of(context).surface,
    builder: (_) => const _ChatConsentSheet(),
  );
  return accepted == true;
}

class _ChatConsentSheet extends StatefulWidget {
  const _ChatConsentSheet();

  @override
  State<_ChatConsentSheet> createState() => _ChatConsentSheetState();
}

class _ChatConsentSheetState extends State<_ChatConsentSheet> {
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
          border: Border.all(color: c.border.withValues(alpha: 0.32), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColor.of(context).textPrimary.withValues(alpha: 0.14),
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
                    color: c.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: c.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Messenger Consent',
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
              'Before using Messenger, you must agree to communication and data handling terms.',
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
                color: c.background.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border.withValues(alpha: 0.2)),
              ),
              child: Text(
                'By continuing, you agree that chat metadata and encrypted message payload fields may be processed and stored to deliver direct messaging, moderation, dispute support, fraud prevention, and legal compliance. Do not share private keys, passwords, OTPs, or sensitive payment credentials in chat. NextFi may retain records according to applicable laws and policy.',
                style: TextStyle(
                  color: c.textPrimary.withValues(alpha: 0.92),
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
                          'I consent to NextFi Messenger terms and confirm I will use chat only for lawful trading communication.',
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
                      side: BorderSide(color: c.border.withValues(alpha: 0.55)),
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
                      foregroundColor: AppColor.of(context).onPrimary,
                      disabledBackgroundColor: c.border.withValues(alpha: 0.2),
                      disabledForegroundColor: c.textSecondary.withValues(alpha: 
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
