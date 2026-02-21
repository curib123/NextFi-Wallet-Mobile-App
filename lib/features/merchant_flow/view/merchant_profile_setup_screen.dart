import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/modal/verification_result_modal.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_dtos.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';

class MerchantProfileSetupScreen extends StatefulWidget {
  const MerchantProfileSetupScreen({super.key, this.initial});

  final MerchantProfileModel? initial;

  @override
  State<MerchantProfileSetupScreen> createState() =>
      _MerchantProfileSetupScreenState();
}

class _MerchantProfileSetupScreenState extends State<MerchantProfileSetupScreen> {
  final _displayNameCtrl = TextEditingController();
  final _requestNoteCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
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
      _countryCtrl.text = initial.country ?? '';
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
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _requestNoteCtrl.dispose();
    _countryCtrl.dispose();
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

  Future<void> _submit() async {
    final displayName = _displayNameCtrl.text.trim();
    if (displayName.isEmpty) {
      _showSnack('Display name is required.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final req = RequestMerchantProfileRequest(
        type: _type,
        displayName: displayName,
        requestNote: _requestNoteCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
          _Field(c: c, controller: _countryCtrl, label: 'Country', hint: 'e.g. PH'),
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
                foregroundColor: Colors.white,
                disabledBackgroundColor: c.primary.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.storefront_outlined, color: c.primary, size: 22),
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
        border: Border.all(color: c.border.withOpacity(0.22)),
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
        fillColor: c.border.withOpacity(0.06),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: multiline ? 14 : 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
    );
  }
}
