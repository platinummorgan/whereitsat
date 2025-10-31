// img.dart
import 'package:flutter/material.dart';

Widget buildItemImage(String uri, double width, double height) {
  if (uri.isEmpty) return const Icon(Icons.inventory_2, size: 40);
  if (uri.startsWith('file://')) {
    // On web, file:// is not supported, so fallback to icon.
    return const Icon(Icons.broken_image, size: 40);
  }
  if (uri.startsWith('/')) {
    // On web, local file paths are not supported.
    return const Icon(Icons.broken_image, size: 40);
  }
  return Image.network(
    uri,
    width: width,
    height: height,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
  );
}
