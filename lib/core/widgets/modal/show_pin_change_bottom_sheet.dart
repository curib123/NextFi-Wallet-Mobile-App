// lib/common/components/security_pin_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';
import 'package:next_fi/core/services/secure_storage/security_storage.dart';

/// Open the modal. Returns true if changed/created, false/null if cancelled.
///
/// Flow:
/// - If a PIN exists â†’ show a Verify PIN sheet first.
///   - On success â†’ open the Change PIN sheet (no "old PIN" field).
/// - If no PIN exists â†’ open the Create PIN sheet directly.
Future<bool?> showPinChangeBottomSheet(BuildContext context) async {
  final hasPin = await SecurityStorage.hasPin();
  if (!context.mounted) return null;

  bool preAuthed = false;
  if (hasPin) {
    final verified = await showAppModalBottomSheet<bool>(
      context,
      builder: (_) => const _VerifyCurrentPinSheet(),
    );

    if (verified != true) {
      return verified;
    }
    if (!context.mounted) return null;
    preAuthed = true;
  }

  return showAppModalBottomSheet<bool>(
    context,
    builder: (_) => _PinChangeSheet(preAuthed: preAuthed),
  );
}

/// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
/// VERIFY CURRENT PIN (single-field gate)
/// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _VerifyCurrentPinSheet extends StatefulWidget {
  const _VerifyCurrentPinSheet();

  @override
  State<_VerifyCurrentPinSheet> createState() => _VerifyCurrentPinSheetState();
}

