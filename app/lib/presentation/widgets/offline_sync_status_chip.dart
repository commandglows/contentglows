import 'package:flutter/material.dart';

import '../../data/models/offline_sync.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class OfflineSyncStatusChip extends StatelessWidget {
  const OfflineSyncStatusChip({
    super.key,
    required this.info,
    this.compact = false,
  });

  final OfflineEntitySyncInfo info;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (info.status) {
      OfflineEntitySyncStatus.failed => colorScheme.error,
      OfflineEntitySyncStatus.pausedAuth => AppTheme.warningColor,
      OfflineEntitySyncStatus.retrying => AppTheme.infoColor,
      OfflineEntitySyncStatus.blockedDependency => AppTheme.warningColor,
      OfflineEntitySyncStatus.pending => AppTheme.infoColor,
    };
    final icon = switch (info.status) {
      OfflineEntitySyncStatus.failed => Icons.error_outline_rounded,
      OfflineEntitySyncStatus.pausedAuth => Icons.lock_clock_outlined,
      OfflineEntitySyncStatus.retrying => Icons.sync_rounded,
      OfflineEntitySyncStatus.blockedDependency => Icons.link_rounded,
      OfflineEntitySyncStatus.pending => Icons.cloud_upload_outlined,
    };
    final label = switch (info.status) {
      OfflineEntitySyncStatus.failed => context.tr('Sync failed'),
      OfflineEntitySyncStatus.pausedAuth => context.tr('Sync paused'),
      OfflineEntitySyncStatus.retrying => context.tr('Retrying sync'),
      OfflineEntitySyncStatus.blockedDependency =>
        context.tr('Waiting for dependency'),
      OfflineEntitySyncStatus.pending => context.tr('Pending sync'),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.soft),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: AppOpacity.light)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? AppSizes.iconTiny : AppSizes.iconSm,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? AppText.xs11 : AppText.xs,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
