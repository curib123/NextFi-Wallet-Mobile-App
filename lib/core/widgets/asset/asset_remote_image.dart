import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

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
  static final Map<String, Future<bool>> _svgDetectionCache =
      <String, Future<bool>>{};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant AssetRemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  bool _looksLikeSvgByUrl(String? rawUrl) {
    final url = (rawUrl ?? '').trim().toLowerCase();
    if (url.isEmpty) return false;
    if (url.endsWith('.svg') || url.contains('.svg?')) return true;

    const rasterMarkers = ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'];
    for (final marker in rasterMarkers) {
      if (url.endsWith(marker) || url.contains('$marker?')) {
        return false;
      }
    }

    return false;
  }

  Future<bool> _detectSvg(String url) {
    return _svgDetectionCache.putIfAbsent(url, () async {
      if (_looksLikeSvgByUrl(url)) return true;

      try {
        final response = await http.head(Uri.parse(url));
        final contentType = (response.headers['content-type'] ?? '')
            .toLowerCase()
            .trim();
        if (contentType.contains('image/svg+xml')) {
          return true;
        }
        if (contentType.startsWith('image/')) {
          return false;
        }
      } catch (_) {}

      return _looksLikeSvgByUrl(url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url?.trim() ?? '';
    if (url.isEmpty) return widget.fallback;

    return FutureBuilder<bool>(
      future: _detectSvg(url),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return widget.placeholder ??
              SizedBox(width: widget.width, height: widget.height);
        }

        if (snapshot.data == true) {
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
      },
    );
  }
}
