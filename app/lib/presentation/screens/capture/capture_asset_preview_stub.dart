import 'package:flutter/material.dart';

import '../../../data/models/capture_asset.dart';
import '../../theme/app_theme.dart';

class CaptureAssetPreview extends StatelessWidget {
  const CaptureAssetPreview({super.key, required this.asset});

  final CaptureAsset asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        asset.isScreenshot ? Icons.image_rounded : Icons.smart_display_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: AppSizes.control,
      ),
    );
  }
}
