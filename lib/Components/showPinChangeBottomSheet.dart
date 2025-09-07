// lib/Components/security_pin_sheet.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/security_storage.dart';

/// Shared key for the app PIN
const String kAppPinKey = 'app_pin_v1';

/// Open the modal. Returns true if changed, false/null if cancelled.
Future<bool?> showPinChangeBottomSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PinChangeSheet(),
  );
}

class _PinChangeSheet extends StatefulWidget {
  const _PinChangeSheet({super.key});
  @override
  State<_PinChangeSheet> createState() => _PinChangeSheetState();
}

class _PinChangeSheetState extends State<_PinChangeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _oldC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();

  final _oldF = FocusNode();
  final _newF = FocusNode();
  final _confirmF = FocusNode();

  bool _hasExisting = false;
  bool _obOld = true, _obNew = true, _obConfirm = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final has = await SecurityStorage.containsKey(kAppPinKey);
    if (mounted) setState(() => _hasExisting = has);
  }

  @override
  void dispose() {
    _oldC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    _oldF.dispose();
    _newF.dispose();
    _confirmF.dispose();
    super.dispose();
  }

  String? _validatePin(String? v, {bool allowEmpty = false}) {
    final s = (v ?? '').trim();
    if (!allowEmpty && s.isEmpty) return 'Required';
    if (s.isEmpty && allowEmpty) return null;
    if (!RegExp(r'^\d{4,8}$').hasMatch(s)) {
      return 'PIN must be 4–8 digits';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      // Verify old if required
      if (_hasExisting) {
        final current = (await SecurityStorage.read(kAppPinKey)) ?? '';
        if (_oldC.text.trim() != current) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect old PIN')),
            );
          }
          return;
        }
      }

      // Verify new vs confirm
      final newPin = _newC.text.trim();
      final confirm = _confirmC.text.trim();
      if (newPin != confirm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New PIN and confirmation do not match')),
          );
        }
        return;
      }
      if (_hasExisting && newPin == _oldC.text.trim()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New PIN must be different from old PIN')),
          );
        }
        return;
      }

      await SecurityStorage.save(kAppPinKey, newPin);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN updated successfully')),
        );
        Navigator.pop(context, true);
      }
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
                const Expanded(
                  child: Text(
                    'Change Security PIN',
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
                _hasExisting
                    ? 'Enter your old PIN, then set a new one.'
                    : 'No PIN set yet. Create a new PIN.',
                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 12),

            // Old PIN (required only if existing)
            if (_hasExisting) ...[
              _PinField(
                controller: _oldC,
                focusNode: _oldF,
                label: 'Old PIN',
                obscure: _obOld,
                onToggleObscure: () => setState(() => _obOld = !_obOld),
                validator: (v) => _validatePin(v),
                onFieldSubmitted: (_) => _newF.requestFocus(),
              ),
              const SizedBox(height: 10),
            ],

            // New PIN
            _PinField(
              controller: _newC,
              focusNode: _newF,
              label: 'New PIN',
              obscure: _obNew,
              onToggleObscure: () => setState(() => _obNew = !_obNew),
              validator: (v) => _validatePin(v),
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
              validator: (v) => _validatePin(v),
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
                    onPressed: _submitting ? null : _submit,
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
                        : const Text('Save'),
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

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.obscure,
    required this.onToggleObscure,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      obscureText: obscure,
      maxLength: 8,
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
