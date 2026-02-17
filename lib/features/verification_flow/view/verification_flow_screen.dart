import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/services/verification/models/verification_models.dart';
import 'package:next_fi/services/verification/verification_flow_service.dart';

class VerificationFlowScreen extends StatefulWidget {
  const VerificationFlowScreen({super.key});

  @override
  State<VerificationFlowScreen> createState() => _VerificationFlowScreenState();
}

class _VerificationFlowScreenState extends State<VerificationFlowScreen> {
  VerificationFlowSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await VerificationFlowService.I.getSnapshot();
      if (!mounted) return;

      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        title: const Text('Verification'),
      ),
      body: _buildBody(c),
    );
  }

  Widget _buildBody(AppColor c) {
    if (_loading) {
      return const PageLoader(label: 'Checking verification status...');
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: c.error, size: 32),
              const SizedBox(height: 10),
              Text(
                'Failed to load verification status',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }

    final statusLabel = _trustStatusText(snapshot.verification.status);
    final status = snapshot.verification.status;
    final canContinue = status == TrustStatus.basic || status == TrustStatus.unknown;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _statusCard(
            c,
            title: 'Verification status',
            value: statusLabel,
            subtitle: snapshot.isCompleted
                ? 'All required steps are completed.'
                : 'Continue from step ${snapshot.nextStepIndex}.',
          ),
          const SizedBox(height: 12),
          _stepTile(
            c,
            index: 1,
            title: 'Profile',
            subtitle: 'Fill basic identity details',
            nextStepIndex: snapshot.nextStepIndex,
          ),
          const SizedBox(height: 10),
          _stepTile(
            c,
            index: 2,
            title: 'Selfie Verification',
            subtitle: 'Submit selfie for review',
            nextStepIndex: snapshot.nextStepIndex,
          ),
          const SizedBox(height: 10),
          _stepTile(
            c,
            index: 3,
            title: 'Payment Method',
            subtitle: 'Set up your payment account',
            nextStepIndex: snapshot.nextStepIndex,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: canContinue ? () => _continueFromSnapshot(snapshot) : null,
              child: Text(
                _ctaLabel(snapshot),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(
    AppColor c, {
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _stepTile(
    AppColor c, {
    required int index,
    required String title,
    required String subtitle,
    required int nextStepIndex,
  }) {
    final isDone = nextStepIndex > index;
    final isCurrent = nextStepIndex == index;

    final dotColor = isDone
        ? c.success
        : isCurrent
            ? c.primary
            : c.textSecondary.withOpacity(0.4);

    final statusText = isDone
        ? 'Done'
        : isCurrent
            ? 'Current'
            : 'Pending';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? c.primary.withOpacity(0.5) : c.border.withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: dotColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  color: dotColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
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
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: dotColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _trustStatusText(TrustStatus status) {
    switch (status) {
      case TrustStatus.basic:
        return 'BASIC';
      case TrustStatus.reviewing:
        return 'REVIEWING';
      case TrustStatus.ready:
        return 'READY';
      case TrustStatus.suspended:
        return 'SUSPENDED';
      case TrustStatus.unknown:
        return 'UNKNOWN';
    }
  }

  String _ctaLabel(VerificationFlowSnapshot snapshot) {
    switch (snapshot.verification.status) {
      case TrustStatus.reviewing:
        return 'Under Review';
      case TrustStatus.ready:
        return 'Verified';
      case TrustStatus.suspended:
        return 'Verification Suspended';
      case TrustStatus.basic:
      case TrustStatus.unknown:
        return snapshot.isCompleted
            ? 'Verification Completed'
            : 'Continue Step ${snapshot.nextStepIndex}';
    }
  }

  Future<void> _continueFromSnapshot(VerificationFlowSnapshot snapshot) async {
    final step = snapshot.nextStepIndex > 3 ? 3 : snapshot.nextStepIndex;
    final routeName = switch (step) {
      1 => '/verification/profile',
      2 => '/verification/selfie',
      3 => '/verification/payment',
      _ => '/verification/profile',
    };

    try {
      await Navigator.of(context).pushNamed(routeName);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Step $step route is not configured yet ($routeName).'),
        ),
      );
    }
  }
}
