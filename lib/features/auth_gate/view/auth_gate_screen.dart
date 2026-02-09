import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/features/auth_gate/model/auth_gate_state.dart';
import 'package:next_fi/features/auth_gate/view/widgets/biometrics_button.dart';
import 'package:next_fi/features/auth_gate/view/widgets/headings.dart';
import 'package:next_fi/features/auth_gate/view/widgets/lock_badge.dart';
import 'package:next_fi/features/auth_gate/view/widgets/lock_out_banner.dart';
import 'package:next_fi/features/auth_gate/view/widgets/pin_field.dart';
import 'package:next_fi/features/auth_gate/view/widgets/primary_action.dart';
import 'package:next_fi/features/auth_gate/view_model/auth_gate_vm.dart';
import 'package:next_fi/features/wallet_creation/view/widgets/fintech_background.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';

class AuthGateScreen extends StatefulWidget {
  final VoidCallback? goNext;
  const AuthGateScreen({super.key, this.goNext});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const double _kFormWidth = 380;

  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  Timer? _smallVisualDelay;

  late AuthGateVM _vm;

  // Animation controllers
  late final AnimationController _bgCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  late final AnimationController _scaleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Entrance animation
    _scaleCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _vm.init();
      if (!mounted) return;

      final warn = _vm.state.initWarning;
      if (warn != null) {
        showFloatingSnackBar(context, message: warn, type: SnackBarType.error);
        if (!mounted) return;
      }

