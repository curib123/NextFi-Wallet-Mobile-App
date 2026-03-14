import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/features/auth_gate/presentation/widgets/lock_out_banner.dart';
import 'package:next_fi/features/auth_gate/presentation/viewmodels/auth_gate_controller.dart';
import 'package:next_fi/features/wallet_creation/presentation/widgets/fintech_background.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';

class AuthGateScreen extends ConsumerStatefulWidget {
  final VoidCallback? goNext;
  const AuthGateScreen({super.key, this.goNext});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  Timer? _smallVisualDelay;

  // Animation controllers
  late final AnimationController _bgCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  late final AnimationController _scaleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scaleCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(authGateControllerProvider.notifier);
      await controller.initialize();
      if (!mounted) return;

      final warn = ref.read(authGateControllerProvider).flow.initWarning;
      if (warn != null) {
        showFloatingSnackBar(context, message: warn, type: SnackBarType.error);
        if (!mounted) return;
      }

      final auto = await controller.maybeAutoBiometric();
      if (!mounted) return;
      if (auto?.message != null) {
        showFloatingSnackBar(
          context,
          message: auto!.message!,
          type: auto.success ? SnackBarType.success : SnackBarType.error,
        );
      }
      if (auto?.success == true) {
        _onSuccessNavigate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _smallVisualDelay?.cancel();
    _bgCtrl.dispose();
    _scaleCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = ref.read(authGateControllerProvider.notifier);
      controller.refreshLockout();
      controller.maybeAutoBiometric().then((auto) {
        if (!mounted) return;
        if (auto?.success == true) {
          _onSuccessNavigate();
        }
      });
    }
  }

  void _onSuccessNavigate() {
    _smallVisualDelay?.cancel();
    _smallVisualDelay = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final goNext = widget.goNext;
      if (goNext != null) {
        goNext();
      } else {
        Navigator.pushReplacementNamed(context, "/home");
      }
    });
  }

  void _onNumberPressed(String number) {
    final controller = ref.read(authGateControllerProvider.notifier);
    final completed = controller.onNumberPressed(number);
    if (completed || ref.read(authGateControllerProvider).currentPinLength > 0) {
      HapticFeedback.lightImpact();
    }
    if (completed) {
      _submit();
    }
  }

  void _onBackspacePressed() {
    final controller = ref.read(authGateControllerProvider.notifier);
    if (ref.read(authGateControllerProvider).currentPin.isNotEmpty) {
      controller.onBackspacePressed();
      HapticFeedback.lightImpact();
    }
  }

  void _playShakeAnimation() {
    _shakeCtrl.reset();
    _shakeCtrl.forward();
  }

  Future<void> _submit() async {
    final controller = ref.read(authGateControllerProvider.notifier);
    final res = await controller.submitCurrentPin();
    if (!mounted) return;

    if (res.message != null) {
      showFloatingSnackBar(
        context,
        message: res.message!,
        type: switch (res.status) {
          PinStatus.saved || PinStatus.verified => SnackBarType.success,
          PinStatus.needFirstConfirm => SnackBarType.info,
          PinStatus.mismatch ||
          PinStatus.invalid ||
          PinStatus.storageError ||
          PinStatus.error => SnackBarType.error,
          PinStatus.lockedOut => SnackBarType.warning,
        },
      );
    }

    switch (res.status) {
      case PinStatus.needFirstConfirm:
        controller.clearCurrentPin();
        break;
      case PinStatus.mismatch:
      case PinStatus.invalid:
      case PinStatus.storageError:
      case PinStatus.error:
        _playShakeAnimation();
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) controller.clearCurrentPin();
        break;
      case PinStatus.lockedOut:
        controller.clearCurrentPin();
        break;
      case PinStatus.saved:
      case PinStatus.verified:
        controller.clearCurrentPin();
        _onSuccessNavigate();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final viewState = ref.watch(authGateControllerProvider);
    final controller = ref.read(authGateControllerProvider.notifier);
    final s = viewState.flow;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    final isLockedOut = viewState.isLockedOut;
    final headline = s.isNewUser
        ? (s.firstPinEntry == null ? "Create PIN" : "Confirm PIN")
        : "Enter PIN";
    final subhead = s.isNewUser
        ? (s.firstPinEntry == null
              ? "Set a 6-digit PIN to secure your wallet"
              : "Please enter your PIN again")
        : "Enter your PIN to unlock";

    return PopScope(
      canPop: Navigator.canPop(context),
      child: Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            // Animated fallback background
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _bgCtrl,
                  builder: (_, __) => FintechBackground(
                    progress: _bgCtrl.value,
                    colors: colors,
                    devicePixelRatio: dpr,
                    topBandFraction: .55,
                  ),
                ),
              ),
            ),
            if (viewState.coverImageUrl != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CachedNetworkImage(
                    imageUrl: viewState.coverImageUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    fadeInDuration: const Duration(milliseconds: 220),
                    fadeOutDuration: const Duration(milliseconds: 120),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    placeholder: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(
                          alpha: viewState.coverImageUrl != null ? 0.48 : 0.18,
                        ),
                        Colors.black.withValues(
                          alpha: viewState.coverImageUrl != null ? 0.32 : 0.08,
                        ),
                        colors.background.withValues(
                          alpha: viewState.coverImageUrl != null ? 0.76 : 0.16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _scaleCtrl,
                        curve: Curves.easeOutBack,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Lock icon
                          _LockIcon(unlocked: s.unlockedVisual, colors: colors),

                          const SizedBox(height: 32),

                          // Headline
                          Text(
                            headline,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Subheadline
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              subhead,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),

                          if (isLockedOut) ...[
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: LockoutBanner(
                                remaining: s.lockoutRemaining!,
                                colors: colors,
                              ),
                            ),
                          ],

                          const SizedBox(height: 48),

                          // PIN dots display
                          AnimatedBuilder(
                            animation: _shakeCtrl,
                            builder: (context, child) {
                              final shake = _shakeCtrl.value;
                              final offset = shake < 0.5
                                  ? shake * 20
                                  : (1 - shake) * 20;
                              return Transform.translate(
                                offset: Offset(
                                  shake > 0
                                      ? (offset - 10) * (shake < 0.5 ? 1 : -1)
                                      : 0,
                                  0,
                                ),
                                child: child,
                              );
                            },
                            child: _PinDotsDisplay(
                              pinLength: viewState.currentPinLength,
                              colors: colors,
                              obscure: s.obscurePin,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Custom numeric keyboard with biometric button integrated
                  _NumericKeyboard(
                    onNumberPressed: _onNumberPressed,
                    onBackspacePressed: _onBackspacePressed,
                    colors: colors,
                    enabled: !isLockedOut && !s.submitting,
                    showBiometric:
                        !s.isNewUser &&
                        s.deviceSupportsBiometrics &&
                        s.biometricsEnabled &&
                        !isLockedOut,
                    onBiometricPressed: () async {
                      final res = await controller.authenticateWithBiometrics();
                      if (!context.mounted) return;
                      if (res.message != null) {
                        showFloatingSnackBar(
                          context,
                          message: res.message!,
                          type: res.success
                              ? SnackBarType.success
                              : SnackBarType.error,
                        );
                      }
                      if (res.success) _onSuccessNavigate();
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern lock icon with animation
class _LockIcon extends StatelessWidget {
  const _LockIcon({required this.unlocked, required this.colors});

  final bool unlocked;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: unlocked ? 1.0 : 0.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (unlocked ? colors.success : colors.primary).withValues(
                  alpha: .15,
                ),
                (unlocked ? colors.success : colors.primary).withValues(
                  alpha: .05,
                ),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: (unlocked ? colors.success : colors.primary).withValues(
                  alpha: .2,
                ),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 36,
              color: unlocked ? colors.success : colors.primary,
            ),
          ),
        );
      },
    );
  }
}

