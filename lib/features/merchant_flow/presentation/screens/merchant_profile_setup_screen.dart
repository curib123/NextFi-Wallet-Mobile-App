import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/core/widgets/modal/verification_result_modal.dart';
import 'package:next_fi/core/services/countries/country_service.dart';
import 'package:next_fi/core/services/countries/models/country_model.dart';
import 'package:next_fi/core/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/core/services/merchant_profile/models/merchant_profile_dtos.dart';
import 'package:next_fi/core/services/merchant_profile/models/merchant_profile_models.dart';

class MerchantProfileSetupScreen extends StatefulWidget {
  const MerchantProfileSetupScreen({super.key, this.initial});

  final MerchantProfileModel? initial;

  @override
  State<MerchantProfileSetupScreen> createState() =>
      _MerchantProfileSetupScreenState();
}

class _MerchantProfileSetupScreenState
    extends State<MerchantProfileSetupScreen> {
  static final RegExp _emailPattern = RegExp(
    r"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$",
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9][0-9\s\-\(\)]{7,17}$');
  static final RegExp _registrationPattern = RegExp(r'^[A-Z0-9\-\/]{4,30}$');

  final _displayNameCtrl = TextEditingController();
  final _requestNoteCtrl = TextEditingController();
  CountryModel? _selectedCountry;
  final _locationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _registrationNoCtrl = TextEditingController();
  final _businessAddressCtrl = TextEditingController();
  final _authorizedRepCtrl = TextEditingController();
  final _authorizedPositionCtrl = TextEditingController();

  MerchantType _type = MerchantType.individual;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _displayNameCtrl.text = initial.displayName;
      _requestNoteCtrl.text = initial.requestNote ?? '';
      _locationCtrl.text = initial.location ?? '';
      _emailCtrl.text = initial.email ?? '';
      _phoneCtrl.text = initial.phone ?? '';
      _businessNameCtrl.text = initial.businessName ?? '';
      _registrationNoCtrl.text = initial.registrationNumber ?? '';
      _businessAddressCtrl.text = initial.businessAddress ?? '';
      _authorizedRepCtrl.text = initial.authorizedRepName ?? '';
      _authorizedPositionCtrl.text = initial.authorizedRepPosition ?? '';
      _type = initial.type == MerchantType.business
          ? MerchantType.business
          : MerchantType.individual;
      // Pre-fill country picker from saved value
      if (initial.country != null && initial.country!.isNotEmpty) {
        _tryPrefillCountry(initial.country!);
      }
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _requestNoteCtrl.dispose();
    _locationCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _businessNameCtrl.dispose();
    _registrationNoCtrl.dispose();
    _businessAddressCtrl.dispose();
    _authorizedRepCtrl.dispose();
    _authorizedPositionCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryPrefillCountry(String value) async {
    try {
      final countries = await CountryService.I.getAll();
      if (!mounted) return;
      final q = value.trim().toLowerCase();
      final match = countries.firstWhere(
        (c) =>
            c.name.toLowerCase() == q ||
            c.code.toLowerCase() == q,
        orElse: () => CountryModel(name: value, code: '', flag: ''),
      );
      setState(() => _selectedCountry = match);
    } catch (_) {
      // Leave null â€” user can re-pick manually.
    }
  }

  Future<void> _submit() async {
    final error = _validateBeforeSubmit();
    if (error != null) {
      _showSnack(error);
      return;
    }

    final displayName = _displayNameCtrl.text.trim();

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final req = RequestMerchantProfileRequest(
        type: _type,
        displayName: displayName,
        requestNote: _requestNoteCtrl.text.trim(),
        country: _selectedCountry?.name,
        location: _locationCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        businessName: _businessNameCtrl.text.trim(),
        registrationNumber: _registrationNoCtrl.text.trim(),
        businessAddress: _businessAddressCtrl.text.trim(),
        authorizedRepName: _authorizedRepCtrl.text.trim(),
        authorizedRepPosition: _authorizedPositionCtrl.text.trim(),
      );
      await MerchantProfileCoreService.I.request(req);
      if (!mounted) return;
      await showVerificationResultModal(
        context,
        title: 'Request Submitted',
        message: 'Your merchant profile request was sent for approval.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      await showVerificationResultModal(
        context,
        title: 'Submit Failed',
        message: e.toString(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateBeforeSubmit() {
    final displayName = _displayNameCtrl.text.trim();
    final requestNote = _requestNoteCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final businessName = _businessNameCtrl.text.trim();
    final registrationNo = _registrationNoCtrl.text.trim().toUpperCase();
    final businessAddress = _businessAddressCtrl.text.trim();
    final authorizedRep = _authorizedRepCtrl.text.trim();
    final authorizedPosition = _authorizedPositionCtrl.text.trim();
    final business = _type == MerchantType.business;

    if (displayName.isEmpty) return 'Display name is required.';
    if (displayName.length < 2) return 'Display name must be at least 2 characters.';
    if (displayName.length > 80) return 'Display name must be at most 80 characters.';

    if (requestNote.isNotEmpty && requestNote.length > 500) {
      return 'Request note must be at most 500 characters.';
    }

    if (_selectedCountry == null) return 'Country is required.';
    if (location.isEmpty) return 'Location is required.';
    if (location.length < 2) return 'Location must be at least 2 characters.';

    if (email.isEmpty && phone.isEmpty) {
      return 'Provide at least one contact: email or phone.';
    }
    if (email.isNotEmpty && !_emailPattern.hasMatch(email)) {
      return 'Enter a valid contact email.';
    }
    if (phone.isNotEmpty && !_phonePattern.hasMatch(phone)) {
      return 'Enter a valid contact phone number.';
    }

    if (business) {
      if (businessName.isEmpty) return 'Business name is required.';
      if (businessName.length < 2) {
        return 'Business name must be at least 2 characters.';
      }
      if (registrationNo.isEmpty) return 'Registration number is required.';
      if (!_registrationPattern.hasMatch(registrationNo)) {
        return 'Registration number is invalid.';
      }
      if (businessAddress.isEmpty) return 'Business address is required.';
      if (authorizedRep.isEmpty) return 'Authorized representative is required.';
      if (authorizedPosition.isEmpty) {
        return 'Representative position is required.';
      }
    }

    return null;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickCountry() async {
    final c = AppColor.of(context);
    final picked = await showModalBottomSheet<CountryModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      builder: (_) => _CountryPickerSheet(c: c),
    );
    if (picked != null && mounted) {
      setState(() => _selectedCountry = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final business = _type == MerchantType.business;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'Merchant Profile Setup',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        children: [
          _Hero(c: c),
          const SizedBox(height: 18),
          _TypeSelector(
            c: c,
            type: _type,
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 14),
          _Field(
            c: c,
            controller: _displayNameCtrl,
            label: 'Display Name *',
            hint: 'Public merchant display name',
          ),
          const SizedBox(height: 10),
          _Field(
            c: c,
            controller: _requestNoteCtrl,
            label: 'Request Note',
            hint: 'Short note for reviewer',
            multiline: true,
          ),
          const SizedBox(height: 10),
          _CountryPickerField(
            c: c,
            selected: _selectedCountry,
            onTap: _pickCountry,
          ),
          const SizedBox(height: 10),
          _Field(
            c: c,
            controller: _locationCtrl,
            label: 'Location',
            hint: 'e.g. Manila',
          ),
          const SizedBox(height: 10),
          _Field(
            c: c,
            controller: _emailCtrl,
            label: 'Contact Email',
            hint: 'name@example.com',
          ),
          const SizedBox(height: 10),
          _Field(
            c: c,
            controller: _phoneCtrl,
            label: 'Contact Phone',
            hint: '+63...',
          ),
          if (business) ...[
            const SizedBox(height: 16),
            Text(
              'BUSINESS DETAILS',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            _Field(
              c: c,
              controller: _businessNameCtrl,
              label: 'Business Name',
              hint: 'Legal business name',
            ),
            const SizedBox(height: 10),
            _Field(
              c: c,
              controller: _registrationNoCtrl,
              label: 'Registration Number',
              hint: 'Company registration number',
            ),
            const SizedBox(height: 10),
            _Field(
              c: c,
              controller: _businessAddressCtrl,
              label: 'Business Address',
              hint: 'Office address',
              multiline: true,
            ),
            const SizedBox(height: 10),
            _Field(
              c: c,
              controller: _authorizedRepCtrl,
              label: 'Authorized Representative',
              hint: 'Representative name',
            ),
            const SizedBox(height: 10),
            _Field(
              c: c,
              controller: _authorizedPositionCtrl,
              label: 'Representative Position',
              hint: 'e.g. Operations Manager',
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: AppElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                disabledBackgroundColor: c.primary.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(c.onPrimary),
                      ),
                    )
                  : const Text(
                      'Submit Merchant Request',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// COUNTRY PICKER FIELD
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.border.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: c.border.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(Icons.public_outlined, color: c.textSecondary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: selected != null
                  ? Row(
                      children: [
                        if (selected!.flag.isNotEmpty) ...[
                          Text(
                            selected!.flag,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            selected!.name,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Country',
                      style: TextStyle(
                        color: c.textSecondary.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
            ),
            if (selected != null)
              Icon(Icons.check_circle_outline_rounded,
                  color: c.success, size: 17)
            else
              Icon(Icons.chevron_right_rounded,
                  color: c.textSecondary.withValues(alpha: 0.45), size: 18),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// COUNTRY PICKER SHEET
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.c});

  final AppColor c;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<CountryModel>? _all;
  List<CountryModel> _filtered = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final countries = await CountryService.I.getAll();
      if (!mounted) return;
      setState(() {
        _all = countries;
        _filtered = countries;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? (_all ?? [])
          : (_all ?? [])
              .where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.code.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Country',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.border.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: c.textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search countryâ€¦',
                  hintStyle: TextStyle(
                    color: c.textSecondary.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: c.surface,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: c.textSecondary, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide:
                        BorderSide(color: c.border.withValues(alpha: 0.25)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide:
                        BorderSide(color: c.border.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(color: c.primary, width: 1.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: c.border.withValues(alpha: 0.15)),
            Expanded(child: _buildList(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AppColor c) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: c.error, size: 32),
              const SizedBox(height: 12),
              Text(
                'Could not load countries',
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() => _error = null);
                  CountryService.I.clearCache();
                  _load();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_all == null) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(c.primary),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          'No countries found',
          style: TextStyle(color: c.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, indent: 56, color: c.border.withValues(alpha: 0.12)),
      itemBuilder: (_, i) {
        final country = _filtered[i];
        return InkWell(
          onTap: () => Navigator.of(context).pop(country),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              children: [
                Text(country.flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    country.name,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  country.code,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// HERO
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Hero extends StatelessWidget {
  const _Hero({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.storefront_outlined, color: c.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Step 1 of 2: Complete merchant profile request.',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TYPE SELECTOR
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.c,
    required this.type,
    required this.onChanged,
  });

  final AppColor c;
  final MerchantType type;
  final ValueChanged<MerchantType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merchant Type',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Individual'),
                selected: type == MerchantType.individual,
                onSelected: (_) => onChanged(MerchantType.individual),
              ),
              ChoiceChip(
                label: const Text('Business'),
                selected: type == MerchantType.business,
                onSelected: (_) => onChanged(MerchantType.business),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GENERIC FIELD
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Field extends StatelessWidget {
  const _Field({
    required this.c,
    required this.controller,
    required this.label,
    required this.hint,
    this.multiline = false,
  });

  final AppColor c;
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 4 : 1,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: c.border.withValues(alpha: 0.06),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: multiline ? 14 : 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withValues(alpha: 0.28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withValues(alpha: 0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
    );
  }
}


