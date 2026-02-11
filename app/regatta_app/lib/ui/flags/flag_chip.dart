import 'package:flutter/material.dart';

/// FlagChip displays a sailing flag image + label
/// Uses PNG assets instead of SVG
class FlagChip extends StatelessWidget {
  final String flagCode; // e.g. P, I, Z, U, BLACK
  final String? label;

  const FlagChip({
    super.key,
    required this.flagCode,
    this.label,
  });

  // Map flag codes to PNG asset paths
  String get _assetPath {
    switch (flagCode.toUpperCase()) {
      case 'P':
        return 'assets/flags/p.png';
      case 'I':
        return 'assets/flags/i.png';
      case 'Z':
        return 'assets/flags/z.png';
      case 'U':
        return 'assets/flags/u.png';
      case 'BLACK':
        return 'assets/flags/black.png';
      default:
        return 'assets/flags/p.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          _assetPath,
          width: 80,
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.flag, size: 48);
          },
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(
            label!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}
