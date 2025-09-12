// NOTE: We keep the filename for now to avoid breaking imports.
//       Internals are renamed to "transaction fee". A deprecated shim is provided.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

// ⬇️ Pulls the active wallet mnemonic / publicAddress
import 'package:next_fi/services/seed_storage.dart';

/// Stores and verifies a **Transaction Fee** configuration (separate from Stellar network fee).
/// Uses a signed payload {schema, version, address, fee_stroops} verified by a signer pubkey.
/// Falls back to safe defaults if verification fails. Includes automatic migration
/// from older "profit_*" storage keys.
final class TransactionFeeVaultSecureStorage {
  // ────────────────────────────────────────────────────────────────────────────
  // Storage keys (config cache) — new transaction-fee names
  static const String _kKeyAddr       = 'txfee_cfg_addr_v1';
  static const String _kKeyFeeStroops = 'txfee_cfg_fee_stroops_v1';

  // Storage keys (signed bundle) — new transaction-fee names
  static const String _kSignedPayloadB64 = 'txfee_cfg_signed_payload_b64_v1';
  static const String _kSignatureB64     = 'txfee_cfg_signature_b64_v1';
  static const String _kSignerPubKey     = 'txfee_cfg_signer_pub_v1';

  // Legacy "profit_*" keys for transparent migration
  static const String _LEG_kKeyAddr       = 'profit_cfg_addr_v1';
  static const String _LEG_kKeyFeeStroops = 'profit_cfg_fee_stroops_v1';
  static const String _LEG_kSignedPayloadB64 = 'profit_cfg_signed_payload_b64_v1';
  static const String _LEG_kSignatureB64     = 'profit_cfg_signature_b64_v1';
  static const String _LEG_kSignerPubKey     = 'profit_cfg_signer_pub_v1';

  // Built-in safe defaults (used if verification fails or no bundle available)
  static const String _DEFAULT_ADDR = 'GANLHIBDIZHWW6ZPKGCKXMBK2E4TS3Z6QHCPEMVKUOTYKMIZFZHQIBGU';
  static const int    _DEFAULT_FEE_STROOPS = 500000;
  static const int    _VERSION = 1;

  // Payload schema (fixed-fee) — updated name
  static const String _SCHEMA = 'TXFEECFG-FIXED-v1';

  final FlutterSecureStorage _storage;

  /// Dev helpers (optional): one-shot bootstrap using the ACTIVE wallet.
  final bool   devAutoInitFromActive;
  final double devInitFeeXlm;
  final String? devInitRecipientOverride;

  const TransactionFeeVaultSecureStorage({
    FlutterSecureStorage? storage,
    this.devAutoInitFromActive = false,
    this.devInitFeeXlm = 0.01,
    this.devInitRecipientOverride,
  }) : _storage = storage ?? const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  // ────────────────────────────────────────────────────────────────────────────
  /// Read a verified config (or defaults), and mirror to secure storage.
  /// Never throws. Migrates legacy profit_* keys if found.
  Future<TransactionFeeConfig> readOrInit() async {
    // Optionally bootstrap a *real* signed bundle from SeedStorage (DEV-only)
    if (devAutoInitFromActive) {
      await _maybeDevInitFromActiveWallet(
        feeXlm: devInitFeeXlm,
        recipientOverride: devInitRecipientOverride,
      );
    }

    // Attempt verify with new keys, then legacy keys; return defaults on failure.
    final verified = await _verifyOrDefault();

    // Normalize/persist verified values for quick reads & resilience
    try {
      final cachedAddr = await _storage.read(key: _kKeyAddr);
      final cachedFee  = await _storage.read(key: _kKeyFeeStroops);

      if (cachedAddr != verified.address) {
        await _storage.write(key: _kKeyAddr, value: verified.address);
      }
      final feeStr = verified.feeStroops.toString();
      if (cachedFee != feeStr) {
        await _storage.write(key: _kKeyFeeStroops, value: feeStr);
      }
    } catch (_) {/* ignore */}

    return verified;
  }

