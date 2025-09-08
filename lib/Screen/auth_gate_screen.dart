// lib/Screen/auth_gate_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Services/security_storage.dart';
import 'package:next_fi/Components/CustomButton.dart';

class AuthGateScreen extends StatefulWidget {
  final VoidCallback? goNext;

  const AuthGateScreen({Key? key, this.goNext}) : super(key: key);

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final TextEditingController _pinController = TextEditingController();

  bool _isNewUser = false;
  bool _deviceSupportsBiometrics = false;
  bool _biometricsEnabled = false;
  bool _obscurePin = true;
  bool _submitting = false;

  // First-time setup: step 1 (enter) → step 2 (confirm)
  String? _firstPinEntry;

  // Lockout support
  Duration? _lockoutRemaining;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _initAuthCheck();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _initAuthCheck() async {
    // Ensure secure storage is actually available
    final ready = await SecurityStorage.ensureReady();
    if (!ready) {
      if (mounted) {
        showFloatingSnackBar(
          context,
          message:
          "Secure storage is unavailable on this environment. PIN cannot be saved (e.g., web private mode/emulator).",
          type: SnackBarType.error,
        );
      }
      setState(() {
        _isNewUser = true;
        _deviceSupportsBiometrics = false;
        _biometricsEnabled = false;
      });
      return;
    }

    // Safe migrations (no-op if absent/invalid)
    await SecurityStorage.migrateLegacyPlaintextPin(legacyKey: 'user_pin');
    await SecurityStorage.migrateLegacyPlaintextPin(legacyKey: 'app_pin_v1');

    // PIN presence
    final hasPin = await SecurityStorage.hasPin();

    // Biometrics capabilities
    bool canCheck = false;
    bool isSupported = false;
    List<BiometricType> available = const [];
    try {
      canCheck = await _localAuth.canCheckBiometrics;
      isSupported = await _localAuth.isDeviceSupported();
      available = await _localAuth.getAvailableBiometrics();
    } catch (_) {}
    final bioEnabled = await SecurityStorage.isBiometricsEnabled();

    // Current lockout (if any)
    final rem = await SecurityStorage.lockoutRemaining();

    if (!mounted) return;
    setState(() {
      _isNewUser = !hasPin;
      _deviceSupportsBiometrics = (canCheck || isSupported) && available.isNotEmpty;
      _biometricsEnabled = bioEnabled;
      _lockoutRemaining = rem;
    });

    _startOrStopLockoutTimer(rem);
  }

