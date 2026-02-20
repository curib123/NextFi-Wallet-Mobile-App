import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/services/profile/models/profile_models.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';

class MerchantRequestScreen extends StatefulWidget {
  const MerchantRequestScreen({super.key});

  @override
  State<MerchantRequestScreen> createState() => _MerchantRequestScreenState();
}

class _MerchantRequestScreenState extends State<MerchantRequestScreen> {
  final TextEditingController _noteCtrl = TextEditingController();

  MerchantRequestStatusModel? _status;
  bool _loading = true;
  bool _submitting = false;
  bool _didHydrateNote = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final status = await ProfileCoreService.I.getMerchantRequestStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
        if (!_didHydrateNote) {
          _noteCtrl.text = status.merchantRequestNote?.trim() ?? '';
          _didHydrateNote = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_submitting) return;
    final status = _status;
    if (status == null || status.isMerchant || status.merchantRequestPending) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final updated = await ProfileCoreService.I.requestMerchantAccess(
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _status = updated;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merchant request submitted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final d = value.toLocal();
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final status = _status;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Merchant Request'),
      ),
      body: _loading
          ? const PageLoader(label: 'Loading merchant status...')
          : RefreshIndicator(
              onRefresh: _loadStatus,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                children: [
                  _IntroCard(colors: c),
                  const SizedBox(height: 12),
                  _StatusCard(
                    colors: c,
                    status: status,
                    formatDate: _formatDate,
                  ),
                  const SizedBox(height: 12),
                  if (_canRequest(status)) ...[
                    _NoteCard(
                      colors: c,
                      controller: _noteCtrl,
                      submitting: _submitting,
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    _StateHint(colors: c, status: status),
                    const SizedBox(height: 14),
                  ],
                  if (_error != null) ...[
                    _ErrorBanner(colors: c, message: _error!),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: AppOutlinedButton.icon(
                          onPressed: _submitting ? null : _loadStatus,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Refresh'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.textPrimary,
                            side: BorderSide(color: c.border.withOpacity(0.55)),
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppElevatedButton.icon(
                          onPressed: _canRequest(status)
                              ? _submitRequest
                              : null,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 16),
                          label: Text(
                            _submitting ? 'Submitting...' : 'Request',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: c.border.withOpacity(0.25),
                            disabledForegroundColor: c.textSecondary
                                .withOpacity(0.5),
                            minimumSize: const Size.fromHeight(46),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  bool _canRequest(MerchantRequestStatusModel? status) {
    if (status == null) return false;
    return !status.isMerchant && !status.merchantRequestPending;
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.colors});

  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.store, size: 16, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Request merchant access to unlock seller routes and offer creation.',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.colors,
    required this.status,
    required this.formatDate,
  });

  final AppColor colors;
  final MerchantRequestStatusModel? status;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final isMerchant = status?.isMerchant == true;
    final pending = status?.merchantRequestPending == true;
    final label = isMerchant
        ? 'Merchant enabled'
        : pending
        ? 'Request pending review'
        : 'No active request';
    final color = isMerchant
        ? colors.success
        : pending
        ? colors.warning
        : colors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Requested at: ${formatDate(status?.merchantRequestedAt)}',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.colors,
    required this.controller,
    required this.submitting,
  });

  final AppColor colors;
  final TextEditingController controller;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withOpacity(0.25)),
      ),
      child: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 5,
        enabled: !submitting,
        decoration: InputDecoration(
          labelText: 'Request note (optional)',
          hintText: 'Tell admin why you need merchant access.',
          filled: true,
          fillColor: colors.background.withOpacity(0.55),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border.withOpacity(0.35)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border.withOpacity(0.35)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _StateHint extends StatelessWidget {
  const _StateHint({required this.colors, required this.status});

  final AppColor colors;
  final MerchantRequestStatusModel? status;

  @override
  Widget build(BuildContext context) {
    final text = status?.isMerchant == true
        ? 'Your account is already approved as a merchant.'
        : 'Your request is already submitted and waiting for admin review.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 12.6,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.colors, required this.message});

  final AppColor colors;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withOpacity(0.2)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: colors.error,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