  // Convenience getters
  Future<String> getAddress() async => (await readOrInit()).address;
  Future<int>    getFeeStroops() async => (await readOrInit()).feeStroops;
  Future<double> getFeeXlm() async => (await readOrInit()).feeXlm;
  Future<String> getFeeXlmLabel() async => (await readOrInit()).feeXlmLabel;

  // ────────────────────────────────────────────────────────────────────────────
  // DEV: one-shot initializer using SeedStorage
  Future<bool> initSignedConfigFromActiveWallet({
    double feeXlm = 0.01,
    String? recipientOverride,
  }) async {
    return await _devInitFromActiveWallet(
      feeXlm: feeXlm,
      recipientOverride: recipientOverride,
    );
  }

  Future<void> _maybeDevInitFromActiveWallet({
    required double feeXlm,
    String? recipientOverride,
  }) async {
    // If we already have a signed bundle (new or legacy), do nothing
    final haveNew = await _hasAnySignedBundle(newKeys: true);
    final haveOld = await _hasAnySignedBundle(newKeys: false);
    if (haveNew || haveOld) return;

    await _devInitFromActiveWallet(
      feeXlm: feeXlm,
      recipientOverride: recipientOverride,
    );
  }

  Future<bool> _hasAnySignedBundle({required bool newKeys}) async {
    final payload = await _storage.read(
      key: newKeys ? _kSignedPayloadB64 : _LEG_kSignedPayloadB64,
    );
    final sig = await _storage.read(
      key: newKeys ? _kSignatureB64 : _LEG_kSignatureB64,
    );
    final signer = await _storage.read(
      key: newKeys ? _kSignerPubKey : _LEG_kSignerPubKey,
    );
    return payload != null && sig != null && signer != null;
  }

