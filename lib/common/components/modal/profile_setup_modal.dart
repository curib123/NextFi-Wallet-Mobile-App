import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/countries/country_service.dart';
import 'package:next_fi/services/countries/models/country_model.dart';
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
  CountryModel? _selectedCountry;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _usernameCtrl = TextEditingController(text: p?.username ?? '');
    _displayNameCtrl = TextEditingController(text: p?.displayName ?? '');
    if (p?.country != null && p!.country!.isNotEmpty) {
      _tryPrefillCountry(p.country!);
    }
  }

  Future<void> _tryPrefillCountry(String value) async {
    try {
      final countries = await CountryService.I.getAll();
      final match = countries.firstWhere(
        (c) =>
            c.name.toLowerCase() == value.toLowerCase() ||
            c.code.toLowerCase() == value.toLowerCase(),
        orElse: () => CountryModel(name: value, code: '', flag: ''),
      );
      if (mounted) setState(() => _selectedCountry = match);
    } catch (_) {
      if (mounted) {
        setState(
          () => _selectedCountry = CountryModel(name: value, code: '', flag: ''),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final req = UpsertProfileRequest(
        username: _usernameCtrl.text,
        displayName: _displayNameCtrl.text,
        country: _selectedCountry?.name,
        includeNulls: true,
      );
      await ProfileCoreService.I.upsertMe(req);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  String? _validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!UpsertProfileRequest.isValidUsername(v)) {
      return '3-30 chars, letters/numbers/underscore/dot only';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
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
                                validator: _validateUsername,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9_.]'),
                                  ),
                                ],
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

                        // Location section
                        _SectionHeader(label: 'LOCATION', c: c),
                        const SizedBox(height: 10),
                        _CountryPickerField(
                          c: c,
                          selected: _selectedCountry,
                          onTap: () async {
                            final picked =
                                await showModalBottomSheet<CountryModel>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const _CountryPickerSheet(),
                            );
                            if (picked != null) {
                              setState(() => _selectedCountry = picked);
                            }
                          },
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
// FORM FIELD — flat, soft, modern
// ─────────────────────────────────────────────────────────────────────────────

class _FormField extends StatefulWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.action,
    required this.c,
    this.multiline = false,
    this.validator,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputAction action;
  final AppColor c;
  final bool multiline;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

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
      borderSide: BorderSide(
        color: c.border.withOpacity(0.3),
        width: 1.2,
      ),
    );

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: TextFormField(
        controller: widget.controller,
        textInputAction: widget.action,
        minLines: widget.multiline ? 2 : 1,
        maxLines: widget.multiline ? 4 : 1,
        validator: widget.validator,
        inputFormatters: widget.inputFormatters,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: c.textSecondary.withOpacity(0.45),
            fontSize: 13.5,
          ),
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
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
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
            borderSide: BorderSide(
              color: c.border.withOpacity(0.25),
              width: 1.2,
            ),
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
        child: Icon(Icons.close_rounded, size: 17, color: c.textSecondary),
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
              style: TextStyle(color: c.error, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTRY PICKER FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _CountryPickerField extends StatelessWidget {
  const _CountryPickerField({
    required this.c,
    required this.selected,
    required this.onTap,
  });

  final AppColor c;
  final CountryModel? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = selected != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.border.withOpacity(0.05),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: c.border.withOpacity(0.25), width: 1.2),
        ),
        child: Row(
          children: [
            Icon(Icons.public_rounded,
                size: 17,
                color: hasValue
                    ? c.primary
                    : c.textSecondary.withOpacity(0.5)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Country',
                    style: TextStyle(
                      fontSize: 11,
                      color: hasValue ? c.primary : c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasValue) ...[
                    const SizedBox(height: 1),
                    Text(
                      '${selected!.flag}  ${selected!.name}',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: c.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else
                    Text(
                      'Select your country',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: c.textSecondary.withOpacity(0.45),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              hasValue ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              size: 18,
              color: hasValue ? c.primary : c.textSecondary.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTRY PICKER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<CountryModel> _all = [];
  List<CountryModel> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final countries = await CountryService.I.getAll();
      if (!mounted) return;
      setState(() {
        _all = countries;
        _filtered = countries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.code.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.border.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select Country',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search countries…',
                hintStyle: TextStyle(
                    color: c.textSecondary.withOpacity(0.5), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18, color: c.textSecondary.withOpacity(0.5)),
                filled: true,
                fillColor: c.border.withOpacity(0.07),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: c.textPrimary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: c.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: TextStyle(
                                    color: c.error, fontSize: 13),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final country = _filtered[i];
                          return ListTile(
                            leading: Text(country.flag,
                                style: const TextStyle(fontSize: 22)),
                            title: Text(
                              country.name,
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                            trailing: Text(
                              country.code,
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 12),
                            ),
                            onTap: () =>
                                Navigator.of(context).pop(country),
                          );
                        },
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
      child: AppElevatedButton(
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