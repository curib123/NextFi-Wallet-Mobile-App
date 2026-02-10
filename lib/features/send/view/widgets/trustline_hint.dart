// lib/features/send/view/widgets/trustline_hint.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/features/send/view_model/send_vm.dart';
import 'package:provider/provider.dart';

class TrustlineHint extends StatelessWidget {
  const TrustlineHint({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = context.watch<SendVM>();

    if (vm.isXlm) return const SizedBox.shrink();
    if (vm.to.trim().isEmpty) return const SizedBox.shrink();

    // Checking state
    if (vm.checking) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _HintContainer(
          gradient: [
            c.primary.withValues(alpha: 0.06),
            c.primary.withValues(alpha: 0.03),
          ],
          borderColor: c.primary.withValues(alpha: 0.12),
          child: Row(
            children: [
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Verifying USDC trustline…',
                  style: TextStyle(
                    color: c.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No trustline
    if (vm.destHasUsdcTL == false) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _HintContainer(
          gradient: [
            c.error.withValues(alpha: 0.08),
            c.error.withValues(alpha: 0.04),
          ],
          borderColor: c.error.withValues(alpha: 0.15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.error.withValues(alpha: 0.15),
                      c.error.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.alertTriangle,
                  size: 14,
                  color: c.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No USDC Trustline',
                      style: TextStyle(
                        color: c.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'This address cannot receive USDC. The recipient needs to add a USDC trustline first.',
                      style: TextStyle(
                        color: c.error.withValues(alpha: 0.8),
                        fontSize: 11.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Trustline verified
    if (vm.destHasUsdcTL == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _HintContainer(
          gradient: [
            c.success.withValues(alpha: 0.08),
            c.success.withValues(alpha: 0.04),
          ],
          borderColor: c.success.withValues(alpha: 0.15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.success.withValues(alpha: 0.15),
                      c.success.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.checkCircle2,
                  size: 14,
                  color: c.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trustline Verified',
                      style: TextStyle(
                        color: c.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This address can receive USDC',
                      style: TextStyle(
                        color: c.textSecondary.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _HintContainer extends StatefulWidget {
  const _HintContainer({
    required this.gradient,
    required this.borderColor,
    required this.child,
  });

  final List<Color> gradient;
  final Color borderColor;
  final Widget child;

  @override
  State<_HintContainer> createState() => _HintContainerState();
}

class _HintContainerState extends State<_HintContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradient,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.borderColor,
              width: 1.5,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}