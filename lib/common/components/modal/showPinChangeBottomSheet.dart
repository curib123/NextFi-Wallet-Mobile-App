// lib/common/components/security_pin_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/Services/security_storage.dart';

/// Open the modal. Returns true if changed/created, false/null if cancelled.
///
/// Flow:
/// - If a PIN exists → show a Verify PIN sheet first.
///   - On success → open the Change PIN sheet (no "old PIN" field).
/// - If no PIN exists → open the Create PIN sheet directly.
Future<bool?> showPinChangeBottomSheet(BuildContext context) async {
  final hasPin = await SecurityStorage.hasPin();

  bool preAuthed = false;
  if (hasPin) {
    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _VerifyCurrentPinSheet(),
    );

    if (verified != true) {
      // User cancelled or failed verification.
      return verified;
    }
    preAuthed = true;
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PinChangeSheet(preAuthed: preAuthed),
  );
}

/// ─────────────────────────────────────────────────────────────────────────────
/// VERIFY CURRENT PIN (single-field gate)
/// ─────────────────────────────────────────────────────────────────────────────
class _VerifyCurrentPinSheet extends StatefulWidget {
  const _VerifyCurrentPinSheet({super.key});
  @override
  State<_VerifyCurrentPinSheet> createState() => _VerifyCurrentPinSheetState();
}

class _VerifyCurrentPinSheetState extends State<_VerifyCurrentPinSheet> {
  static const int _requiredLen = 6;

  final _pinC = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  Duration? _lockoutRemaining;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _initLockout();
  }

  @override
  void dispose() {
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

  Future<void> _submit() async {
    if (_submitting) return;
    final pin = _pinC.text.trim();

    final lockedOut = _lockoutRemaining != null && _lockoutRemaining! > Duration.zero;
    if (lockedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Too many attempts. Try again in ${_lockoutRemaining!.inSeconds}s.')),
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be exactly 6 digits')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final ok = await SecurityStorage.verifyPin(pin);
      if (ok) {
        _pinC.clear();
        if (!mounted) return;
        // Success → Close this sheet and allow opening the change sheet.
        Navigator.pop(context, true);
      } else {
        final rem = await SecurityStorage.lockoutRemaining();
        if (mounted) {
          setState(() => _lockoutRemaining = rem);
          _startOrStopLockoutTimer(rem);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rem != null && rem > Duration.zero
                ? 'Too many attempts. Try again in ${rem.inSeconds}s.'
                : 'Invalid PIN'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final cs = Theme.of(context).colorScheme;

    final isLockedOut = _lockoutRemaining != null && _lockoutRemaining! > Duration.zero;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.badgeCheck, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Verify Current PIN',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(context, false),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Enter your 6-digit PIN to continue.',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
          ),
          if (isLockedOut) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Text(
                "Too many attempts. Try again in ${_lockoutRemaining!.inSeconds}s.",
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // PIN field
          TextField(
            controller: _pinC,
            enabled: !_submitting && !isLockedOut,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            obscureText: _obscure,
            maxLength: _requiredLen,
            decoration: InputDecoration(
              counterText: '',
              labelText: 'Current PIN',
              filled: true,
              fillColor: cs.surfaceContainerLowest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? LucideIcons.eyeOff : LucideIcons.eye),
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Show' : 'Hide',
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_submitting || isLockedOut) ? null : () { _submit(); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Verify'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// CHANGE / CREATE PIN (no "old PIN" field — we already pre-auth’d)
/// ─────────────────────────────────────────────────────────────────────────────
class _PinChangeSheet extends StatefulWidget {
  const _PinChangeSheet({super.key, this.preAuthed = false});
  final bool preAuthed;

  @override
  State<_PinChangeSheet> createState() => _PinChangeSheetState();
}

class _PinChangeSheetState extends State<_PinChangeSheet> {
  static const int _requiredLen = 6;

  final _formKey = GlobalKey<FormState>();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();

  final _newF = FocusNode();
  final _confirmF = FocusNode();

  bool _hasExisting = false;
  bool _submitting = false;
  bool _obNew = true, _obConfirm = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
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

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final newPin = _newC.text.trim();
      final confirm = _confirmC.text.trim();

      if (newPin != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New PIN and confirmation do not match')),
        );
        return;
      }

      if (_hasExisting) {
        if (widget.preAuthed) {
          // We already verified the old PIN → directly set the new PIN.
          await SecurityStorage.setPin(newPin);
        } else {
          // Fallback path if someone opens this sheet directly.
          // This will ask SecurityStorage to verify old, but we have no old value here,
          // so better to block and instruct to use the proper entrypoint.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please verify your current PIN first.')),
          );
          return;
        }
      } else {
        // CREATE flow
        await SecurityStorage.setPin(newPin);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_hasExisting ? 'PIN updated successfully' : 'PIN created successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.shield, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _hasExisting ? 'Change Security PIN' : 'Create Security PIN',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.pop(context, false),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _hasExisting
                    ? 'Set your new 6-digit PIN.'
                    : 'Create a new 6-digit PIN.',
                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 12),

            // New PIN
            _PinField(
              controller: _newC,
              focusNode: _newF,
              label: 'New PIN',
              obscure: _obNew,
              onToggleObscure: () => setState(() => _obNew = !_obNew),
              validator: _validatePin,
              onFieldSubmitted: (_) => _confirmF.requestFocus(),
            ),
            const SizedBox(height: 10),

            // Confirm
            _PinField(
              controller: _confirmC,
              focusNode: _confirmF,
              label: 'Confirm New PIN',
              obscure: _obConfirm,
              onToggleObscure: () => setState(() => _obConfirm = !_obConfirm),
              validator: _validatePin,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : () { _submit(); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(_hasExisting ? 'Save' : 'Create'),
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

/// Reusable PIN field used in both sheets.
class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.obscure,
    required this.onToggleObscure,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final bool obscure;
  final bool enabled;
  final VoidCallback onToggleObscure;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      obscureText: obscure,
      maxLength: 6, // enforce 6-digit UI
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: IconButton(
          icon: Icon(obscure ? LucideIcons.eyeOff : LucideIcons.eye),
          onPressed: onToggleObscure,
          tooltip: obscure ? 'Show' : 'Hide',
        ),
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
