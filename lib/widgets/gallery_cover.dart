import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Cover art for a gallery list item, with a neutral placeholder while the
/// CDN image loads and when the URL is missing.
class GalleryCover extends StatelessWidget {
  const GalleryCover({super.key, required this.url, this.cacheKey});

  final String url;
  final String? cacheKey;

  static const _placeholderColor = Color(0xFF1A1218);

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const ColoredBox(
        color: _placeholderColor,
        child: Icon(Icons.broken_image_outlined),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: cacheKey ?? url,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(color: _placeholderColor),
      errorWidget: (_, _, _) => const ColoredBox(
        color: _placeholderColor,
        child: Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
