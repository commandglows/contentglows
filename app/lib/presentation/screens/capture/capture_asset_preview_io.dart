import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/capture_asset.dart';
import '../../theme/app_theme.dart';

class CaptureAssetPreview extends StatelessWidget {
  const CaptureAssetPreview({super.key, required this.asset});

  final CaptureAsset asset;

  @override
  Widget build(BuildContext context) {
    if (asset.isScreenshot && File(asset.path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Image.file(
          File(asset.path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const _FallbackPreview(),
        ),
      );
    }
    return const _FallbackPreview();
  }
}

class _FallbackPreview extends StatelessWidget {
  const _FallbackPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.smart_display_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: AppSizes.control,
      ),
    );
  }
}
