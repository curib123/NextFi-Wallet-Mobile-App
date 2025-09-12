import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:provider/provider.dart';

import 'asset_logo.dart';

class AvatarWithAssetLogo extends StatelessWidget {
  const AvatarWithAssetLogo({
    super.key,
    required this.isIncoming,
    required this.asset,
    this.recName,
    this.recColor,
  });

  final bool isIncoming;
  final String asset;
  final String? recName;
  final int? recColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    Widget baseAvatar;
    if (recName != null && recColor != null) {
      final bg = Color(recColor!);
      final initial = recName!.trim().isNotEmpty
          ? recName!.trim().characters.first.toUpperCase()
          : '•';
      baseAvatar = CircleAvatar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
      );
    } else {
      baseAvatar = CircleAvatar(
        backgroundColor:
        (isIncoming ? colors.success : colors.error).withOpacity(0.15),
        child: Icon(
          isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncoming ? colors.success : colors.error,
        ),
      );
    }

    const double outer = 40;
    const double logoSize = 16;

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: SizedBox(width: outer, height: outer, child: baseAvatar),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary.withOpacity(0.12)),
              ),
              padding: const EdgeInsets.all(1.5),
              child: AssetLogo(asset: asset, size: logoSize),
            ),
          ),
        ],
      ),
    );
  }
}
