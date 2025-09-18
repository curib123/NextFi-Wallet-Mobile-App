import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple helper for opening links (and common explorer links).
/// Defaults to opening in the external browser.
class LinkOpener {
  /// Opens a raw [url]. If it can't launch, copies to clipboard and notifies.
  static Future<void> open(
      BuildContext context,
      String url, {
        bool external = true,
        String? fallbackLabel, // e.g., "Explorer link"
      }) async {
    if (url.isEmpty) {
      _toast(context, 'No link available');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      // Allow deep-link schemes too (e.g., app://) — try anyway if parse ok.
      final deep = Uri.tryParse(url);
      if (deep == null) {
        _toast(context, 'Invalid link');
        return;
      }
      final ok = await launchUrl(deep, mode: LaunchMode.externalApplication);
      if (!ok) _copyFallback(context, url, label: fallbackLabel);
      return;
    }

    final mode = external
        ? LaunchMode.externalApplication
        : LaunchMode.platformDefault; // may open in-app if supported

    final ok = await launchUrl(uri, mode: mode);
    if (!ok) _copyFallback(context, url, label: fallbackLabel);
  }

  /// Opens a Stellar Expert transaction page by [hash].
  static Future<void> openStellarTx(
      BuildContext context, {
        required String hash,
        bool isTestnet = false,
      }) async {
    if (hash.isEmpty) {
      _toast(context, 'No transaction hash');
      return;
    }
    final url =
        'https://stellar.expert/explorer/${isTestnet ? 'testnet' : 'public'}/tx/$hash';
    await open(context, url, fallbackLabel: 'Explorer link');
  }

  /// Opens a Stellar Expert account page by [address] (G...).
  static Future<void> openStellarAccount(
      BuildContext context, {
        required String address,
        bool isTestnet = false,
      }) async {
    if (address.isEmpty) {
      _toast(context, 'No account address');
      return;
    }
    final url =
        'https://stellar.expert/explorer/${isTestnet ? 'testnet' : 'public'}/account/$address';
    await open(context, url, fallbackLabel: 'Explorer link');
  }

  static void _copyFallback(BuildContext context, String url, {String? label}) async {
    await Clipboard.setData(ClipboardData(text: url));
    _toast(context, '${label ?? "Link"} copied to clipboard');
  }

  static void _toast(BuildContext context, String msg) {
    showFloatingSnackBar(
      context,
      message: msg,
      type: SnackBarType.info,
      position: SnackBarPosition.top,
    );
  }
}
