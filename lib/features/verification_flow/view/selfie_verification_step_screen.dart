import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/modal/verification_result_modal.dart';
import 'package:next_fi/services/countries/country_service.dart';
import 'package:next_fi/services/countries/models/country_model.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';
import 'package:next_fi/services/verification/models/verification_models.dart';
import 'package:next_fi/services/verification/verification_core_service.dart';

class SelfieVerificationStepScreen extends StatefulWidget {
  const SelfieVerificationStepScreen({super.key});

  @override
  State<SelfieVerificationStepScreen> createState() =>
      _SelfieVerificationStepScreenState();
}

enum _ImageSlot { selfie, idFront, idBack }

class _ImageMetrics {
  const _ImageMetrics({
    required this.width,
    required this.height,
    required this.sharpness,
  });

  final double width;
  final double height;
  final double sharpness;
}

class _SelfieVerificationStepScreenState
    extends State<SelfieVerificationStepScreen> {
  static const int _maxAutoRetryPerCapture = 1;
  static const double _selfieMinSharpness = 45;
  static const double _idMinSharpness = 60;
  static const double _selfieMinFaceCoverage = 0.10;
  static const double _selfieMinIdCoverage = 0.04;
  static const double _idMinObjectCoverage = 0.16;

  final ImagePicker _picker = ImagePicker();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  final ObjectDetector _objectDetector = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  // ── Contact ──────────────────────────────────────────────
  final TextEditingController _phoneCtrl = TextEditingController();

  // ── Identity ─────────────────────────────────────────────
  final TextEditingController _fullLegalNameCtrl = TextEditingController();
  final TextEditingController _nationalityCtrl = TextEditingController();
  CountryModel? _selectedCountryOfResidence;
  DateTime? _dateOfBirth;

  // ── Address ──────────────────────────────────────────────
  final TextEditingController _addressLine1Ctrl = TextEditingController();
  final TextEditingController _addressLine2Ctrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _stateOrProvinceCtrl = TextEditingController();
  final TextEditingController _postalCodeCtrl = TextEditingController();
  CountryModel? _selectedIssuingCountry;

  // ── Government ID ─────────────────────────────────────────
  GovernmentIdType? _governmentIdType;
  final TextEditingController _governmentIdNumberCtrl = TextEditingController();
  DateTime? _governmentIdExpiry;

  // ── Files ────────────────────────────────────────────────
  File? _selfie;
  File? _idFront;
  File? _idBack;

  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  bool _picking = false;
  bool _submitting = false;
  bool _loadingPayment = false;
  bool _loadingVerification = false;

  String? _activePaymentAccountId;
  String? _activePaymentLabel;
  VerificationModel? _currentVerification;

  @override
  void initState() {
    super.initState();
    _loadActivePaymentAccount();
    _loadCurrentVerification();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _objectDetector.close();
    _textRecognizer.close();
    _phoneCtrl.dispose();
    _fullLegalNameCtrl.dispose();
    _nationalityCtrl.dispose();
    _addressLine1Ctrl.dispose();
    _addressLine2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateOrProvinceCtrl.dispose();
    _postalCodeCtrl.dispose();
    _governmentIdNumberCtrl.dispose();
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

  Future<void> _loadCurrentVerification() async {
    setState(() => _loadingVerification = true);
    try {
      final verification = await VerificationCoreService.I.getMe();
      if (!mounted) return;
      setState(() {
        _currentVerification = verification;
        _loadingVerification = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingVerification = false);
    }
  }

  bool _isSupportedImagePath(String path) {
    final normalized = path.trim().toLowerCase();
    final dot = normalized.lastIndexOf('.');
    if (dot < 0) return false;
    return _allowedExtensions.contains(normalized.substring(dot + 1));
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

  Future<_ImageMetrics?> _analyzeImageMetrics(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final working = decoded.width > 1400
        ? img.copyResize(decoded, width: 1400)
        : decoded;

    final width = working.width;
    final height = working.height;
    if (width < 120 || height < 120) return null;

    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < height - 1; y += 2) {
      for (int x = 1; x < width - 1; x += 2) {
        final c = working.getPixel(x, y);
        final l = (0.299 * c.r) + (0.587 * c.g) + (0.114 * c.b);

        final lN = _luma(working.getPixel(x, y - 1));
        final lS = _luma(working.getPixel(x, y + 1));
        final lW = _luma(working.getPixel(x - 1, y));
        final lE = _luma(working.getPixel(x + 1, y));

        final lap = (lN + lS + lW + lE - (4 * l)).abs();
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return null;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return _ImageMetrics(
      width: width.toDouble(),
      height: height.toDouble(),
      sharpness: variance,
    );
  }

  double _luma(img.Pixel pixel) {
    return (0.299 * pixel.r) + (0.587 * pixel.g) + (0.114 * pixel.b);
  }

  Future<String> _applyMirrorIfNeeded(_ImageSlot slot, String imagePath) async {
    if (slot != _ImageSlot.selfie) return imagePath;

    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return imagePath;

      final mirrored = img.flipHorizontal(decoded);
      final lower = imagePath.toLowerCase();
      final encoded = lower.endsWith('.png')
          ? img.encodePng(mirrored)
          : img.encodeJpg(mirrored, quality: 92);

      await file.writeAsBytes(encoded, flush: true);
      return imagePath;
    } catch (_) {
      return imagePath;
    }
  }

  Future<String?> _runMlKitValidation(_ImageSlot slot, String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final metrics = await _analyzeImageMetrics(imagePath);
    if (metrics == null) {
      return 'Unable to analyze image quality. Retake in better lighting.';
    }
    final minSharpness = slot == _ImageSlot.selfie
        ? _selfieMinSharpness
        : _idMinSharpness;
    if (metrics.sharpness < minSharpness) {
      return 'Image is too blurry. Keep steady and retake a clearer photo.';
    }

    final objects = await _objectDetector.processImage(inputImage);
    final imageArea = metrics.width * metrics.height;

    if (slot == _ImageSlot.selfie) {
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        return 'No face detected. Retake the selfie with your face clearly visible.';
      }
      if (faces.length > 1) {
        return 'Multiple faces detected. Capture only your face with your ID.';
      }
      final face = faces.first;
      final faceArea = face.boundingBox.width * face.boundingBox.height;
      final imageArea = metrics.width * metrics.height;
      final coverage = faceArea / imageArea;
      if (coverage < _selfieMinFaceCoverage) {
        return 'Move closer to camera. Your face must be clearly present.';
      }

      final hasIdInSelfie = objects.any((obj) {
        final box = obj.boundingBox;
        final objCoverage = (box.width * box.height) / imageArea;
        final ratio = box.width / box.height;
        return objCoverage >= _selfieMinIdCoverage &&
            ratio >= 1.2 &&
            ratio <= 2.3;
      });
      if (!hasIdInSelfie) {
        return 'Selfie with ID is invalid. Hold your ID beside your face and keep the full card visible.';
      }
      return null;
    }

    final hasCardLikeObject = objects.any((obj) {
      final box = obj.boundingBox;
      final coverage = (box.width * box.height) / imageArea;
      final ratio = box.width / box.height;
      return coverage >= _idMinObjectCoverage && ratio >= 1.2 && ratio <= 2.3;
    });
    if (!hasCardLikeObject) {
      return 'ID card not detected. Place the full ID inside frame and retake.';
    }

    final recognized = await _textRecognizer.processImage(inputImage);
    final compactText = recognized.text.replaceAll(RegExp(r'\s+'), '').trim();
    if (compactText.length < 18) {
      return 'ID looks unclear. Retake with better lighting and keep all text readable.';
    }

    return null;
  }

  Future<void> _pickForSlot(_ImageSlot slot, {int attempt = 0}) async {
    if (_picking || _submitting) return;
    HapticFeedback.lightImpact();
    setState(() => _picking = true);
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: slot == _ImageSlot.selfie
            ? CameraDevice.front
            : CameraDevice.rear,
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

      final processedPath = await _applyMirrorIfNeeded(slot, xFile.path);
      final mlKitError = await _runMlKitValidation(slot, processedPath);
      if (!mounted) return;
      if (mlKitError != null) {
        setState(() => _picking = false);
        if (attempt < _maxAutoRetryPerCapture) {
          _showSnack('$mlKitError Auto-retake started...');
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          await _pickForSlot(slot, attempt: attempt + 1);
          return;
        }
        _showSnack(mlKitError);
        return;
      }

      _assignSlot(slot, File(processedPath));
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

  Future<void> _pickDate({
    required DateTime? initial,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) {
        final c = AppColor.of(ctx);
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(
              ctx,
            ).colorScheme.copyWith(primary: c.primary, surface: c.surface),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPicked(picked);
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
      final verification =
          _currentVerification ?? await VerificationCoreService.I.getMe();
      if (verification.status == TrustStatus.ready) {
        throw Exception('Your account is already verified.');
      }
      if (verification.status == TrustStatus.suspended) {
        throw Exception(
          'Your verification is suspended. Please contact support.',
        );
      }

      final hasPreviousSubmission = verification.submittedAt != null;

      if (hasPreviousSubmission) {
        await VerificationCoreService.I.resubmit(
          phoneNumber: _phoneCtrl.text.trim(),
          selfie: _selfie!,
          governmentIdFront: _idFront!,
          governmentIdBack: _idBack!,
          paymentAccountId: _activePaymentAccountId,
          fullLegalName: _fullLegalNameCtrl.text.trim().isEmpty
              ? null
              : _fullLegalNameCtrl.text.trim(),
          dateOfBirth: _dateOfBirth,
          nationality: _nationalityCtrl.text.trim().isEmpty
              ? null
              : _nationalityCtrl.text.trim(),
          countryOfResidence: _selectedCountryOfResidence?.name,
          addressLine1: _addressLine1Ctrl.text.trim().isEmpty
              ? null
              : _addressLine1Ctrl.text.trim(),
          addressLine2: _addressLine2Ctrl.text.trim().isEmpty
              ? null
              : _addressLine2Ctrl.text.trim(),
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          stateOrProvince: _stateOrProvinceCtrl.text.trim().isEmpty
              ? null
              : _stateOrProvinceCtrl.text.trim(),
          postalCode: _postalCodeCtrl.text.trim().isEmpty
              ? null
              : _postalCodeCtrl.text.trim(),
          issuingCountry: _selectedIssuingCountry?.name,
          governmentIdType: _governmentIdType,
          governmentIdNumber: _governmentIdNumberCtrl.text.trim().isEmpty
              ? null
              : _governmentIdNumberCtrl.text.trim(),
          governmentIdExpiry: _governmentIdExpiry,
        );
      } else {
        await VerificationCoreService.I.submit(
          phoneNumber: _phoneCtrl.text.trim(),
          selfie: _selfie!,
          governmentIdFront: _idFront!,
          governmentIdBack: _idBack!,
          paymentAccountId: _activePaymentAccountId,
          // Identity
          fullLegalName: _fullLegalNameCtrl.text.trim().isEmpty
              ? null
              : _fullLegalNameCtrl.text.trim(),
          dateOfBirth: _dateOfBirth,
          nationality: _nationalityCtrl.text.trim().isEmpty
              ? null
              : _nationalityCtrl.text.trim(),
          countryOfResidence: _selectedCountryOfResidence?.name,
          // Address
          addressLine1: _addressLine1Ctrl.text.trim().isEmpty
              ? null
              : _addressLine1Ctrl.text.trim(),
          addressLine2: _addressLine2Ctrl.text.trim().isEmpty
              ? null
              : _addressLine2Ctrl.text.trim(),
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          stateOrProvince: _stateOrProvinceCtrl.text.trim().isEmpty
              ? null
              : _stateOrProvinceCtrl.text.trim(),
          postalCode: _postalCodeCtrl.text.trim().isEmpty
              ? null
              : _postalCodeCtrl.text.trim(),
          issuingCountry: _selectedIssuingCountry?.name,
          // Government ID
          governmentIdType: _governmentIdType,
          governmentIdNumber: _governmentIdNumberCtrl.text.trim().isEmpty
              ? null
              : _governmentIdNumberCtrl.text.trim(),
          governmentIdExpiry: _governmentIdExpiry,
        );
      }

      await _loadCurrentVerification();
      if (!mounted) return;

      await showVerificationResultModal(
        context,
        title: hasPreviousSubmission
            ? 'Verification Re-submitted'
            : 'Verification Submitted',
        message: hasPreviousSubmission
            ? 'Your updated documents were re-submitted successfully. We are reviewing your corrections.'
            : 'Your documents were submitted successfully. We are now reviewing your verification.',
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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        children: [
          if (_loadingVerification)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: c.primary,
                backgroundColor: c.border,
              ),
            ),
          if (_currentVerification?.resubmissionGuide != null) ...[
            _ResubmissionGuideCard(
              c: c,
              guide: _currentVerification!.resubmissionGuide!,
            ),
            const SizedBox(height: 12),
          ],
          if ((_currentVerification?.reviewLogs ?? const []).isNotEmpty) ...[
            _ReviewHistoryCard(c: c, logs: _currentVerification!.reviewLogs),
            const SizedBox(height: 12),
          ],
          _HeroCard(c: c),
          const SizedBox(height: 20),

          // ── Section: Contact ──────────────────────────────
          _SectionHeader(c: c, label: 'Contact'),
          const SizedBox(height: 10),
          _AppTextField(
            controller: _phoneCtrl,
            c: c,
            labelText: 'Phone Number *',
            hintText: 'e.g. +639171234567',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 20),

          // ── Section: Personal Information ─────────────────
          _SectionHeader(c: c, label: 'Personal Information'),
          const SizedBox(height: 10),
          _AppTextField(
            controller: _fullLegalNameCtrl,
            c: c,
            labelText: 'Full Legal Name',
            hintText: 'As printed on your ID',
            prefixIcon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          _DatePickerField(
            c: c,
            label: 'Date of Birth',
            value: _dateOfBirth,
            onTap: () => _pickDate(
              initial: _dateOfBirth,
              firstDate: DateTime(1900),
              lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
              onPicked: (d) => setState(() => _dateOfBirth = d),
            ),
          ),
          const SizedBox(height: 10),
          _AppTextField(
            controller: _nationalityCtrl,
            c: c,
            labelText: 'Nationality',
            hintText: 'e.g. Filipino',
            prefixIcon: Icons.flag_outlined,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          _CountryPickerField(
            c: c,
            label: 'Country of Residence',
            selected: _selectedCountryOfResidence,
            onTap: () async {
              final picked = await showModalBottomSheet<CountryModel>(
                context: context,
                isScrollControlled: true,
                backgroundColor: c.surface,
                builder: (_) =>
                    _CountryPickerSheet(c: c, title: 'Country of Residence'),
              );
              if (picked != null && mounted) {
                setState(() {
                  _selectedCountryOfResidence = picked;
                  // Auto-default issuing country if not explicitly chosen yet
                  _selectedIssuingCountry ??= picked;
                });
              }
            },
          ),

          const SizedBox(height: 20),

          // ── Section: Address ──────────────────────────────
          _SectionHeader(c: c, label: 'Address'),
          const SizedBox(height: 10),
          _AppTextField(
            controller: _addressLine1Ctrl,
            c: c,
            labelText: 'Address Line 1',
            hintText: 'Street, building, house no.',
            prefixIcon: Icons.home_outlined,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 10),
          _AppTextField(
            controller: _addressLine2Ctrl,
            c: c,
            labelText: 'Address Line 2',
            hintText: 'Barangay, subdivision, etc. (optional)',
            prefixIcon: Icons.home_work_outlined,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AppTextField(
                  controller: _cityCtrl,
                  c: c,
                  labelText: 'City',
                  hintText: 'e.g. Cebu City',
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AppTextField(
                  controller: _postalCodeCtrl,
                  c: c,
                  labelText: 'Postal Code',
                  hintText: 'e.g. 6000',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AppTextField(
            controller: _stateOrProvinceCtrl,
            c: c,
            labelText: 'State / Province',
            hintText: 'e.g. Cebu',
            prefixIcon: Icons.map_outlined,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          _CountryPickerField(
            c: c,
            label: 'Issuing Country',
            selected: _selectedIssuingCountry,
            onTap: () async {
              final picked = await showModalBottomSheet<CountryModel>(
                context: context,
                isScrollControlled: true,
                backgroundColor: c.surface,
                builder: (_) =>
                    _CountryPickerSheet(c: c, title: 'Issuing Country'),
              );
              if (picked != null && mounted) {
                setState(() => _selectedIssuingCountry = picked);
              }
            },
          ),

          const SizedBox(height: 20),

          // ── Section: Government ID ────────────────────────
          _SectionHeader(c: c, label: 'Government ID'),
          const SizedBox(height: 10),
          _GovernmentIdTypeDropdown(
            c: c,
            value: _governmentIdType,
            onChanged: (v) => setState(() => _governmentIdType = v),
          ),
          const SizedBox(height: 10),
          _AppTextField(
            controller: _governmentIdNumberCtrl,
            c: c,
            labelText: 'ID Number',
            hintText: 'As printed on your ID',
            prefixIcon: Icons.numbers_rounded,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          _DatePickerField(
            c: c,
            label: 'ID Expiry Date',
            value: _governmentIdExpiry,
            onTap: () => _pickDate(
              initial: _governmentIdExpiry,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
              onPicked: (d) => setState(() => _governmentIdExpiry = d),
            ),
          ),

          const SizedBox(height: 20),

          // ── Section: Documents ────────────────────────────
          _SectionHeader(c: c, label: 'Documents'),
          const SizedBox(height: 10),
          _UploadCard(
            c: c,
            title: 'Government ID — Front',
            subtitle: 'Capture the front side of your ID',
            icon: Icons.credit_card_outlined,
            file: _idFront,
            busy: _picking || _submitting,
            onCamera: () => _pickForSlot(_ImageSlot.idFront),
            onClear: () => _clearSlot(_ImageSlot.idFront),
          ),
          const SizedBox(height: 10),
          _UploadCard(
            c: c,
            title: 'Government ID — Back',
            subtitle: 'Capture the back side of your ID',
            icon: Icons.flip_outlined,
            file: _idBack,
            busy: _picking || _submitting,
            onCamera: () => _pickForSlot(_ImageSlot.idBack),
            onClear: () => _clearSlot(_ImageSlot.idBack),
          ),
          const SizedBox(height: 10),
          _UploadCard(
            c: c,
            title: 'Selfie with ID',
            subtitle:
                'Take a photo of yourself clearly holding your ID next to your face',
            icon: Icons.face_retouching_natural_outlined,
            file: _selfie,
            busy: _picking || _submitting,
            onCamera: () => _pickForSlot(_ImageSlot.selfie),
            onClear: () => _clearSlot(_ImageSlot.selfie),
          ),

          const SizedBox(height: 12),

          _PaymentAccountHint(
            c: c,
            loading: _loadingPayment,
            activePaymentLabel: _activePaymentLabel,
          ),

          const SizedBox(height: 20),

          // ── Submit ────────────────────────────────────────
          SizedBox(
            height: 52,
            child: AppElevatedButton(
              onPressed: _submitting || _picking ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                disabledBackgroundColor: c.primary.withValues(alpha: 0.45),
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
                            valueColor: AlwaysStoppedAnimation(c.onPrimary),
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

// ─────────────────────────────────────────────────────────────────────────────
// HERO CARD
// ─────────────────────────────────────────────────────────────────────────────

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
        border: Border.all(color: c.border.withValues(alpha: 0.22)),
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
            'Fill in your identity details and upload your documents.',
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

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.c, required this.label});

  final AppColor c;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 0),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GENERIC TEXT FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.c,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final AppColor c;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.primary, width: 1.4),
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: c.textSecondary, size: 20)
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE PICKER FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.c,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final AppColor c;
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayText = value != null
        ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: c.border.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: c.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayText ?? label,
                style: TextStyle(
                  color: displayText != null ? c.textPrimary : c.textSecondary,
                  fontSize: 14.5,
                  fontWeight: displayText != null
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ),
            if (value != null)
              Icon(
                Icons.check_circle_outline_rounded,
                color: c.success,
                size: 18,
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: c.textSecondary.withValues(alpha: 0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOVERNMENT ID TYPE DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────

class _GovernmentIdTypeDropdown extends StatelessWidget {
  const _GovernmentIdTypeDropdown({
    required this.c,
    required this.value,
    required this.onChanged,
  });

  final AppColor c;
  final GovernmentIdType? value;
  final ValueChanged<GovernmentIdType?> onChanged;

  static const _labels = {
    GovernmentIdType.passport: 'Passport',
    GovernmentIdType.driversLicense: "Driver's License",
    GovernmentIdType.nationalId: 'National ID',
    GovernmentIdType.other: 'Other',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<GovernmentIdType>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'ID Type',
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.primary, width: 1.4),
        ),
        prefixIcon: Icon(
          Icons.badge_outlined,
          color: c.textSecondary,
          size: 20,
        ),
      ),
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: c.surface,
      items: GovernmentIdType.values
          .map(
            (t) =>
                DropdownMenuItem(value: t, child: Text(_labels[t] ?? t.name)),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UPLOAD CARD
// ─────────────────────────────────────────────────────────────────────────────

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.c,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.file,
    required this.busy,
    required this.onCamera,
    required this.onClear,
  });

  final AppColor c;
  final String title;
  final String subtitle;
  final IconData icon;
  final File? file;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFile
              ? c.success.withValues(alpha: 0.3)
              : c.border.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hasFile
                      ? c.success.withValues(alpha: 0.1)
                      : c.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  hasFile ? Icons.check_rounded : icon,
                  color: hasFile ? c.success : c.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textSecondary, fontSize: 11.5),
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
                    color: c.success.withValues(alpha: 0.12),
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
          SizedBox(
            width: double.infinity,
            height: 148,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasFile
                  ? Image.file(
                      file!,
                      width: double.infinity,
                      height: 148,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: c.border.withValues(alpha: 0.08),
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: c.textSecondary.withValues(alpha: 0.45),
                          size: 28,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: AppOutlinedButton(
                    onPressed: busy ? null : onCamera,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 14,
                          color: c.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        const Flexible(
                          child: Text(
                            'Camera',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (hasFile) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  height: 38,
                  child: AppOutlinedButton(
                    onPressed: busy ? null : onClear,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.error,
                      side: BorderSide(color: c.error.withValues(alpha: 0.3)),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, size: 17),
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

// ─────────────────────────────────────────────────────────────────────────────
// COUNTRY PICKER FIELD  (tap-to-open, matches _DatePickerField style)
// ─────────────────────────────────────────────────────────────────────────────

class _CountryPickerField extends StatelessWidget {
  const _CountryPickerField({
    required this.c,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppColor c;
  final String label;
  final CountryModel? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: c.border.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: c.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: selected != null
                  ? Row(
                      children: [
                        Text(
                          selected!.flag,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selected!.name,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: TextStyle(color: c.textSecondary, fontSize: 14.5),
                    ),
            ),
            if (selected != null)
              Icon(
                Icons.check_circle_outline_rounded,
                color: c.success,
                size: 18,
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: c.textSecondary.withValues(alpha: 0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTRY PICKER SHEET  (searchable modal bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.c, this.title = 'Select Country'});

  final AppColor c;
  final String title;

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
                .where(
                  (c) =>
                      c.name.toLowerCase().contains(q) ||
                      c.code.toLowerCase().contains(q),
                )
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
            // ── Drag handle ──────────────────────────────────
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

            // ── Title ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    widget.title,
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
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Search ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: c.textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search country…',
                  hintStyle: TextStyle(
                    color: c.textSecondary.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: c.surface,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: c.textSecondary,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(
                      color: c.border.withValues(alpha: 0.25),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(
                      color: c.border.withValues(alpha: 0.25),
                    ),
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

            // ── List ─────────────────────────────────────────
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
                  fontSize: 14,
                ),
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
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 56,
        color: c.border.withValues(alpha: 0.12),
      ),
      itemBuilder: (_, i) {
        final country = _filtered[i];
        return InkWell(
          onTap: () => Navigator.of(context).pop(country),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
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

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT ACCOUNT HINT
// ─────────────────────────────────────────────────────────────────────────────

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
        color: c.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withValues(alpha: 0.18)),
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

class _ResubmissionGuideCard extends StatelessWidget {
  const _ResubmissionGuideCard({required this.c, required this.guide});

  final AppColor c;
  final VerificationResubmissionGuide guide;

  @override
  Widget build(BuildContext context) {
    final reason = (guide.reason ?? '').trim();
    final fields = guide.fields;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.warning.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: c.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'Resubmission Guidance',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reason,
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
          ],
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: fields
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewHistoryCard extends StatelessWidget {
  const _ReviewHistoryCard({required this.c, required this.logs});

  final AppColor c;
  final List<VerificationReviewLog> logs;

  static const int _maxItems = 4;

  @override
  Widget build(BuildContext context) {
    final visibleLogs = [...logs]
      ..sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
    final items = visibleLogs.take(_maxItems).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review History',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            _ReviewHistoryItem(c: c, log: items[i]),
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  color: c.border.withValues(alpha: 0.2),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReviewHistoryItem extends StatelessWidget {
  const _ReviewHistoryItem({required this.c, required this.log});

  final AppColor c;
  final VerificationReviewLog log;

  @override
  Widget build(BuildContext context) {
    final action = _formatAction(log.action);
    final when = _formatDate(log.createdAt);
    final reason = (log.reason ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                action,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (when != null)
              Text(
                when,
                style: TextStyle(color: c.textSecondary, fontSize: 11.5),
              ),
          ],
        ),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(reason, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ],
        if (log.resubmissionFields.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: log.resubmissionFields
                .map(
                  (field) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      field,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  String _formatAction(String? rawAction) {
    final text = (rawAction ?? '').trim();
    if (text.isEmpty) return 'Review update';
    return text
        .toLowerCase()
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String? _formatDate(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    final month = _monthName(local.month);
    final day = local.day.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month $day, $year • $hour:$minute';
  }

  String _monthName(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      default:
        return 'Dec';
    }
  }
}
