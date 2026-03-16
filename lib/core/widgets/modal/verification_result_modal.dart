import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';

Future<void> showVerificationResultModal(
  BuildContext context, {
  required String title,
  required String message,
  bool isError = false,
}) {
  return showAppModalBottomSheet<void>(
    context,
    builder: (_) => _VerificationResultModal(
      title: title,
      message: message,
      isError: isError,
    ),
  );
}

class _VerificationResultModal extends StatefulWidget {
  const _VerificationResultModal({
    required this.title,
    required this.message,
    required this.isError,
  });

  final String title;
  final String message;
  final bool isError;

  @override
  State<_VerificationResultModal> createState() =>
      _VerificationResultModalState();
}

class _VerificationResultModalState extends State<_VerificationResultModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scaleAnim = Tween<double>(
      begin: 0.72,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    HapticFeedback.lightImpact();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final accent = widget.isError ? c.error : c.success;

    return FadeTransition(
      opacity: _fadeAnim,
      child: AppModalBase(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: _ResultIcon(isError: widget.isError, accent: accent),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 28),
            _OkButton(accent: accent, ctx: context),
          ],
        ),
      ),
    );
  }
}

class _ResultIcon extends StatelessWidget {
  const _ResultIcon({required this.isError, required this.accent});

  final bool isError;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        isError
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded,
        color: accent,
        size: 34,
      ),
    );
  }
}

class _OkButton extends StatelessWidget {
  const _OkButton({required this.accent, required this.ctx});

  final Color accent;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: AppElevatedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(ctx).pop();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: AppColor.of(context).onPrimary,
          elevation: 0,
          shadowColor: AppColor.of(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Got it',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
