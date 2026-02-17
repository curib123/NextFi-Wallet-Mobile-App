import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/profile/models/profile_dtos.dart';
import 'package:next_fi/services/profile/models/profile_models.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';

Future<bool?> showProfileSetupModal(
    BuildContext context, {
      ProfileModel? initial,
    }) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfileSetupModal(initial: initial),
  );
}

class _ProfileSetupModal extends StatefulWidget {
  const _ProfileSetupModal({this.initial});

  final ProfileModel? initial;

  @override
  State<_ProfileSetupModal> createState() => _ProfileSetupModalState();
}

class _ProfileSetupModalState extends State<_ProfileSetupModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _usernameCtrl;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _addressCtrl;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _usernameCtrl    = TextEditingController(text: p?.username    ?? '');
    _displayNameCtrl = TextEditingController(text: p?.displayName ?? '');
    _firstNameCtrl   = TextEditingController(text: p?.firstName   ?? '');
    _middleNameCtrl  = TextEditingController(text: p?.middleName  ?? '');
    _lastNameCtrl    = TextEditingController(text: p?.lastName    ?? '');
    _countryCtrl     = TextEditingController(text: p?.country     ?? '');
    _addressCtrl     = TextEditingController(text: p?.address     ?? '');
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _countryCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error  = null;
    });

    try {
      final req = UpsertProfileRequest(
        username:    _usernameCtrl.text,
        displayName: _displayNameCtrl.text,
        firstName:   _firstNameCtrl.text,
        middleName:  _middleNameCtrl.text,
        lastName:    _lastNameCtrl.text,
        country:     _countryCtrl.text,
        address:     _addressCtrl.text,
      );
      await ProfileCoreService.I.upsertMe(req);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error  = e.toString();
      });
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c     = AppColor.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Title bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.initial != null
                                ? 'Edit Profile'
                                : 'Profile Setup',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fill in your identity details',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CloseButton(saving: _saving, c: c),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Divider(height: 1, color: c.border.withOpacity(0.18)),
              const SizedBox(height: 4),

              // ── Form ───────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Public identity section
                        _SectionHeader(label: 'PUBLIC IDENTITY', c: c),
                        const SizedBox(height: 10),
                        _FieldRow(
                          children: [
                            Expanded(
                              child: _FormField(
                                controller: _usernameCtrl,
                                label: 'Username',
                                hint: 'e.g. nextfi_user',
                                icon: Icons.alternate_email_rounded,
                                action: TextInputAction.next,
                                c: c,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _FormField(
                                controller: _displayNameCtrl,
                                label: 'Display Name',
                                hint: 'Your visible name',
                                icon: Icons.badge_outlined,
                                action: TextInputAction.next,
                                c: c,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Legal name section
                        _SectionHeader(label: 'LEGAL NAME', c: c),
                        const SizedBox(height: 10),
                        _FormField(
                          controller: _firstNameCtrl,
                          label: 'First Name',
                          hint: 'Required',
                          icon: Icons.person_outline_rounded,
                          action: TextInputAction.next,
                          required: true,
                          validator: (v) => _required(v, 'First name'),
                          c: c,
                        ),
                        const SizedBox(height: 10),
                        _FormField(
                          controller: _middleNameCtrl,
                          label: 'Middle Name',
                          hint: 'Optional',
                          icon: Icons.person_outline_rounded,
                          action: TextInputAction.next,
                          c: c,
                        ),
                        const SizedBox(height: 10),
                        _FormField(
                          controller: _lastNameCtrl,
                          label: 'Last Name',
                          hint: 'Required',
                          icon: Icons.person_outline_rounded,
                          action: TextInputAction.next,
                          required: true,
                          validator: (v) => _required(v, 'Last name'),
                          c: c,
                        ),

                        const SizedBox(height: 20),

                        // Location section
                        _SectionHeader(label: 'LOCATION', c: c),
                        const SizedBox(height: 10),
                        _FormField(
                          controller: _countryCtrl,
                          label: 'Country',
                          hint: 'e.g. Philippines',
                          icon: Icons.public_rounded,
                          action: TextInputAction.next,
                          required: true,
                          validator: (v) => _required(v, 'Country'),
                          c: c,
                        ),
                        const SizedBox(height: 10),
                        _FormField(
                          controller: _addressCtrl,
                          label: 'Address',
                          hint: 'Street, city, province…',
                          icon: Icons.location_on_outlined,
                          action: TextInputAction.done,
                          required: true,
                          multiline: true,
                          validator: (v) => _required(v, 'Address'),
                          c: c,
                        ),

                        // Error banner
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _ErrorBanner(error: _error!, c: c),
                        ],

                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Save button ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _SaveButton(saving: _saving, onPressed: _save, c: c),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.c});

  final String label;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: c.textSecondary.withOpacity(0.6),
        letterSpacing: 1.0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD ROW (side by side)
// ─────────────────────────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM FIELD  — flat, soft, modern
// ─────────────────────────────────────────────────────────────────────────────

class _FormField extends StatefulWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.action,
    required this.c,
    this.required = false,
    this.multiline = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputAction action;
  final AppColor c;
  final bool required;
  final bool multiline;
  final String? Function(String?)? validator;

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final border = _focused
        ? OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: c.primary, width: 1.5),
    )
        : OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: c.border.withOpacity(0.3), width: 1.2),
    );

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: TextFormField(
        controller: widget.controller,
        textInputAction: widget.action,
        minLines: widget.multiline ? 2 : 1,
        maxLines: widget.multiline ? 4 : 1,
        validator: widget.validator,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.required ? '${widget.label} *' : widget.label,
          hintText: widget.hint,
          hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.45), fontSize: 13.5),
          labelStyle: TextStyle(
            color: _focused ? c.primary : c.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: _focused ? c.primary : c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(
              widget.icon,
              size: 17,
              color: _focused ? c.primary : c.textSecondary.withOpacity(0.5),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          filled: true,
          fillColor: _focused
              ? c.primary.withOpacity(0.03)
              : c.border.withOpacity(0.05),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: widget.multiline ? 14 : 0,
          ),
          border: border,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: c.border.withOpacity(0.25), width: 1.2),
          ),
          focusedBorder: border,
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: c.error.withOpacity(0.6), width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: c.error, width: 1.5),
          ),
          errorStyle: TextStyle(color: c.error, fontSize: 11.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLOSE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.saving, required this.c});

  final bool saving;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : () => Navigator.of(context).pop(false),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: c.border.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close_rounded,
          size: 17,
          color: c.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.c});

  final String error;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: c.error.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.error.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: c.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: c.error,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saving,
    required this.onPressed,
    required this.c,
  });

  final bool saving;
  final VoidCallback onPressed;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: saving
            ? null
            : [
          BoxShadow(
            color: c.primary.withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.primary.withOpacity(0.55),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: saving
              ? Row(
            key: const ValueKey('saving'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white70),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Saving…',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          )
              : Row(
            key: const ValueKey('save'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_rounded, size: 18),
              SizedBox(width: 8),
              Text(
                'Save Profile',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}