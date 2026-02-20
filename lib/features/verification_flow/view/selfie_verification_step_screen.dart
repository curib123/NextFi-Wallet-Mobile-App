import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/modal/verification_result_modal.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';
import 'package:next_fi/services/verification/verification_core_service.dart';

class SelfieVerificationStepScreen extends StatefulWidget {
  const SelfieVerificationStepScreen({super.key});

  @override
  State<SelfieVerificationStepScreen> createState() =>
      _SelfieVerificationStepScreenState();
}

enum _ImageSlot { selfie, idFront, idBack }

class _SelfieVerificationStepScreenState
    extends State<SelfieVerificationStepScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _phoneCtrl = TextEditingController();

  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  File? _selfie;
  File? _idFront;
  File? _idBack;

  bool _picking = false;
  bool _submitting = false;
  bool _loadingPayment = false;

  String? _activePaymentAccountId;
  String? _activePaymentLabel;

  @override
  void initState() {
    super.initState();
    _loadActivePaymentAccount();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActivePaymentAccount() async {
    setState(() => _loadingPayment = true);
    try {
      final accounts = await PaymentMethodAndAccountsCoreService.I
          .listMyPaymentAccounts(activeOnly: true);
      if (!mounted) return;
      if (accounts.isEmpty) {
        setState(() {
          _activePaymentAccountId = null;
          _activePaymentLabel = null;
          _loadingPayment = false;
        });
        return;
      }

      final account = accounts.first;
      final method = account.paymentMethod?.name;
      final accountNo = account.accountNo?.trim();
      final preview = [
        account.accountName.trim(),
        if (method != null && method.trim().isNotEmpty) method.trim(),
        if (accountNo != null && accountNo.isNotEmpty) accountNo,
      ].join(' • ');

      setState(() {
        _activePaymentAccountId = account.id;
        _activePaymentLabel = preview;
        _loadingPayment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPayment = false);
    }
  }

  bool _isSupportedImagePath(String path) {
    final normalized = path.trim().toLowerCase();
    final dot = normalized.lastIndexOf('.');
    if (dot < 0) return false;
    final ext = normalized.substring(dot + 1);
    return _allowedExtensions.contains(ext);
  }

  void _assignSlot(_ImageSlot slot, File file) {
    setState(() {
      if (slot == _ImageSlot.selfie) {
        _selfie = file;
      } else if (slot == _ImageSlot.idFront) {
        _idFront = file;
      } else {
        _idBack = file;
      }
    });
  }

  Future<void> _pickForSlot(_ImageSlot slot, ImageSource source) async {
    if (_picking || _submitting) return;
    HapticFeedback.lightImpact();
    setState(() => _picking = true);
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
      if (!mounted) return;

      if (xFile == null) {
        setState(() => _picking = false);
        return;
      }

      if (!_isSupportedImagePath(xFile.path)) {
        setState(() => _picking = false);
        _showSnack('Unsupported image type. Use JPG, PNG, or WEBP.');
        return;
      }

      _assignSlot(slot, File(xFile.path));
      setState(() => _picking = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _picking = false);
      _showSnack('Failed to pick image: $e');
    }
  }

  void _clearSlot(_ImageSlot slot) {
    setState(() {
      if (slot == _ImageSlot.selfie) {
        _selfie = null;
      } else if (slot == _ImageSlot.idFront) {
        _idFront = null;
      } else {
        _idBack = null;
      }
    });
  }

  String? _validateBeforeSubmit() {
    if (_phoneCtrl.text.trim().isEmpty) return 'Phone number is required.';
    if (_selfie == null) return 'Selfie image is required.';
    if (_idFront == null) return 'Government ID front image is required.';
    if (_idBack == null) return 'Government ID back image is required.';

    if (!_isSupportedImagePath(_selfie!.path) ||
        !_isSupportedImagePath(_idFront!.path) ||
        !_isSupportedImagePath(_idBack!.path)) {
      return 'Only JPG, PNG, or WEBP images are supported.';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validateBeforeSubmit();
    if (error != null) {
      _showSnack(error);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    try {
      await VerificationCoreService.I.submit(
        phoneNumber: _phoneCtrl.text.trim(),
        selfie: _selfie!,
        governmentIdFront: _idFront!,
        governmentIdBack: _idBack!,
        paymentAccountId: _activePaymentAccountId,
      );
      if (!mounted) return;

      await showVerificationResultModal(
        context,
        title: 'Verification Submitted',
        message:
            'Your documents were submitted successfully. We are now reviewing your verification.',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      await showVerificationResultModal(
        context,
        title: 'Submission Failed',
        message: e.toString(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'Identity Verification',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          _HeroCard(c: c),
          const SizedBox(height: 14),
          _PhoneField(controller: _phoneCtrl, c: c),
          const SizedBox(height: 14),
          _UploadCard(
            c: c,
            title: 'Selfie',
            subtitle: 'Clear face photo in good lighting',
            file: _selfie,
            busy: _picking || _submitting,
            onCamera: () => _pickForSlot(_ImageSlot.selfie, ImageSource.camera),
            onGallery: () =>
                _pickForSlot(_ImageSlot.selfie, ImageSource.gallery),
            onClear: () => _clearSlot(_ImageSlot.selfie),
          ),
          const SizedBox(height: 12),
          _UploadCard(
            c: c,
            title: 'Government ID Front',
            subtitle: 'Capture the front side of your ID',
            file: _idFront,
            busy: _picking || _submitting,
            onCamera: () =>
                _pickForSlot(_ImageSlot.idFront, ImageSource.camera),
            onGallery: () =>
                _pickForSlot(_ImageSlot.idFront, ImageSource.gallery),
            onClear: () => _clearSlot(_ImageSlot.idFront),
          ),
          const SizedBox(height: 12),
          _UploadCard(
            c: c,
            title: 'Government ID Back',
            subtitle: 'Capture the back side of your ID',
            file: _idBack,
            busy: _picking || _submitting,
            onCamera: () => _pickForSlot(_ImageSlot.idBack, ImageSource.camera),
            onGallery: () =>
                _pickForSlot(_ImageSlot.idBack, ImageSource.gallery),
            onClear: () => _clearSlot(_ImageSlot.idBack),
          ),
          const SizedBox(height: 12),
          _PaymentAccountHint(
            c: c,
            loading: _loadingPayment,
            activePaymentLabel: _activePaymentLabel,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: AppElevatedButton(
              onPressed: _submitting || _picking ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: c.primary.withOpacity(0.45),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Submitting...',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : const Text(
                      'Submit Verification',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.c});

  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: c.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Step 3 of 3',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Submit your phone number, selfie, and both sides of your government ID.',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.c});

  final TextEditingController controller;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: 'Phone Number *',
        hintText: 'e.g. +639171234567',
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.primary, width: 1.4),
        ),
        prefixIcon: Icon(Icons.phone_outlined, color: c.textSecondary),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.c,
    required this.title,
    required this.subtitle,
    required this.file,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
    required this.onClear,
  });

  final AppColor c;
  final String title;
  final String subtitle;
  final File? file;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (hasFile)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Added',
                    style: TextStyle(
                      color: c.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 164,
              color: hasFile ? Colors.black : c.border.withOpacity(0.08),
              child: hasFile
                  ? Image.file(file!, fit: BoxFit.cover)
                  : Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: c.textSecondary.withOpacity(0.45),
                        size: 28,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: AppOutlinedButton(
                    onPressed: busy ? null : onCamera,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Camera'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: AppOutlinedButton(
                    onPressed: busy ? null : onGallery,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Gallery'),
                  ),
                ),
              ),
              if (hasFile) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: AppOutlinedButton(
                    onPressed: busy ? null : onClear,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.error,
                      side: BorderSide(color: c.error.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentAccountHint extends StatelessWidget {
  const _PaymentAccountHint({
    required this.c,
    required this.loading,
    required this.activePaymentLabel,
  });

  final AppColor c;
  final bool loading;
  final String? activePaymentLabel;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Text(
        'Checking active payment account...',
        style: TextStyle(color: c.textSecondary, fontSize: 12.5),
      );
    }

    if (activePaymentLabel == null) {
      return Text(
        'No active payment account selected. Submission will still continue.',
        style: TextStyle(color: c.textSecondary, fontSize: 12.5),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: c.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Linked payment account: $activePaymentLabel',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
