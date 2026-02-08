// NOTE: We keep the filename for now to avoid breaking imports.
//       Internals are renamed to "transaction fee". A deprecated shim is provided.

import 'dart:convert';
import 'dart:math' show min, max;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

// ⬇️ Pulls the active wallet mnemonic / publicAddress
import 'package:next_fi/services/seed_storage.dart';
// ⬇️ NEW: Import CurrencyVM to get live USDC price
import 'package:next_fi/reusable_view_model/currency_vm.dart';

/// Stores and verifies a **Transaction Fee** configuration (separate from Stellar network fee).
/// Uses a signed payload {schema, version, address, fee_usd} verified by a signer pubkey.
/// **NEW**: Dynamically calculates fee in stroops based on current USDC price.
/// Falls back to safe defaults if verification fails. Includes automatic migration
/// from older "profit_*" storage keys.
class TransactionFeeVaultSecureStorage {
  // ────────────────────────────────────────────────────────────────────────────
  // Storage keys (config cache) — new transaction-fee names (v2)
  static const String _kKeyAddr    = 'txfee_cfg_addr_v2';
  static const String _kKeyFeeUsd  = 'txfee_cfg_fee_usd_v2';

  // Storage keys (signed bundle) — new transaction-fee names (v2 schema)
  static const String _kSignedPayloadB64 = 'txfee_cfg_signed_payload_b64_v2';
  static const String _kSignatureB64     = 'txfee_cfg_signature_b64_v2';
  static const String _kSignerPubKey     = 'txfee_cfg_signer_pub_v2';

  // Legacy v1 keys (fee_stroops based)
  static const String _LEG_v1_kKeyAddr          = 'txfee_cfg_addr_v1';
  static const String _LEG_v1_kKeyFeeStroops    = 'txfee_cfg_fee_stroops_v1';
  static const String _LEG_v1_kSignedPayloadB64 = 'txfee_cfg_signed_payload_b64_v1';
  static const String _LEG_v1_kSignatureB64     = 'txfee_cfg_signature_b64_v1';
  static const String _LEG_v1_kSignerPubKey     = 'txfee_cfg_signer_pub_v1';

  // Legacy "profit_*" keys for transparent migration
  static const String _LEG_kKeyAddr          = 'profit_cfg_addr_v1';
  static const String _LEG_kKeyFeeStroops    = 'profit_cfg_fee_stroops_v1';
  static const String _LEG_kSignedPayloadB64 = 'profit_cfg_signed_payload_b64_v1';
  static const String _LEG_kSignatureB64     = 'profit_cfg_signature_b64_v1';
  static const String _LEG_kSignerPubKey     = 'profit_cfg_signer_pub_v1';

  // Built-in safe defaults (used if verification fails or no bundle available)
  static const String _DEFAULT_ADDR = 'GC77YDSLSYFVH5BMEANWEOWOKAAZDLBCST25VSS5XLITS3VEYLZ4YDUE';
  static const double _DEFAULT_FEE_USD = 0.05; // $0.05 USD equivalent
  static const int    _VERSION = 2;

  // Payload schema (dynamic USD-based) — updated name
  static const String _SCHEMA = 'TXFEECFG-DYNAMIC-USD-v2';
  static const String _SCHEMA_V1 = 'TXFEECFG-FIXED-v1';

  final FlutterSecureStorage _storage;
  final CurrencyVM? _currencyVM; // NEW: for live USDC price

  /// Dev helpers (optional): one-shot bootstrap using the ACTIVE wallet.
  final bool   devAutoInitFromActive;
  final double devInitFeeUsd;
  final String? devInitRecipientOverride;