  Future<bool> _devInitFromActiveWallet({
    required double feeXlm,
    String? recipientOverride,
  }) async {
    try {
      // 1) Read mnemonic + (optional) saved publicAddress from SeedStorage
      final mnemonic = await SeedStorage.getActiveSeed();
      if (mnemonic == null || mnemonic.trim().isEmpty) return false;

      final meta = await SeedStorage.getActiveWalletMeta();
      String? recipient = recipientOverride?.trim();
      recipient ??= meta?.publicAddress?.trim();

      // 2) Derive signer keypair from active wallet (index 0)
      final wallet = await Wallet.from(mnemonic);
      final signerKp = await wallet.getKeyPair(index: 0);
      final signerPub = signerKp.accountId;

      // If recipient was not set/saved, use signer pub as default recipient
      recipient ??= signerPub;

      // Basic address sanity
      KeyPair.fromAccountId(recipient);

      // 3) Build payload and sign
      final feeStroops = (feeXlm * 1e7).round();
      final payloadMap = <String, dynamic>{
        'schema': _SCHEMA,
        'version': _VERSION,
        'address': recipient,
        'fee_stroops': feeStroops,
      };
      final payloadJson  = jsonEncode(payloadMap);
      final payloadBytes = utf8.encode(payloadJson);
      final sigBytes     = signerKp.sign(payloadBytes);

      // 4) Persist signed bundle (NEW keys)
      await _storage.write(key: _kSignedPayloadB64, value: base64Encode(payloadBytes));
      await _storage.write(key: _kSignatureB64,     value: base64Encode(sigBytes));
      await _storage.write(key: _kSignerPubKey,     value: signerPub);

      if (kDebugMode) {
        // Also mirror the readable fields for convenience
        await _storage.write(key: _kKeyAddr,       value: recipient);
        await _storage.write(key: _kKeyFeeStroops, value: feeStroops.toString());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Verification (non-fatal): returns defaults if anything fails. Also migrates legacy keys.
  Future<TransactionFeeConfig> _verifyOrDefault() async {
    try {
      // Try NEW txfee bundle first; fallback to legacy profit bundle.
      String? signerPub   = await _storage.read(key: _kSignerPubKey);
      String? payloadB64  = await _storage.read(key: _kSignedPayloadB64);
      String? signatureB64= await _storage.read(key: _kSignatureB64);

      bool usingLegacy = false;
      if (signerPub == null || payloadB64 == null || signatureB64 == null) {
        signerPub    = await _storage.read(key: _LEG_kSignerPubKey);
        payloadB64   = await _storage.read(key: _LEG_kSignedPayloadB64);
        signatureB64 = await _storage.read(key: _LEG_kSignatureB64);
        usingLegacy  = (signerPub != null && payloadB64 != null && signatureB64 != null);
      }

      if (signerPub == null || payloadB64 == null || signatureB64 == null) {
        // No bundle present → defaults
        return const TransactionFeeConfig(
          address: _DEFAULT_ADDR,
          feeStroops: _DEFAULT_FEE_STROOPS,
          version: _VERSION,
        );
      }

      final payloadBytes = base64Decode(payloadB64);
      final sigBytes     = base64Decode(signatureB64);

      // Verify signature
      final signer = KeyPair.fromAccountId(signerPub);
      if (!signer.verify(payloadBytes, sigBytes)) {
        return const TransactionFeeConfig(
          address: _DEFAULT_ADDR,
          feeStroops: _DEFAULT_FEE_STROOPS,
          version: _VERSION,
        );
      }

      // Parse & validate payload
      final map       = json.decode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
      final schema    = (map['schema'] as String?)?.trim();
      final version   = (map['version'] as int?) ?? 0;
      final addr      = (map['address'] as String?)?.trim() ?? '';
      final feeStrps  = (map['fee_stroops'] as num?)?.toInt() ?? -1;

      if (schema != _SCHEMA || version < 1 || addr.isEmpty || feeStrps < 0) {
        return const TransactionFeeConfig(
          address: _DEFAULT_ADDR,
          feeStroops: _DEFAULT_FEE_STROOPS,
          version: _VERSION,
        );
      }

      // Validate Stellar address format
      KeyPair.fromAccountId(addr);

      // Clamp fee to a sane range (0..10 XLM)
      final feeClamped = feeStrps < 0 ? 0 : (feeStrps > 100000000 ? 100000000 : feeStrps);

      // If we verified from legacy keys, migrate them to new keys for future reads.
      if (usingLegacy) {
        try {
          await _storage.write(key: _kSignerPubKey,     value: signerPub);
          await _storage.write(key: _kSignedPayloadB64, value: payloadB64);
          await _storage.write(key: _kSignatureB64,     value: signatureB64);

          // Migrate cached mirrors if present
          final oldAddr = await _storage.read(key: _LEG_kKeyAddr);
          final oldFee  = await _storage.read(key: _LEG_kKeyFeeStroops);
          if (oldAddr != null) await _storage.write(key: _kKeyAddr, value: oldAddr);
          if (oldFee  != null) await _storage.write(key: _kKeyFeeStroops, value: oldFee);
        } catch (_) {/* ignore */}
      }

      return TransactionFeeConfig(address: addr, feeStroops: feeClamped, version: version);
    } catch (_) {
      return const TransactionFeeConfig(
        address: _DEFAULT_ADDR,
        feeStroops: _DEFAULT_FEE_STROOPS,
        version: _VERSION,
      );
    }
  }
}

/// Value object for **Transaction Fee** config.
class TransactionFeeConfig {
  final String address;
  final int feeStroops;
  final int version;

  const TransactionFeeConfig({
    required this.address,
    required this.feeStroops,
    required this.version,
  });

  double get feeXlm => feeStroops / 1e7;
  String get feeXlmLabel => '${feeXlm.toStringAsFixed(7)} XLM';
}
