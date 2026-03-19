import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AssetRemoteImage extends StatefulWidget {
  const AssetRemoteImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    required this.fit,
    required this.fallback,
    this.placeholder,
  });

  final String? url;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget fallback;
  final Widget? placeholder;

  @override
  State<AssetRemoteImage> createState() => _AssetRemoteImageState();
}

class _AssetRemoteImageState extends State<AssetRemoteImage> {
  late bool _trySvgFirst;

  @override
  void initState() {
    super.initState();
    _trySvgFirst = _looksLikeSvg(widget.url);
  }

  @override
  void didUpdateWidget(covariant AssetRemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _trySvgFirst = _looksLikeSvg(widget.url);
    }
  }

  bool _looksLikeSvg(String? rawUrl) {
    final url = (rawUrl ?? '').trim().toLowerCase();
    if (url.isEmpty) return false;
    if (url.endsWith('.svg') || url.contains('.svg?')) return true;

    const rasterMarkers = ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'];
    for (final marker in rasterMarkers) {
      if (url.endsWith(marker) || url.contains('$marker?')) {
        return false;
      }
    }

    return url.contains('/ipfs/');
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url?.trim() ?? '';
    if (url.isEmpty) return widget.fallback;

    if (_trySvgFirst) {
      return SvgPicture.network(
        url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholderBuilder: (_) =>
            widget.placeholder ??
            SizedBox(width: widget.width, height: widget.height),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) =>
          widget.placeholder ??
          SizedBox(width: widget.width, height: widget.height),
      errorWidget: (_, __, ___) => widget.fallback,
    );
  }
}
