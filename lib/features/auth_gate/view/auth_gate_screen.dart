import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/features/auth_gate/model/auth_gate_state.dart';
import 'package:next_fi/features/auth_gate/view/widgets/biometrics_button.dart';
import 'package:next_fi/features/auth_gate/view/widgets/headings.dart';
import 'package:next_fi/features/auth_gate/view/widgets/lock_badge.dart';
import 'package:next_fi/features/auth_gate/view/widgets/lock_out_banner.dart';
import 'package:next_fi/features/auth_gate/view/widgets/pin_field.dart';
import 'package:next_fi/features/auth_gate/view/widgets/primary_action.dart';
import 'package:next_fi/features/auth_gate/view/widgets/tob_bar.dart';
import 'package:next_fi/features/auth_gate/view_model/auth_gate_vm.dart';
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
    with WidgetsBindingObserver {
  static const double _kFormWidth = 360;

  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  Timer? _smallVisualDelay;

  // Cache VM to avoid using context in dispose()
  late AuthGateVM _vm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    // When the PIN field gains focus, nudge to ensure visibility.
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
          appBar: TopBar(colors: colors),
          body: DecoratedBox(
            // Subtle background polish without clashing with your theme
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.background.withOpacity(.98),
                  colors.background.withOpacity(.94),
                ],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, viewport) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + kb),
                        keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            // Make content at least viewport height minus keyboard
                            minHeight: viewport.maxHeight - kb,
                          ),
                          child: Center(
                            // True vertical centering when space allows
                            child: _AuthCard(
                              formWidth: _kFormWidth,
                              colors: colors,
                              state: s,
                              isLockedOut: isLockedOut,
                              onSubmit: () => _submit(vm),
                              onToggleObscure: vm.toggleObscurePin,
                              onBiometricToggle: (val) async {
                                await vm.setBiometricsEnabled(val);
                                if (!mounted) return;
                                if (val) {
                                  final res = await vm.authenticateWithBiometrics();
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
                                } else {
                                  showFloatingSnackBar(
                                    context,
                                    message: "Biometrics disabled",
                                    type: SnackBarType.info,
                                  );
                                }
                              },
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
                  );
                },
              ),
            ),
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

/// Extracted for clarity. Simple, elegant card with soft elevation.
class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.formWidth,
    required this.colors,
    required this.state,
    required this.isLockedOut,
    required this.onSubmit,
    required this.onToggleObscure,
    required this.onBiometricToggle,
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
  final ValueChanged<bool> onBiometricToggle;
  final VoidCallback onToggleObscure;

  final TextEditingController pinController;
  final FocusNode pinFocus;

  final String headline;
  final String subhead;

  @override
  Widget build(BuildContext context) {
    final s = state;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      constraints: BoxConstraints(maxWidth: formWidth),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lock badge
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 250),
            child: Align(
              alignment: Alignment.topCenter,
              child: LockBadge(
                unlocked: s.unlockedVisual,
                colors: colors,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Headings
          Headings(headline: headline, subhead: subhead, colors: colors),

          if (isLockedOut) ...[
            const SizedBox(height: 10),
            LockoutBanner(remaining: s.lockoutRemaining!, colors: colors),
          ],

          const SizedBox(height: 16),

          // PIN input
          PinField(
            maxWidth: formWidth,
            controller: pinController,
            focusNode: pinFocus,
            enabled: !isLockedOut && !s.submitting,
            obscure: s.obscurePin,
            colors: colors,
            onSubmit: onSubmit,
            onToggleObscure: onToggleObscure,
          ),

          const SizedBox(height: 16),

          // Primary action
          PrimaryAction(
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

          // Biometrics switch
          if (!s.isNewUser && s.deviceSupportsBiometrics) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Use biometrics to unlock",
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: s.biometricsEnabled,
                  onChanged: (s.submitting || isLockedOut)
                      ? null
                      : onBiometricToggle,
                ),
              ],
            ),
          ],

          // Biometrics button (if enabled)
          if (!s.isNewUser &&
              s.deviceSupportsBiometrics &&
              s.biometricsEnabled) ...[
            const SizedBox(height: 8),
            BiometricsButton(
              maxWidth: formWidth,
              colors: colors,
              onPressed: onBiometricPressed,
            ),
          ],
        ],
      ),
    );
  }
}