  TransactionFeeVaultSecureStorage({
    FlutterSecureStorage? storage,
    CurrencyVM? currencyVM, // NEW: inject CurrencyVM
    this.devAutoInitFromActive = false,
    this.devInitFeeUsd = 0.01,
    this.devInitRecipientOverride,
  }) : _storage = storage ??
      const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          resetOnError: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      ),
        _currencyVM = currencyVM;

  // ────────────────────────────────────────────────────────────────────────────
  /// Read a verified config (or defaults), and mirror to secure storage.
  /// Never throws. Migrates legacy profit_* keys if found.
  /// **NEW**: Dynamically calculates stroops based on current USDC price.
  Future<TransactionFeeConfig> readOrInit() async {
    // Optionally bootstrap a *real* signed bundle from SeedStorage (DEV-only)
    if (devAutoInitFromActive) {
      await _maybeDevInitFromActiveWallet(
        feeUsd: devInitFeeUsd,
        recipientOverride: devInitRecipientOverride,
      );
    }

    // Attempt verify with new keys, then legacy keys; return defaults on failure.
    final verified = await _verifyOrDefault();

    // Normalize/persist verified values for quick reads & resilience
    try {
      final cachedAddr = await _storage.read(key: _kKeyAddr);
      final cachedFee  = await _storage.read(key: _kKeyFeeUsd);

      if (cachedAddr != verified.address) {
        await _storage.write(key: _kKeyAddr, value: verified.address);
      }
      final feeStr = verified.feeUsd.toString();
      if (cachedFee != feeStr) {
        await _storage.write(key: _kKeyFeeUsd, value: feeStr);
      }
    } catch (_) {/* ignore */}

    return verified;
  }

  // Convenience getters - **NEW**: Now dynamically calculate stroops
  Future<String> getAddress() async => (await readOrInit()).address;
  Future<double> getFeeUsd() async => (await readOrInit()).feeUsd;

  /// **NEW**: Dynamically calculate fee in stroops based on current USDC price
  Future<int> getFeeStroops() async {
    final config = await readOrInit();
    return await _calculateDynamicFeeStroops(config.feeUsd);
  }

  /// **NEW**: Get fee in XLM based on current USDC price
  Future<double> getFeeXlm() async {
    final stroops = await getFeeStroops();
    return stroops / 1e7;
  }

  /// **NEW**: Get formatted fee label with XLM amount
  Future<String> getFeeXlmLabel() async {
    final xlm = await getFeeXlm();
    return '${xlm.toStringAsFixed(7)} XLM';
  }

  /// **NEW**: Get formatted fee label with USD amount
  Future<String> getFeeUsdLabel() async {
    final usd = await getFeeUsd();
    return '\$${usd.toStringAsFixed(2)} USD';
  }

  // ────────────────────────────────────────────────────────────────────────────
  // **NEW**: Dynamic fee calculation based on USDC price
  Future<int> _calculateDynamicFeeStroops(double feeUsd) async {
    // Get current USDC price from CurrencyVM
    final usdcPrice = _currencyVM?.usdcRate ?? 1.0;

    // If no valid price, use 1:1 ratio (USDC ≈ USD)
    if (usdcPrice <= 0) {
      return (feeUsd * 1e7).round();
    }

    // Calculate: fee_usdc = fee_usd / usdc_price
    // Then convert to stroops: fee_stroops = fee_usdc * 1e7
    final feeUsdc = feeUsd / usdcPrice;
    final feeStroops = (feeUsdc * 1e7).round();

    // Clamp to sane range (0..10 XLM = 0..100M stroops)
    return min(max(feeStroops, 0), 100000000);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DEV: one-shot initializer using SeedStorage
  Future<bool> initSignedConfigFromActiveWallet({
    double feeUsd = 0.01,
    String? recipientOverride,
  }) async {
    return _devInitFromActiveWallet(
      feeUsd: feeUsd,
      recipientOverride: recipientOverride,
    );
  }

  Future<void> _maybeDevInitFromActiveWallet({
    required double feeUsd,
    String? recipientOverride,
  }) async {
    // If we already have a signed bundle (new or legacy), do nothing
    final haveNew = await _hasAnySignedBundle(newKeys: true);
    final haveV1  = await _hasAnySignedBundle(v1Keys: true);
    final haveOld = await _hasAnySignedBundle(newKeys: false);
    if (haveNew || haveV1 || haveOld) return;

    await _devInitFromActiveWallet(
      feeUsd: feeUsd,
      recipientOverride: recipientOverride,
    );
  }

  Future<bool> _hasAnySignedBundle({
    bool newKeys = false,
    bool v1Keys = false,
  }) async {
    String payloadKey, sigKey, signerKey;

    if (v1Keys) {
      payloadKey = _LEG_v1_kSignedPayloadB64;
      sigKey = _LEG_v1_kSignatureB64;
      signerKey = _LEG_v1_kSignerPubKey;
    } else if (newKeys) {
      payloadKey = _kSignedPayloadB64;
      sigKey = _kSignatureB64;
      signerKey = _kSignerPubKey;
    } else {
      payloadKey = _LEG_kSignedPayloadB64;
      sigKey = _LEG_kSignatureB64;
      signerKey = _LEG_kSignerPubKey;
    }

    final payload = await _storage.read(key: payloadKey);
    final sig = await _storage.read(key: sigKey);
    final signer = await _storage.read(key: signerKey);
    return payload != null && sig != null && signer != null;
  }

  /// Dev bootstrap:
  /// - Signs with the active **Stellar secret seed** if available (S… 56 chars).
  /// - If we cannot sign, returns false quietly (no bundle written).
  /// **UPDATED**: Now uses fee_usd instead of fee_stroops
  Future<bool> _devInitFromActiveWallet({
    required double feeUsd,
    String? recipientOverride,
  }) async {
    try {
      // 1) Read seed and metadata from SeedStorage
      final rawSeedOrMnemonic = (await SeedStorage.getActiveSeed())?.trim();
      final meta = await SeedStorage.getActiveWalletMeta();

      // Determine signer (private key) only if we actually have a Stellar secret seed.
      KeyPair? signerKp;
      if (rawSeedOrMnemonic != null &&
          rawSeedOrMnemonic.startsWith('S') &&
          rawSeedOrMnemonic.length == 56) {
        // Looks like a Stellar secret seed
        signerKp = KeyPair.fromSecretSeed(rawSeedOrMnemonic);
      }

      // Determine recipient address preference:
      // 1) explicit override, 2) saved publicAddress, 3) signer pub (if we have one)
      String? recipient = recipientOverride?.trim();
      recipient ??= meta?.publicAddress?.trim();
      recipient ??= signerKp?.accountId;

      if (recipient == null || recipient.isEmpty) {
        // Cannot determine a valid recipient; abort dev init
        return false;
      }

      // Basic address sanity
      KeyPair.fromAccountId(recipient);

      // 2) Build payload **NEW**: with fee_usd instead of fee_stroops
      final payloadMap = <String, dynamic>{
        'schema': _SCHEMA,
        'version': _VERSION,
        'address': recipient,
        'fee_usd': feeUsd,
      };
      final payloadJson  = jsonEncode(payloadMap);
      final payloadBytes = utf8.encode(payloadJson);

      // 3) Sign if we can; if not, do not write an unverifiable bundle.
      if (signerKp == null) {
        if (kDebugMode) {
          // Still mirror human-readable fields to help developers see intent,
          // but skip writing a (useless) unsigned bundle.
          await _storage.write(key: _kKeyAddr,   value: recipient);
          await _storage.write(key: _kKeyFeeUsd, value: feeUsd.toString());
        }
        return false;
      }

      final sigBytes = signerKp.sign(payloadBytes);

      // 4) Persist signed bundle (NEW v2 keys)
      await _storage.write(key: _kSignedPayloadB64, value: base64Encode(payloadBytes));
      await _storage.write(key: _kSignatureB64,     value: base64Encode(sigBytes));
      await _storage.write(key: _kSignerPubKey,     value: signerKp.accountId);

      if (kDebugMode) {
        // Also mirror the readable fields for convenience
        await _storage.write(key: _kKeyAddr,   value: recipient);
        await _storage.write(key: _kKeyFeeUsd, value: feeUsd.toString());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Verification (non-fatal): returns defaults if anything fails. Also migrates legacy keys.
  // **UPDATED**: Now handles both v2 (fee_usd) and v1 (fee_stroops) schemas
  Future<TransactionFeeConfig> _verifyOrDefault() async {
    try {
      // Try NEW v2 bundle first, then v1, then legacy profit bundle.
      String? signerPub    = await _storage.read(key: _kSignerPubKey);
      String? payloadB64   = await _storage.read(key: _kSignedPayloadB64);
      String? signatureB64 = await _storage.read(key: _kSignatureB64);

      bool usingV1 = false;
      bool usingLegacy = false;

      if (signerPub == null || payloadB64 == null || signatureB64 == null) {
        // Try v1 keys
        signerPub    = await _storage.read(key: _LEG_v1_kSignerPubKey);
        payloadB64   = await _storage.read(key: _LEG_v1_kSignedPayloadB64);
        signatureB64 = await _storage.read(key: _LEG_v1_kSignatureB64);
        usingV1 = (signerPub != null && payloadB64 != null && signatureB64 != null);

        if (!usingV1) {
          // Try legacy profit keys
          signerPub    = await _storage.read(key: _LEG_kSignerPubKey);
          payloadB64   = await _storage.read(key: _LEG_kSignedPayloadB64);
          signatureB64 = await _storage.read(key: _LEG_kSignatureB64);
          usingLegacy  = (signerPub != null && payloadB64 != null && signatureB64 != null);
        }
      }

      if (signerPub == null || payloadB64 == null || signatureB64 == null) {
        // No bundle present → defaults
        return const TransactionFeeConfig(
          address: _DEFAULT_ADDR,
          feeUsd: _DEFAULT_FEE_USD,
          version: _VERSION,
        );
      }

      final payloadBytes = base64Decode(payloadB64);
      final sigBytes     = base64Decode(signatureB64);

      // Verify signature
      final signer = KeyPair.fromAccountId(signerPub);
      final ok = signer.verify(payloadBytes, sigBytes);
      if (!ok) {
        return const TransactionFeeConfig(
          address: _DEFAULT_ADDR,
          feeUsd: _DEFAULT_FEE_USD,
          version: _VERSION,
        );
      }

      // Parse & validate payload
      final map     = json.decode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
      final schema  = (map['schema'] as String?)?.trim();
      final version = (map['version'] as int?) ?? 0;
      final addr    = (map['address'] as String?)?.trim() ?? '';

      // **NEW**: Handle both v2 (fee_usd) and v1 (fee_stroops) schemas
      double feeUsd;

      if (schema == _SCHEMA && version >= 2) {
        // v2 schema: fee_usd
        feeUsd = (map['fee_usd'] as num?)?.toDouble() ?? -1.0;
      } else if (schema == _SCHEMA_V1 || usingV1 || usingLegacy) {
        // v1 or legacy schema: fee_stroops → convert to approximate USD
        final feeStroops = (map['fee_stroops'] as num?)?.toInt() ?? -1;
        if (feeStroops < 0) {
          feeUsd = -1.0;
        } else {
          // Approximate conversion: assume 1 USDC ≈ $1 and current XLM price
          // For migration, use a reasonable default conversion or current price
          final feeXlm = feeStroops / 1e7;
          // Use current XLM rate if available, otherwise assume $0.10/XLM as safe fallback
          final xlmPrice = _currencyVM?.xlmRate ?? 0.10;
          feeUsd = feeXlm * xlmPrice;
        }
      } else {
        feeUsd = -1.0;
      }

      if (schema == null || version < 1 || addr.isEmpty || feeUsd < 0) {
        return const TransactionFeeConfig(
          address: _DEFAULT_ADDR,
          feeUsd: _DEFAULT_FEE_USD,
          version: _VERSION,
        );
      }

      // Validate Stellar address format
      KeyPair.fromAccountId(addr);

      // Clamp fee to a sane range ($0.001 to $10 USD)
      final feeClamped = min(max(feeUsd, 0.001), 10.0);

      // If we verified from legacy keys, migrate them to new v2 keys for future reads.
      if (usingLegacy || usingV1) {
        try {
          // Copy the bundle (can't re-sign without private key)
          await _storage.write(key: _kSignerPubKey,     value: signerPub);
          await _storage.write(key: _kSignedPayloadB64, value: payloadB64);
          await _storage.write(key: _kSignatureB64,     value: signatureB64);

          // Migrate cached mirrors
          await _storage.write(key: _kKeyAddr,   value: addr);
          await _storage.write(key: _kKeyFeeUsd, value: feeClamped.toString());
        } catch (_) {/* ignore */}
      }

      return TransactionFeeConfig(
        address: addr,
        feeUsd: feeClamped,
        version: version,
      );
    } catch (_) {
      return const TransactionFeeConfig(
        address: _DEFAULT_ADDR,
        feeUsd: _DEFAULT_FEE_USD,
        version: _VERSION,
      );
    }
  }
}

/// Value object for **Transaction Fee** config.
/// **UPDATED**: Now stores fee_usd instead of fee_stroops
class TransactionFeeConfig {
  final String address;
  final double feeUsd;
  final int version;

  const TransactionFeeConfig({
    required this.address,
    required this.feeUsd,
    required this.version,
  });

  /// **DEPRECATED**: Use TransactionFeeVaultSecureStorage.getFeeStroops() for dynamic pricing
  /// This getter assumes 1:1 USDC/USD which may not be accurate
  @Deprecated('Use TransactionFeeVaultSecureStorage.getFeeStroops() for dynamic pricing')
  int get feeStroops => (feeUsd * 1e7).round();

  /// **DEPRECATED**: Use TransactionFeeVaultSecureStorage.getFeeXlm() for dynamic pricing
  @Deprecated('Use TransactionFeeVaultSecureStorage.getFeeXlm() for dynamic pricing')
  double get feeXlm => feeStroops / 1e7;

  /// **DEPRECATED**: Use TransactionFeeVaultSecureStorage.getFeeXlmLabel() for dynamic pricing
  @Deprecated('Use TransactionFeeVaultSecureStorage.getFeeXlmLabel() for dynamic pricing')
  String get feeXlmLabel => '${feeXlm.toStringAsFixed(7)} XLM';

  /// Get USD fee amount
  String get feeUsdLabel => '\$${feeUsd.toStringAsFixed(2)} USD';
}