  void _startOrStopLockoutTimer(Duration? remaining) {
    _lockoutTimer?.cancel();
    if (remaining == null || remaining <= Duration.zero) return;

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final rem = await SecurityStorage.lockoutRemaining();
      if (!mounted) return;
      if (rem == null || rem <= Duration.zero) {
        t.cancel();
        setState(() => _lockoutRemaining = null);
      } else {
        setState(() => _lockoutRemaining = rem);
      }
    });
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;

      if (didAuthenticate) {
        await SecurityStorage.markSuccessfulAuth(); // clears attempts/lockout
        showFloatingSnackBar(
          context,
          message: "Authentication successful",
          type: SnackBarType.success,
        );
        _onAuthSuccess();
      } else {
        showFloatingSnackBar(
          context,
          message: "Biometric authentication failed",
          type: SnackBarType.error,
        );
      }
    } on PlatformException catch (e) {
      showFloatingSnackBar(
        context,
        message: "Biometric error: ${e.code}",
        type: SnackBarType.error,
      );
    } catch (e) {
      showFloatingSnackBar(
        context,
        message: "Biometric error: $e",
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _onSubmitPin() async {
    if (_submitting) return;

    // If locked out, politely inform remaining time
    if (_lockoutRemaining != null && _lockoutRemaining! > Duration.zero) {
      showFloatingSnackBar(
        context,
        message: "Too many attempts. Try again in ${_lockoutRemaining!.inSeconds}s.",
        type: SnackBarType.warning,
      );
      return;
    }

    final pin = _pinController.text.trim();

    // Enforce exact 6 digits to match SecurityStorage policy
    if (pin.length != 6 || !_isAllDigits(pin)) {
      showFloatingSnackBar(
        context,
        message: "PIN must be exactly 6 digits",
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_isNewUser) {
        // Step 1: store first entry
        if (_firstPinEntry == null) {
          _firstPinEntry = pin;
          _pinController.clear();
          showFloatingSnackBar(
            context,
            message: "Re-enter your PIN to confirm",
            type: SnackBarType.info,
          );
          setState(() {}); // updates headline from "Set" → "Confirm"
          return;
        }

        // Step 2: confirm
        if (pin != _firstPinEntry) {
          _firstPinEntry = null;
          _pinController.clear();
          HapticFeedback.mediumImpact();
          showFloatingSnackBar(
            context,
            message: "PINs do not match. Please try again.",
            type: SnackBarType.error,
          );
          return;
        }

        await SecurityStorage.setPin(pin);

        // Sanity check to ensure it persisted (handles rare keystore issues)
        final saved = await SecurityStorage.hasPin();
        if (!saved) {
          showFloatingSnackBar(
            context,
            message: "⚠️ Couldn’t persist PIN. Please try again (or disable private mode).",
            type: SnackBarType.error,
          );
          return;
        }

        if (!mounted) return;
        setState(() {
          _isNewUser = false;
          _firstPinEntry = null;
        });

        showFloatingSnackBar(
          context,
          message: "PIN saved successfully",
          type: SnackBarType.success,
        );
        _pinController.clear();
        _onAuthSuccess();
        return;
      }

      // Existing user: verify against hash with lockout protection.
      final ok = await SecurityStorage.verifyPin(pin);
      if (ok) {
        showFloatingSnackBar(
          context,
          message: "PIN verified successfully",
          type: SnackBarType.success,
        );
        _pinController.clear();
        _onAuthSuccess();
      } else {
        // After a failed verify, lockout may have started; refresh it.
        final rem = await SecurityStorage.lockoutRemaining();
        if (mounted) {
          setState(() => _lockoutRemaining = rem);
          _startOrStopLockoutTimer(rem);
        }

        HapticFeedback.mediumImpact();
        showFloatingSnackBar(
          context,
          message: rem != null && rem > Duration.zero
              ? "Too many attempts. Try again in ${rem.inSeconds}s."
              : "Invalid PIN",
          type: SnackBarType.error,
        );
      }
    } catch (e) {
      showFloatingSnackBar(
        context,
        message: "Error: $e",
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _onAuthSuccess() {
    if (widget.goNext != null) {
      widget.goNext!();
    } else {
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    final isLockedOut = _lockoutRemaining != null && _lockoutRemaining! > Duration.zero;
    final headline = _isNewUser
        ? (_firstPinEntry == null ? "Set Your PIN" : "Confirm PIN")
        : "Enter PIN";
    final subhead = _isNewUser
        ? (_firstPinEntry == null
        ? "Secure your wallet with a 6-digit PIN"
        : "Re-enter the same 6-digit PIN")
        : "Unlock your wallet securely";

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Security",
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: colors.textPrimary,
          onPressed: () => Navigator.pop(context),
        )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, size: 60, color: colors.primary),
                ),
                const SizedBox(height: 28),

                // Headline
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Subhead
                Text(
                  subhead,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Lockout banner
                if (isLockedOut) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Text(
                      "Too many attempts. Try again in ${_lockoutRemaining!.inSeconds}s.",
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // PIN input (centered)
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: TextField(
                      controller: _pinController,
                      enabled: !isLockedOut && !_submitting,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      obscureText: _obscurePin,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onSubmitPin(),
                      style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        filled: true,
                        fillColor: colors.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.primary.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.primary, width: 1.5),
                        ),
                        hintText: "••••••",
                        hintStyle: TextStyle(
                          fontSize: 20,
                          letterSpacing: 6,
                          color: colors.textSecondary.withOpacity(0.4),
                        ),
                        prefixIcon: const SizedBox(width: 48),
                        prefixIconConstraints: const BoxConstraints(minWidth: 48),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePin ? Icons.visibility_off : Icons.visibility,
                            color: colors.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscurePin = !_obscurePin),
                        ),
                        suffixIconConstraints: const BoxConstraints(minWidth: 48),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Primary action
                CustomButton(
                  text: _isNewUser
                      ? (_firstPinEntry == null ? "Continue" : "Save PIN")
                      : "Unlock",
                  onPressed: () {
                    if (_submitting) return;
                    final isLockedOut = _lockoutRemaining != null && _lockoutRemaining! > Duration.zero;
                    if (isLockedOut) return;
                    _onSubmitPin(); // ignore the Future on purpose
                  },
                  type: ButtonType.filled,
                  icon: _isNewUser
                      ? (_firstPinEntry == null ? Icons.arrow_forward : Icons.save)
                      : Icons.lock_open,
                ),

                const SizedBox(height: 16),

                // Biometrics (shown only if user has a PIN AND enabled biometrics)
                if (!_isNewUser && _deviceSupportsBiometrics && _biometricsEnabled)
                  TextButton.icon(
                    onPressed: _authenticateWithBiometrics,
                    icon: Icon(Icons.fingerprint_rounded, color: colors.primary),
                    label: Text(
                      "Use Biometrics",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: colors.primary,
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

  bool _isAllDigits(String s) => RegExp(r'^\d+$').hasMatch(s);
}
