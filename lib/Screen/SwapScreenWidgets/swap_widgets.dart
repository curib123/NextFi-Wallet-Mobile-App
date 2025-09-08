
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Provider/AssetProvider.dart';


/* ======================= Shared: token logo (via AssetProvider) ======================= */

class AssetLogo extends StatelessWidget {
  final String asset; // 'XLM' or 'USDC' (case-insensitive is fine)
  final double size;
  final double radius;
  const AssetLogo({
    super.key,
    required this.asset,
    required this.size,
    this.radius = 999,
  });

  static const String _fallbackXlm =
      'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png';

  @override
  Widget build(BuildContext context) {
    // Resolve logo URL via provider with graceful fallback.
    String url = _fallbackXlm;
    try {
      final ap = context.read<AssetProvider>();
      url = ap.logoFor(asset);
    } catch (_) {
      // Provider not found; keep fallback.
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          // Fallback to an initial if image fails
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
            child: Text(
              asset.isNotEmpty ? asset.characters.first.toUpperCase() : '•',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          );
        },
      ),
    );
  }
}
