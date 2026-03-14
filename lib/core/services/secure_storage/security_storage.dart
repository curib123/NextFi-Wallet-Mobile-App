// lib/services/security_storage.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage wrapper with PIN management and lockout protection.
///
/// Keys used (all strings):
/// - 'pin_hash_v2'         : hex sha256(salt:pin)
/// - 'pin_salt_v2'         : base64 random salt
/// - 'pin_failed_attempts' : integer (as string)
/// - 'pin_lockout_until'   : epoch millis (as string)
/// - 'biometrics_enabled'  : '1' or '0'
class SecurityStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // ────────────────────────────────────────────────────────────────────────────
  // Platform options (apply to ALL operations)
  // ────────────────────────────────────────────────────────────────────────────
  static const AndroidOptions _aOpts = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true, // recreate prefs if keystore keys become invalid
  );
  static const IOSOptions _iOpts = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock, // available after first unlock
  );

  // ────────────────────────────────────────────────────────────────────────────
  // Basic K/V helpers
  // ────────────────────────────────────────────────────────────────────────────
  static Future<void> save(String key, String value) {
    return _storage.write(key: key, value: value, aOptions: _aOpts, iOptions: _iOpts);
  }

  static Future<String?> read(String key) {
    return _storage.read(key: key, aOptions: _aOpts, iOptions: _iOpts);
  }

  static Future<void> delete(String key) {
    return _storage.delete(key: key, aOptions: _aOpts, iOptions: _iOpts);
  }

  static Future<bool> containsKey(String key) {
    return _storage.containsKey(key: key, aOptions: _aOpts, iOptions: _iOpts);
  }

  static Future<Map<String, String>> readAll() {
    return _storage.readAll(aOptions: _aOpts, iOptions: _iOpts);
  }

  static Future<void> deleteAll() {
    return _storage.deleteAll(aOptions: _aOpts, iOptions: _iOpts);
  }

  /// Probe that secure storage actually persists on this environment.
  /// Returns false in web-private mode, some emulators, or broken keystore.
  static Future<bool> ensureReady() async {
    try {
      await _storage.write(key: '__probe__', value: '1', aOptions: _aOpts, iOptions: _iOpts);
      final v = await _storage.read(key: '__probe__', aOptions: _aOpts, iOptions: _iOpts);
      await _storage.delete(key: '__probe__', aOptions: _aOpts, iOptions: _iOpts);
      return v == '1';
    } catch (_) {
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PIN management
  // ────────────────────────────────────────────────────────────────────────────
  static const String _kPinHash = 'pin_hash_v2';
  static const String _kPinSalt = 'pin_salt_v2';
  static const String _kAttempts = 'pin_failed_attempts';
  static const String _kLockoutUntil = 'pin_lockout_until';
  static const String _kBioEnabled = 'biometrics_enabled';

  /// Match UI: exactly 6 digits.
  static const int minPinLen = 6;
  static const int maxPinLen = 6;
  static final RegExp _pinPattern = RegExp(r'^\d{6}$');

  /// Create or replace the PIN (resets attempts/lockout).
  static Future<void> setPin(String pin) async {
    _requireValidPin(pin);

    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await _storage.write(key: _kPinSalt, value: salt, aOptions: _aOpts, iOptions: _iOpts);
    await _storage.write(key: _kPinHash, value: hash, aOptions: _aOpts, iOptions: _iOpts);
    await _storage.write(key: _kAttempts, value: '0', aOptions: _aOpts, iOptions: _iOpts);
    await _storage.delete(key: _kLockoutUntil, aOptions: _aOpts, iOptions: _iOpts);
  }

  /// Does a PIN exist?
  static Future<bool> hasPin() async {
    return (await _storage.read(key: _kPinHash, aOptions: _aOpts, iOptions: _iOpts)) != null;
  }

  /// Remove the stored PIN (also clears attempts/lockout).
  static Future<void> clearPin() async {
    await _storage.delete(key: _kPinHash, aOptions: _aOpts, iOptions: _iOpts);
    await _storage.delete(key: _kPinSalt, aOptions: _aOpts, iOptions: _iOpts);
    await _storage.delete(key: _kAttempts, aOptions: _aOpts, iOptions: _iOpts);
    await _storage.delete(key: _kLockoutUntil, aOptions: _aOpts, iOptions: _iOpts);
  }

  /// Verify a PIN. Applies lockout/backoff on failures.
  ///
  /// Returns true if correct and not locked out; false otherwise.
  static Future<bool> verifyPin(String pin) async {
    // If currently locked, short-circuit.
    final rem = await lockoutRemaining();
    if (rem != null && rem > Duration.zero) return false;

    final salt = await _storage.read(key: _kPinSalt, aOptions: _aOpts, iOptions: _iOpts);
    final storedHash = await _storage.read(key: _kPinHash, aOptions: _aOpts, iOptions: _iOpts);
    if (salt == null || storedHash == null) return false;

    final ok = _hashPin(pin, salt) == storedHash;
    if (ok) {
      // Successful oath2.0 ⇒ reset counters.
      await _storage.write(key: _kAttempts, value: '0', aOptions: _aOpts, iOptions: _iOpts);
      await _storage.delete(key: _kLockoutUntil, aOptions: _aOpts, iOptions: _iOpts);
      return true;
    }

    // Failed attempt ⇒ increment and maybe lock.
    final currentAttempts =
        int.tryParse(await _storage.read(key: _kAttempts, aOptions: _aOpts, iOptions: _iOpts) ?? '0') ?? 0;
    final nextAttempts = currentAttempts + 1;
    await _storage.write(key: _kAttempts, value: '$nextAttempts', aOptions: _aOpts, iOptions: _iOpts);

    final secs = _lockoutSecondsFor(nextAttempts);
    if (secs > 0) {
      final until = DateTime.now().add(Duration(seconds: secs)).millisecondsSinceEpoch.toString();
      await _storage.write(key: _kLockoutUntil, value: until, aOptions: _aOpts, iOptions: _iOpts);
    }
    return false;
  }

  /// Change PIN by asking for [oldPin], then [newPin] and [confirmPin].
  ///
  /// Returns a [ChangePinResult] with success or a user-friendly error message.
  static Future<ChangePinResult> changePin({
    required String oldPin,
    required String newPin,
    required String confirmPin,
  }) async {
    // If locked, tell caller how long is left.
    final rem = await lockoutRemaining();
    if (rem != null && rem > Duration.zero) {
      final secs = rem.inSeconds;
      return ChangePinResult.error('Too many attempts. Try again in ${secs}s.');
    }

    if (newPin != confirmPin) {
      return ChangePinResult.error('New PIN and confirmation do not match.');
    }
    try {
      _requireValidPin(newPin);
    } catch (e) {
      return ChangePinResult.error(e.toString().replaceFirst('Exception: ', ''));
    }

    if (!await verifyPin(oldPin)) {
      return ChangePinResult.error('Old PIN is incorrect.');
    }
    if (oldPin == newPin) {
      return ChangePinResult.error('New PIN must be different from old PIN.');
    }

    await setPin(newPin);
    return ChangePinResult.ok();
  }

  /// Remaining lockout duration (or null if not locked).
  static Future<Duration?> lockoutRemaining() async {
    final untilStr = await _storage.read(key: _kLockoutUntil, aOptions: _aOpts, iOptions: _iOpts);
    if (untilStr == null) return null;

    final untilMs = int.tryParse(untilStr);
    if (untilMs == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = untilMs - now;
    if (diffMs <= 0) {
      await _storage.delete(key: _kLockoutUntil, aOptions: _aOpts, iOptions: _iOpts);
      return null;
    }
    return Duration(milliseconds: diffMs);
  }

  /// Reset failed attempts / lockout (call after a successful biometric oath2.0).
  static Future<void> markSuccessfulAuth() async {
    await _storage.write(key: _kAttempts, value: '0', aOptions: _aOpts, iOptions: _iOpts);
    await _storage.delete(key: _kLockoutUntil, aOptions: _aOpts, iOptions: _iOpts);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Biometrics toggle
  // ────────────────────────────────────────────────────────────────────────────
  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(
      key: _kBioEnabled,
      value: enabled ? '1' : '0',
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
  }

  static Future<bool> isBiometricsEnabled() async {
    return (await _storage.read(key: _kBioEnabled, aOptions: _aOpts, iOptions: _iOpts)) == '1';
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Safe migration for legacy plaintext PINs
  // ────────────────────────────────────────────────────────────────────────────
  static Future<bool> migrateLegacyPlaintextPin({String legacyKey = 'pin'}) async {
    try {
      final legacy = await _storage.read(key: legacyKey, aOptions: _aOpts, iOptions: _iOpts);
      if (legacy == null) return false;

      // Only migrate if it matches the current policy (exactly 6 digits)
      if (!_pinPattern.hasMatch(legacy)) {
        await _storage.delete(key: legacyKey, aOptions: _aOpts, iOptions: _iOpts);
        return false;
      }

      await setPin(legacy);
      await _storage.delete(key: legacyKey, aOptions: _aOpts, iOptions: _iOpts);
      return true;
    } catch (_) {
      try { await _storage.delete(key: legacyKey, aOptions: _aOpts, iOptions: _iOpts); } catch (_) {}
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Internals
  // ────────────────────────────────────────────────────────────────────────────
  static void _requireValidPin(String pin) {
    if (pin.length < minPinLen || pin.length > maxPinLen) {
      throw Exception('PIN must be $minPinLen–$maxPinLen digits.');
    }
    if (!_pinPattern.hasMatch(pin)) {
      throw Exception('PIN must contain digits only.');
    }
  }

  static String _generateSalt([int bytes = 16]) {
    final r = math.Random.secure();
    final b = List<int>.generate(bytes, (_) => r.nextInt(256));
    return base64Url.encode(b);
  }

  static String _hashPin(String pin, String salt) {
    final data = utf8.encode('$salt:$pin');
    final digest = sha256.convert(data);
    return digest.toString(); // hex
  }

  /// Exponential backoff after 5th failed attempt:
  /// 5th: 30s, 6th: 60s, 7th: 120s, ... capped at 900s (15 min).
  static int _lockoutSecondsFor(int attempts) {
    if (attempts < 5) return 0;
    final step = attempts - 5;
    final secs = 30 * (1 << step);
    return secs > 900 ? 900 : secs;
  }
}

/// Result type for changePin().
class ChangePinResult {
  final bool success;
  final String? error;

  const ChangePinResult._(this.success, this.error);

  factory ChangePinResult.ok() => const ChangePinResult._(true, null);

  factory ChangePinResult.error(String message) =>
      ChangePinResult._(false, message);
}