class _VerifyCurrentPinSheetState extends State<_VerifyCurrentPinSheet>
    with SingleTickerProviderStateMixin {
  final _pinC = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  Duration? _lockoutRemaining;
  Timer? _lockoutTimer;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initLockout();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pinC.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLockout() async {
    final rem = await SecurityStorage.lockoutRemaining();
    if (!mounted) return;
    setState(() => _lockoutRemaining = rem);
    _startOrStopLockoutTimer(rem);
  }

  void _startOrStopLockoutTimer(Duration? remaining) {
    _lockoutTimer?.cancel();
    if (remaining == null || remaining <= Duration.zero) return;

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final rem = await SecurityStorage.lockoutRemaining();
      if (!mounted) return;
      if (rem == null || rem <= Duration.zero) {
        t.cancel();
        setState(() => _lockoutRemaining = null);
      } else {
        setState(() => _lockoutRemaining = rem);
      }
    });
  }

  Future<void> _close([bool? result]) async {
    await _animController.reverse();
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final pin = _pinC.text.trim();

    final lockedOut =
        _lockoutRemaining != null && _lockoutRemaining! > Duration.zero;
    if (lockedOut) {
      _showError(
        'Too many attempts. Try again in ${_lockoutRemaining!.inSeconds}s.',
      );
      HapticFeedback.heavyImpact();
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _showError('PIN must be exactly 6 digits');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.selectionClick();

    try {
      final ok = await SecurityStorage.verifyPin(pin);
      if (ok) {
        _pinC.clear();
        HapticFeedback.mediumImpact();
        if (!mounted) return;
        await _close(true);
      } else {
        final rem = await SecurityStorage.lockoutRemaining();
        if (mounted) {
          setState(() => _lockoutRemaining = rem);
          _startOrStopLockoutTimer(rem);
        }
        _showError(
          rem != null && rem > Duration.zero
              ? 'Too many attempts. Try again in ${rem.inSeconds}s.'
              : 'Invalid PIN',
        );
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColor.of(context).error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final isLockedOut =
        _lockoutRemaining != null && _lockoutRemaining! > Duration.zero;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColor.of(context).textPrimary.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  _buildHandle(colors),
                  const SizedBox(height: 8),

                  // Header
                  _buildHeader(
                    colors,
                    icon: LucideIcons.shieldCheck,
                    title: 'Verify PIN',
                    subtitle: 'Enter your 6-digit PIN to continue',
                    onClose: () => _close(false),
                  ),
                  const SizedBox(height: 20),

                  // Lockout warning
                  if (isLockedOut)
                    _buildLockoutWarning(colors, _lockoutRemaining!),

                  if (isLockedOut) const SizedBox(height: 16),

                  // PIN input
                  _buildPinInput(
                    colors,
                    controller: _pinC,
                    label: 'Current PIN',
                    obscure: _obscure,
                    enabled: !_submitting && !isLockedOut,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    onSubmit: _submit,
                  ),

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: _buildButton(
                          colors,
                          label: 'Cancel',
                          icon: LucideIcons.x,
                          outlined: true,
                          onPressed: _submitting ? null : () => _close(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildButton(
                          colors,
                          label: _submitting ? 'Verifying...' : 'Verify',
                          icon: _submitting
                              ? LucideIcons.loader2
                              : LucideIcons.checkCircle2,
                          loading: _submitting,
                          onPressed: (_submitting || isLockedOut)
                              ? null
                              : _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
/// CHANGE / CREATE PIN
/// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _PinChangeSheet extends StatefulWidget {
  const _PinChangeSheet({this.preAuthed = false});
  final bool preAuthed;

  @override
  State<_PinChangeSheet> createState() => _PinChangeSheetState();
}

class _PinChangeSheetState extends State<_PinChangeSheet>
    with SingleTickerProviderStateMixin {
  static const int _requiredLen = 6;

  final _formKey = GlobalKey<FormState>();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();

  final _newF = FocusNode();
  final _confirmF = FocusNode();

  bool _hasExisting = false;
  bool _submitting = false;
  bool _obNew = true, _obConfirm = true;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _init();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _newC.dispose();
    _confirmC.dispose();
    _newF.dispose();
    _confirmF.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final has = await SecurityStorage.hasPin();
    if (mounted) setState(() => _hasExisting = has);
  }

  String? _validatePin(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (!RegExp(r'^\d{6}$').hasMatch(s)) {
      return 'PIN must be exactly $_requiredLen digits';
    }
    return null;
  }

  Future<void> _close([bool? result]) async {
    await _animController.reverse();
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.selectionClick();

    try {
      final newPin = _newC.text.trim();
      final confirm = _confirmC.text.trim();

      if (newPin != confirm) {
        _showError('New PIN and confirmation do not match');
        HapticFeedback.heavyImpact();
        return;
      }

      if (_hasExisting) {
        if (widget.preAuthed) {
          await SecurityStorage.setPin(newPin);
        } else {
          _showError('Please verify your current PIN first.');
          return;
        }
      } else {
        await SecurityStorage.setPin(newPin);
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _showSuccess(
        _hasExisting ? 'PIN updated successfully' : 'PIN created successfully',
      );
      await Future.delayed(const Duration(milliseconds: 500));
      await _close(true);
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColor.of(context).error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColor.of(context).success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColor.of(context).textPrimary.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    _buildHandle(colors),
                    const SizedBox(height: 8),

                    // Header
                    _buildHeader(
                      colors,
                      icon: LucideIcons.shield,
                      title: _hasExisting ? 'Change PIN' : 'Create PIN',
                      subtitle: _hasExisting
                          ? 'Set your new 6-digit PIN'
                          : 'Secure your wallet with a PIN',
                      onClose: () => _close(false),
                    ),
                    const SizedBox(height: 20),

                    // Security tips
                    _buildSecurityTips(colors),
                    const SizedBox(height: 20),

                    // New PIN
                    _buildPinInput(
                      colors,
                      controller: _newC,
                      focusNode: _newF,
                      label: 'New PIN',
                      obscure: _obNew,
                      validator: _validatePin,
                      onToggleObscure: () => setState(() => _obNew = !_obNew),
                      onFieldSubmitted: (_) => _confirmF.requestFocus(),
                    ),
                    const SizedBox(height: 14),

                    // Confirm PIN
                    _buildPinInput(
                      colors,
                      controller: _confirmC,
                      focusNode: _confirmF,
                      label: 'Confirm New PIN',
                      obscure: _obConfirm,
                      validator: _validatePin,
                      onToggleObscure: () =>
                          setState(() => _obConfirm = !_obConfirm),
                      onFieldSubmitted: (_) => _submit(),
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: _buildButton(
                            colors,
                            label: 'Cancel',
                            icon: LucideIcons.x,
                            outlined: true,
                            onPressed: _submitting ? null : () => _close(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildButton(
                            colors,
                            label: _submitting
                                ? 'Saving...'
                                : (_hasExisting ? 'Save PIN' : 'Create PIN'),
                            icon: _submitting
                                ? LucideIcons.loader2
                                : LucideIcons.checkCircle2,
                            loading: _submitting,
                            onPressed: _submitting ? null : _submit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
/// Reusable UI Components
/// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

Widget _buildHandle(AppColor colors) {
  return Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: colors.border.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(100),
    ),
  );
}

Widget _buildHeader(
  AppColor colors, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onClose,
}) {
  return Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: colors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: colors.onPrimary, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ),
      ),
      Material(
        color: colors.surface,
        child: InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(LucideIcons.x, color: colors.textSecondary, size: 20),
          ),
        ),
      ),
    ],
  );
}

Widget _buildLockoutWarning(AppColor colors, Duration remaining) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: colors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: colors.error.withValues(alpha: 0.3), width: 1),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.shieldAlert, color: colors.error, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Too many attempts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.error,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Try again in ${remaining.inSeconds}s',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.error.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildSecurityTips(AppColor colors) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: colors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: colors.primary.withValues(alpha: 0.2),
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.lightbulb, color: colors.primary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Choose a PIN that\'s easy to remember but hard to guess',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

Widget _buildPinInput(
  AppColor colors, {
  required TextEditingController controller,
  FocusNode? focusNode,
  required String label,
  required bool obscure,
  bool enabled = true,
  required VoidCallback onToggleObscure,
  String? Function(String?)? validator,
  void Function(String)? onFieldSubmitted,
  VoidCallback? onSubmit,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          obscureText: obscure,
          maxLength: 6,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'â— â— â— â— â— â—',
            hintStyle: TextStyle(
              color: colors.textSecondary.withValues(alpha: 0.3),
              letterSpacing: 8,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 18,
                color: colors.textSecondary,
              ),
              onPressed: onToggleObscure,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: validator,
          onFieldSubmitted: onFieldSubmitted ?? (_) => onSubmit?.call(),
        ),
      ),
    ],
  );
}

Widget _buildButton(
  AppColor colors, {
  required String label,
  required IconData icon,
  bool outlined = false,
  bool loading = false,
  VoidCallback? onPressed,
}) {
  if (outlined) {
    return AppOutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 16), const SizedBox(width: 8), Text(label)],
      ),
    );
  }

  return AppElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      disabledBackgroundColor: colors.textSecondary.withValues(alpha: 0.2),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(colors.onPrimary),
            ),
          )
        else
          Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(label),
      ],
    ),
  );
}