      final auto = await _vm.maybeAutoBiometric();
      if (!mounted) return;
      if (auto?.message != null) {
        showFloatingSnackBar(
          context,
          message: auto!.message!,
          type: auto.success ? SnackBarType.success : SnackBarType.error,
        );
      }
    });

    _pinFocus.addListener(() {
      if (_pinFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!_scroll.hasClients) return;
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm = context.read<AuthGateVM>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm.disposeTimers();
    _pinController.dispose();
    _pinFocus.dispose();
    _scroll.dispose();
    _smallVisualDelay?.cancel();
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _vm.refreshLockout();
      _vm.maybeAutoBiometric();
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<AuthGateVM>();
    final s = vm.state;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    final isLockedOut = vm.isLockedOut;
    final headline = s.isNewUser
        ? (s.firstPinEntry == null ? "Set Your PIN" : "Confirm PIN")
        : "Enter PIN";
    final subhead = s.isNewUser
        ? (s.firstPinEntry == null
        ? "Secure your wallet with a 6-digit PIN"
        : "Re-enter the same 6-digit PIN")
        : "Unlock your wallet securely";

    final kb = MediaQuery.of(context).viewInsets.bottom;

    return WillPopScope(
      onWillPop: () async => Navigator.canPop(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: colors.background,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              // Animated fintech background
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

              // Main content
              Positioned.fill(
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, viewport) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 540),
                          child: SingleChildScrollView(
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + kb),
                            keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: viewport.maxHeight - kb - 40,
                              ),
                              child: Center(
                                child: ScaleTransition(
                                  scale: CurvedAnimation(
                                    parent: _scaleCtrl,
                                    curve: Curves.easeOutBack,
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _pulseCtrl,
                                    builder: (_, child) {
                                      final pulseScale = 1.0 + (_pulseCtrl.value * 0.008);
                                      return Transform.scale(
                                        scale: pulseScale,
                                        child: child,
                                      );
                                    },
                                    child: _AuthCard(
                                      formWidth: _kFormWidth,
                                      colors: colors,
                                      state: s,
                                      isLockedOut: isLockedOut,
                                      onSubmit: () => _submit(vm),
                                      onToggleObscure: vm.toggleObscurePin,
                                      onBiometricPressed: () async {
                                        final res = await _vm.authenticateWithBiometrics();
                                        if (!mounted) return;
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
                                      pinController: _pinController,
                                      pinFocus: _pinFocus,
                                      headline: headline,
                                      subhead: subhead,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AuthGateVM vm) async {
    final res = await vm.submitPin(_pinController.text);
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
          PinStatus.error =>
          SnackBarType.error,
          PinStatus.lockedOut => SnackBarType.warning,
        },
      );
    }

    switch (res.status) {
      case PinStatus.needFirstConfirm:
        _pinController.clear();
        _pinFocus.requestFocus();
        break;
      case PinStatus.mismatch:
      case PinStatus.invalid:
      case PinStatus.storageError:
      case PinStatus.error:
        _pinController.clear();
        _pinFocus.requestFocus();
        HapticFeedback.mediumImpact();
        break;
      case PinStatus.lockedOut:
        _pinController.clear();
        break;
      case PinStatus.saved:
      case PinStatus.verified:
        _pinController.clear();
        FocusManager.instance.primaryFocus?.unfocus();
        _onSuccessNavigate();
        break;
    }
  }
}

/// Premium glass card with enhanced glassmorphism and depth
class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.formWidth,
    required this.colors,
    required this.state,
    required this.isLockedOut,
    required this.onSubmit,
    required this.onToggleObscure,
    required this.onBiometricPressed,
    required this.pinController,
    required this.pinFocus,
    required this.headline,
    required this.subhead,
  });

  final double formWidth;
  final AppColor colors;
  final AuthGateState state;
  final bool isLockedOut;

  final VoidCallback onSubmit;
  final VoidCallback onBiometricPressed;
  final VoidCallback onToggleObscure;

  final TextEditingController pinController;
  final FocusNode pinFocus;

  final String headline;
  final String subhead;

  @override
  Widget build(BuildContext context) {
    final s = state;

    return Container(
      constraints: BoxConstraints(maxWidth: formWidth),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withOpacity(.7),
            colors.surface.withOpacity(.5),
          ],
        ),
        border: Border.all(
          color: colors.primary.withOpacity(.2),
          width: 1.5,
        ),
        boxShadow: [
          // Primary glow
          BoxShadow(
            color: colors.primary.withOpacity(.12),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 20),
          ),
          // Depth shadow
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          // Top highlight
          BoxShadow(
            color: Colors.white.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surface.withOpacity(.9),
                  colors.surface.withOpacity(.8),
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lock badge with glow
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: s.unlockedVisual
                            ? Colors.green.withOpacity(.2)
                            : colors.primary.withOpacity(.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: LockBadge(
                      unlocked: s.unlockedVisual,
                      colors: colors,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Headings
                Headings(headline: headline, subhead: subhead, colors: colors),

                if (isLockedOut) ...[
                  const SizedBox(height: 16),
                  LockoutBanner(remaining: s.lockoutRemaining!, colors: colors),
                ],

                const SizedBox(height: 24),

                // PIN input with enhanced styling
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: colors.background.withOpacity(.3),
                    border: Border.all(
                      color: colors.primary.withOpacity(.1),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: PinField(
                    maxWidth: formWidth,
                    controller: pinController,
                    focusNode: pinFocus,
                    enabled: !isLockedOut && !s.submitting,
                    obscure: s.obscurePin,
                    colors: colors,
                    onSubmit: onSubmit,
                    onToggleObscure: onToggleObscure,
                  ),
                ),

                const SizedBox(height: 24),

                // Primary action with enhanced styling
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withOpacity(.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: PrimaryAction(
                    maxWidth: formWidth,
                    colors: colors,
                    text: s.isNewUser
                        ? (s.firstPinEntry == null ? "Continue" : "Save PIN")
                        : "Unlock",
                    icon: s.unlockedVisual
                        ? Icons.lock_open_rounded
                        : (s.isNewUser
                        ? (s.firstPinEntry == null
                        ? Icons.arrow_forward
                        : Icons.save_rounded)
                        : Icons.lock_rounded),
                    enabled: !s.submitting && !isLockedOut,
                    onPressed: onSubmit,
                  ),
                ),

                // Biometrics button with enhanced styling
                if (!s.isNewUser &&
                    s.deviceSupportsBiometrics &&
                    s.biometricsEnabled) ...[
                  const SizedBox(height: 16),
                  BiometricsButton(
                    maxWidth: formWidth,
                    colors: colors,
                    onPressed: onBiometricPressed,
                  ),
                ],

                // Security indicator
                if (!s.isNewUser) ...[
                  const SizedBox(height: 20),
                  _SecurityIndicator(colors: colors),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Security indicator widget
class _SecurityIndicator extends StatelessWidget {
  const _SecurityIndicator({required this.colors});

  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primary.withOpacity(.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user,
            size: 16,
            color: colors.primary.withOpacity(.8),
          ),
          const SizedBox(width: 8),
          Text(
            'Your keys are encrypted locally',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}