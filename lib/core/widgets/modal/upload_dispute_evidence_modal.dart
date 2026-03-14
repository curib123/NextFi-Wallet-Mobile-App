import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';

class TradeProofPickResult {
  const TradeProofPickResult({
    required this.source,
    required this.type,
    this.referenceNo,
    this.txHash,
  });

  final ImageSource source;
  final String type;
  final String? referenceNo;
  final String? txHash;
}

class UploadDisputeEvidenceModal extends StatefulWidget {
  const UploadDisputeEvidenceModal({super.key, required this.colors});

  final AppColor colors;

  @override
  State<UploadDisputeEvidenceModal> createState() =>
      _UploadDisputeEvidenceModalState();
}

class _UploadDisputeEvidenceModalState
    extends State<UploadDisputeEvidenceModal> {
  String _proofType = 'FIAT';
  final TextEditingController _referenceCtrl = TextEditingController();
  final TextEditingController _txHashCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _txHashCtrl.dispose();
    super.dispose();
  }

  void _submitWith(ImageSource source) {
    final type = _proofType.trim().toUpperCase();
    final txHash = _txHashCtrl.text.trim();
    if (type == 'CRYPTO' && txHash.isEmpty) {
      setState(
        () =>
            _error = 'Please add the transaction ID for crypto payment proof.',
      );
      return;
    }

    Navigator.pop(
      context,
      TradeProofPickResult(
        source: source,
        type: type,
        referenceNo: _referenceCtrl.text.trim().isEmpty
            ? null
            : _referenceCtrl.text.trim(),
        txHash: txHash.isEmpty ? null : txHash,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final media = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 16, 20, media.padding.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Upload Files for Support Review',
                  style: AppFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose file type and upload screenshots or photos.',
                  textAlign: TextAlign.center,
                  style: AppFonts.sora(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProofTypeChip(
                        colors: colors,
                        label: 'FIAT',
                        selected: _proofType == 'FIAT',
                        onTap: () => setState(() => _proofType = 'FIAT'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProofTypeChip(
                        colors: colors,
                        label: 'CRYPTO',
                        selected: _proofType == 'CRYPTO',
                        onTap: () => setState(() => _proofType = 'CRYPTO'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ProofField(
                  colors: colors,
                  controller: _referenceCtrl,
                  hint: 'Reference no. (optional)',
                ),
                if (_proofType == 'CRYPTO') ...[
                  const SizedBox(height: 10),
                  _ProofField(
                    colors: colors,
                    controller: _txHashCtrl,
                    hint: 'Transaction ID (required)',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: AppFonts.sora(
                        fontSize: 11.5,
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _SourceOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Choose from Gallery',
                  colors: colors,
                  onTap: () => _submitWith(ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                _SourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take a Photo',
                  colors: colors,
                  onTap: () => _submitWith(ImageSource.camera),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: AppOutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.background,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: AppFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProofTypeChip extends StatelessWidget {
  const _ProofTypeChip({
    required this.colors,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppColor colors;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? colors.primary : colors.border),
        ),
        child: Text(
          label,
          style: AppFonts.sora(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? colors.onPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProofField extends StatelessWidget {
  const _ProofField({
    required this.colors,
    required this.controller,
    required this.hint,
  });

  final AppColor colors;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        style: AppFonts.sora(fontSize: 13, color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppFonts.sora(
            fontSize: 12.5,
            color: colors.textSecondary,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final AppColor colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: AppOutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.surface,
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: colors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppFonts.sora(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


