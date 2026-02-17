import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/modal/verification_result_modal.dart';
import 'package:next_fi/services/verification/verification_core_service.dart';

class SelfieVerificationStepScreen extends StatefulWidget {
  const SelfieVerificationStepScreen({super.key});

  @override
  State<SelfieVerificationStepScreen> createState() =>
      _SelfieVerificationStepScreenState();
}

class _SelfieVerificationStepScreenState
    extends State<SelfieVerificationStepScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  static const Set<String> _allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  File? _selectedSelfie;
  bool _picking    = false;
  bool _submitting = false;

  late final AnimationController _previewCtrl;
  late final Animation<double> _previewFade;
  late final Animation<double> _previewScale;

  @override
  void initState() {
    super.initState();
    _previewCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _previewFade  = CurvedAnimation(parent: _previewCtrl, curve: Curves.easeOut);
    _previewScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _previewCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _previewCtrl.dispose();
    super.dispose();
  }

  bool _isSupportedImagePath(String path) {
    final normalized = path.trim().toLowerCase();
    final dot = normalized.lastIndexOf('.');
    if (dot < 0) return false;
    final ext = normalized.substring(dot + 1);
    return _allowedExtensions.contains(ext);
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking || _submitting) return;
    HapticFeedback.lightImpact();
    setState(() => _picking = true);

    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
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
      _previewCtrl.forward(from: 0);
      setState(() {
        _selectedSelfie = File(xFile.path);
        _picking        = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _picking = false);
      _showSnack('Failed to select image: $e');
    }
  }

  Future<void> _submit() async {
    final file = _selectedSelfie;
    if (file == null) {
      _showSnack('Select a selfie first.');
      return;
    }
    if (!_isSupportedImagePath(file.path)) {
      _showSnack('Unsupported image type. Use JPG, PNG, or WEBP.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    try {
      await VerificationCoreService.I.submit(selfie: file);
      if (!mounted) return;

      await showVerificationResultModal(
        context,
        title: 'Verification Submitted',
        message: 'Your selfie was submitted and is now under review.',
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
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c       = AppColor.of(context);
    final hasFile = _selectedSelfie != null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: _buildAppBar(c),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [

          // ── Preview / Placeholder ──────────────────────────────────
          _PreviewArea(
            file: _selectedSelfie,
            picking: _picking,
            fadeAnim: _previewFade,
            scaleAnim: _previewScale,
            c: c,
          ),

          const SizedBox(height: 16),

          // ── Pick source buttons (shown when no image yet) ──────────
          if (!hasFile) ...[
            _PickRow(
              picking: _picking,
              submitting: _submitting,
              onCamera:  () => _pick(ImageSource.camera),
              onGallery: () => _pick(ImageSource.gallery),
              c: c,
            ),
            const SizedBox(height: 16),
            _RequirementsCard(c: c),
            const SizedBox(height: 16),
          ],

          // ── Replace row (shown when image already selected) ────────
          if (hasFile) ...[
            _ReplaceRow(
              picking: _picking,
              submitting: _submitting,
              onCamera:  () => _pick(ImageSource.camera),
              onGallery: () => _pick(ImageSource.gallery),
              c: c,
            ),
            const SizedBox(height: 16),
          ],

          // ── Submit button ──────────────────────────────────────────
          _SubmitButton(
            submitting: _submitting,
            picking: _picking,
            hasFile: hasFile,
            onPressed: _submit,
            c: c,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor c) {
    return AppBar(
      backgroundColor: c.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Text(
        'Selfie Verification',
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREVIEW AREA
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewArea extends StatelessWidget {
  const _PreviewArea({
    required this.file,
    required this.picking,
    required this.fadeAnim,
    required this.scaleAnim,
    required this.c,
  });

  final File? file;
  final bool picking;
  final Animation<double> fadeAnim;
  final Animation<double> scaleAnim;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      height: file != null ? 300 : 210,
      decoration: BoxDecoration(
        color: file != null ? Colors.black : c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: file != null
              ? Colors.transparent
              : c.border.withOpacity(0.22),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: file != null ? _buildImagePreview() : _buildEmptyState(),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Photo
        FadeTransition(
          opacity: fadeAnim,
          child: ScaleTransition(
            scale: scaleAnim,
            child: Image.file(file!, fit: BoxFit.cover, width: double.infinity),
          ),
        ),
        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // "Selfie selected" badge
        Positioned(
          bottom: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text(
                  'Selfie selected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(picking),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                  color: c.primary.withOpacity(0.18), width: 1.5),
            ),
            child: Icon(
              picking
                  ? Icons.hourglass_top_rounded
                  : Icons.face_retouching_natural_rounded,
              color: c.primary,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          picking ? 'Opening picker…' : 'No selfie selected',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Use the buttons below to add a photo',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PICK ROW  (large — camera | gallery)
// ─────────────────────────────────────────────────────────────────────────────

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.picking,
    required this.submitting,
    required this.onCamera,
    required this.onGallery,
    required this.c,
  });

  final bool picking;
  final bool submitting;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final disabled = picking || submitting;
    return Row(
      children: [
        Expanded(
          child: _SourceButton(
            icon: Icons.photo_camera_outlined,
            label: 'Camera',
            disabled: disabled,
            onTap: onCamera,
            c: c,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SourceButton(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            disabled: disabled,
            onTap: onGallery,
            c: c,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPLACE ROW  (compact chips, shown after image is selected)
// ─────────────────────────────────────────────────────────────────────────────

class _ReplaceRow extends StatelessWidget {
  const _ReplaceRow({
    required this.picking,
    required this.submitting,
    required this.onCamera,
    required this.onGallery,
    required this.c,
  });

  final bool picking;
  final bool submitting;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final disabled = picking || submitting;
    return Row(
      children: [
        Icon(Icons.refresh_rounded,
            size: 13, color: c.textSecondary.withOpacity(0.55)),
        const SizedBox(width: 5),
        Text(
          'Replace with:',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        _CompactChip(
          icon: Icons.photo_camera_outlined,
          label: 'Camera',
          disabled: disabled,
          onTap: onCamera,
          c: c,
        ),
        const SizedBox(width: 8),
        _CompactChip(
          icon: Icons.photo_library_outlined,
          label: 'Gallery',
          disabled: disabled,
          onTap: onGallery,
          c: c,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOURCE BUTTON  (tall card, empty state)
// ─────────────────────────────────────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.disabled,
    required this.onTap,
    required this.c,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final VoidCallback onTap;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: c.primary.withOpacity(0.07),
        highlightColor: c.primary.withOpacity(0.04),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: disabled
                    ? c.textSecondary.withOpacity(0.3)
                    : c.textPrimary.withOpacity(0.75),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? c.textSecondary.withOpacity(0.3)
                      : c.textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPACT CHIP  (pill, replace row)
// ─────────────────────────────────────────────────────────────────────────────

class _CompactChip extends StatelessWidget {
  const _CompactChip({
    required this.icon,
    required this.label,
    required this.disabled,
    required this.onTap,
    required this.c,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final VoidCallback onTap;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.border.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: disabled
                    ? c.textSecondary.withOpacity(0.3)
                    : c.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: disabled
                    ? c.textSecondary.withOpacity(0.3)
                    : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUIREMENTS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RequirementsCard extends StatelessWidget {
  const _RequirementsCard({required this.c});

  final AppColor c;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.lightbulb_outline_rounded,  'Good lighting, face fully visible'),
      (Icons.do_not_disturb_on_outlined, 'No sunglasses or face coverings'),
      (Icons.image_outlined,             'JPG, PNG, or WebP format'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REQUIREMENTS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: c.textSecondary.withOpacity(0.6),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c.border.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.$1, size: 15, color: c.textSecondary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.$2,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBMIT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.submitting,
    required this.picking,
    required this.hasFile,
    required this.onPressed,
    required this.c,
  });

  final bool submitting;
  final bool picking;
  final bool hasFile;
  final VoidCallback onPressed;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final disabled = submitting || picking || !hasFile;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: disabled
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
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.primary.withOpacity(0.35),
          disabledForegroundColor: Colors.white54,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: submitting
              ? Row(
            key: const ValueKey('loading'),
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
                'Submitting…',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2),
              ),
            ],
          )
              : Row(
            key: const ValueKey('idle'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasFile
                    ? Icons.cloud_upload_outlined
                    : Icons.add_photo_alternate_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                hasFile ? 'Submit Selfie' : 'Select a Photo First',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