/// PIN dots display
class _PinDotsDisplay extends StatelessWidget {
  const _PinDotsDisplay({
    required this.pinLength,
    required this.colors,
    required this.obscure,
  });

  final int pinLength;
  final AppColor colors;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < pinLength;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: isFilled ? 16 : 14,
            height: isFilled ? 16 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled
                  ? colors.primary
                  : colors.primary.withValues(alpha: .15),
              border: Border.all(
                color: isFilled
                    ? colors.primary
                    : colors.primary.withValues(alpha: .3),
                width: isFilled ? 0 : 2,
              ),
              boxShadow: isFilled
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: .4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

/// Custom numeric keyboard
class _NumericKeyboard extends StatelessWidget {
  const _NumericKeyboard({
    required this.onNumberPressed,
    required this.onBackspacePressed,
    required this.colors,
    required this.enabled,
    this.showBiometric = false,
    this.onBiometricPressed,
  });

  final Function(String) onNumberPressed;
  final VoidCallback onBackspacePressed;
  final AppColor colors;
  final bool enabled;
  final bool showBiometric;
  final VoidCallback? onBiometricPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildRow(['1', '2', '3']),
          const SizedBox(height: 16),
          _buildRow(['4', '5', '6']),
          const SizedBox(height: 16),
          _buildRow(['7', '8', '9']),
          const SizedBox(height: 16),
          _buildRow([showBiometric ? 'biometric' : '', '0', 'backspace']),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) {
          return const Expanded(child: SizedBox());
        }
        if (key == 'biometric') {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _BiometricKeyButton(
                colors: colors,
                onPressed: onBiometricPressed ?? () {},
                enabled: enabled,
              ),
            ),
          );
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _KeyButton(
              label: key,
              onPressed: () {
                if (!enabled) return;
                if (key == 'backspace') {
                  onBackspacePressed();
                } else {
                  onNumberPressed(key);
                }
              },
              colors: colors,
              enabled: enabled,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Individual key button
class _KeyButton extends StatefulWidget {
  const _KeyButton({
    required this.label,
    required this.onPressed,
    required this.colors,
    required this.enabled,
  });

  final String label;
  final VoidCallback onPressed;
  final AppColor colors;
  final bool enabled;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBackspace = widget.label == 'backspace';

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _controller.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _controller.reverse();
              widget.onPressed();
            }
          : null,
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (_controller.value * 0.05);
          return Transform.scale(
            scale: scale,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.colors.primary.withValues(
                  alpha: _controller.value * 0.15,
                ),
              ),
              child: Center(
                child: isBackspace
                    ? Icon(
                        Icons.backspace_outlined,
                        size: 24,
                        color: widget.enabled
                            ? widget.colors.textPrimary
                            : widget.colors.textSecondary.withValues(alpha: .5),
                      )
                    : Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: widget.enabled
                              ? widget.colors.textPrimary
                              : widget.colors.textSecondary.withValues(
                                  alpha: .5,
                                ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Biometric key button (integrated into keyboard)
class _BiometricKeyButton extends StatefulWidget {
  const _BiometricKeyButton({
    required this.colors,
    required this.onPressed,
    required this.enabled,
  });

  final AppColor colors;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<_BiometricKeyButton> createState() => _BiometricKeyButtonState();
}

class _BiometricKeyButtonState extends State<_BiometricKeyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _controller.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _controller.reverse();
              widget.onPressed();
            }
          : null,
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (_controller.value * 0.05);
          return Transform.scale(
            scale: scale,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.colors.primary.withValues(
                  alpha: _controller.value * 0.15,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.fingerprint,
                  size: 28,
                  color: widget.enabled
                      ? widget.colors.primary
                      : widget.colors.primary.withValues(alpha: .5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


