import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Provider/asset_vm.dart';

class AssetLogo extends StatelessWidget {
  const AssetLogo({super.key, required this.asset, required this.size});

  final String asset;
  final double size;

  static const String _fallbackXlmLogo =
      'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png';

  @override
  Widget build(BuildContext context) {
    String url = _fallbackXlmLogo;
    try {
      final ap = context.read<AssetProvider>();
      url = ap.logoFor(asset);
    } catch (_) {}

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration:
            const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
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
