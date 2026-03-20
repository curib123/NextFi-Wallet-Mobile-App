import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const AndroidOptions _aOpts = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );
  static const IOSOptions _iOpts = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  static Future<void> save(String key, String value) {
    return _storage.write(
      key: key,
      value: value,
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
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

  static Future<bool> ensureReady() async {
    try {
      await _storage.write(
        key: '__probe__',
        value: '1',
        aOptions: _aOpts,
        iOptions: _iOpts,
      );
      final v = await _storage.read(
        key: '__probe__',
        aOptions: _aOpts,
        iOptions: _iOpts,
      );
      await _storage.delete(
        key: '__probe__',
        aOptions: _aOpts,
        iOptions: _iOpts,
      );
      return v == '1';
    } catch (_) {
      return false;
    }
  }

  static const String _kPinHash = 'pin_hash_v2';
  static const String _kPinSalt = 'pin_salt_v2';
  static const String _kAttempts = 'pin_failed_attempts';
  static const String _kLockoutUntil = 'pin_lockout_until';
  static const String _kBioEnabled = 'biometrics_enabled';

  static const int minPinLen = 6;
  static const int maxPinLen = 6;
  static final RegExp _pinPattern = RegExp(r'^\d{6}$');

  static Future<void> setPin(String pin) async {
    _requireValidPin(pin);

    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await _storage.write(
      key: _kPinSalt,
      value: salt,
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
    await _storage.write(
      key: _kPinHash,
      value: hash,
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
    await _storage.write(
      key: _kAttempts,
      value: '0',
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
    await _storage.delete(
      key: _kLockoutUntil,
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
  }

  static Future<bool> hasPin() async {
    return (await _storage.read(
          key: _kPinHash,
          aOptions: _aOpts,
          iOptions: _iOpts,
        )) !=
        null;
  }

  static Future<void> clearPin() async {
    await _storage.delete(key: _kPinHash, aOptions: _aOpts, iOptions: _iOpts);
    await _storage.delete(key: _kPinSalt, aOptions: _aOpts, iOptions: _iOpts);
    await _storage.delete(key: _kAttempts, aOptions: _aOpts, iOptions: _iOpts);
    await _storage.delete(
      key: _kLockoutUntil,
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
  }

  static Future<bool> verifyPin(String pin) async {
    final rem = await lockoutRemaining();
    if (rem != null && rem > Duration.zero) return false;

    final salt = await _storage.read(
      key: _kPinSalt,
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
    final storedHash = await _storage.read(
      key: _kPinHash,
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
    if (salt == null || storedHash == null) return false;

    final ok = _hashPin(pin, salt) == storedHash;
    if (ok) {
      await _storage.write(
        key: _kAttempts,
        value: '0',
        aOptions: _aOpts,
        iOptions: _iOpts,
      );
      await _storage.delete(
        key: _kLockoutUntil,
        aOptions: _aOpts,
        iOptions: _iOpts,
      );
      return true;
    }

    final currentAttempts =
        int.tryParse(
          await _storage.read(
                key: _kAttempts,
                aOptions: _aOpts,
                iOptions: _iOpts,
              ) ??
              '0',
        ) ??
        0;
    final nextAttempts = currentAttempts + 1;
    await _storage.write(
      key: _kAttempts,
      value: '$nextAttempts',
      aOptions: _aOpts,
      iOptions: _iOpts,
    );

    final secs = _lockoutSecondsFor(nextAttempts);
    if (secs > 0) {
      final until = DateTime.now()
          .add(Duration(seconds: secs))
          .millisecondsSinceEpoch
          .toString();
      await _storage.write(
        key: _kLockoutUntil,
        value: until,
        aOptions: _aOpts,
        iOptions: _iOpts,
      );
    }
    return false;
  }

  static Future<ChangePinResult> changePin({
    required String oldPin,
    required String newPin,
    required String confirmPin,
  }) async {
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
      return ChangePinResult.error(
        e.toString().replaceFirst('Exception: ', ''),
      );
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

  static Future<Duration?> lockoutRemaining() async {
    final untilStr = await _storage.read(
      key: _kLockoutUntil,
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
    if (untilStr == null) return null;

    final untilMs = int.tryParse(untilStr);
    if (untilMs == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = untilMs - now;
    if (diffMs <= 0) {
      await _storage.delete(
        key: _kLockoutUntil,
        aOptions: _aOpts,
        iOptions: _iOpts,
      );
      return null;
    }
    return Duration(milliseconds: diffMs);
  }

  static Future<void> markSuccessfulAuth() async {
    await _storage.write(
      key: _kAttempts,
      value: '0',
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
    await _storage.delete(
      key: _kLockoutUntil,
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
  }

  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(
      key: _kBioEnabled,
      value: enabled ? '1' : '0',
      aOptions: _aOpts,
      iOptions: _iOpts,
    );
  }

  static Future<bool> isBiometricsEnabled() async {
    return (await _storage.read(
          key: _kBioEnabled,
          aOptions: _aOpts,
          iOptions: _iOpts,
        )) ==
        '1';
  }

  static Future<bool> migrateLegacyPlaintextPin({
    String legacyKey = 'pin',
  }) async {
    try {
      final legacy = await _storage.read(
        key: legacyKey,
        aOptions: _aOpts,
        iOptions: _iOpts,
      );
      if (legacy == null) return false;

      if (!_pinPattern.hasMatch(legacy)) {
        await _storage.delete(
          key: legacyKey,
          aOptions: _aOpts,
          iOptions: _iOpts,
        );
        return false;
      }

      await setPin(legacy);
      await _storage.delete(key: legacyKey, aOptions: _aOpts, iOptions: _iOpts);
      return true;
    } catch (_) {
      try {
        await _storage.delete(
          key: legacyKey,
          aOptions: _aOpts,
          iOptions: _iOpts,
        );
      } catch (_) {}
      return false;
    }
  }

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
    return digest.toString();
  }

  static int _lockoutSecondsFor(int attempts) {
    if (attempts < 5) return 0;
    final step = attempts - 5;
    final secs = 30 * (1 << step);
    return secs > 900 ? 900 : secs;
  }
}

class ChangePinResult {
  final bool success;
  final String? error;

  const ChangePinResult._(this.success, this.error);

  factory ChangePinResult.ok() => const ChangePinResult._(true, null);

  factory ChangePinResult.error(String message) =>
      ChangePinResult._(false, message);
}
