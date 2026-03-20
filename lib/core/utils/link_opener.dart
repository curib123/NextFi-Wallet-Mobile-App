import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkOpener {
  static Future<void> open(
    BuildContext context,
    String url, {
    bool external = true,
    String? fallbackLabel,
  }) async {
    if (url.isEmpty) {
      _toast(context, 'No link available');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      final deep = Uri.tryParse(url);
      if (deep == null) {
        _toast(context, 'Invalid link');
        return;
      }
      final ok = await launchUrl(deep, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;
      if (!ok) _copyFallback(context, url, label: fallbackLabel);
      return;
    }

    final mode = external
        ? LaunchMode.externalApplication
        : LaunchMode.platformDefault;

    final ok = await launchUrl(uri, mode: mode);
    if (!context.mounted) return;
    if (!ok) _copyFallback(context, url, label: fallbackLabel);
  }

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

  static void _copyFallback(
    BuildContext context,
    String url, {
    String? label,
  }) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
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
