import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/content_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/project_picker_action.dart';
import '../../widgets/app_error_view.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(contentHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('History')),
        actions: const [ProjectPickerAction()],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            scope: 'history.load',
            title: context.tr('Failed to load history'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(contentHistoryProvider),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: AppSizes.heroIcon,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.tr('No history yet'),
                    style: TextStyle(
                      fontSize: AppText.title,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            itemBuilder: (context, index) => _HistoryTile(item: items[index]),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ContentItem item;

  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    final typeColor = AppTheme.colorForContentType(item.typeLabel);
    final statusColor = _statusColor(context, item.status);
    final dateFormat = DateFormat('MMM d, HH:mm', context.localeTag);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(AppAlpha.glow),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _statusIcon(item.status),
              color: statusColor,
              size: AppSizes.iconHeading,
            ),
          ),
          const SizedBox(width: AppSpacing.contentInset),
          // Content info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: AppText.medium,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withAlpha(AppAlpha.glow),
                        borderRadius: BorderRadius.circular(
                          AppRadii.compactControl,
                        ),
                      ),
                      child: Text(
                        item.typeLabel,
                        style: TextStyle(
                          color: typeColor,
                          fontSize: AppText.xs11,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      dateFormat.format(item.publishedAt ?? item.createdAt),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: AppText.xs,
                      ),
                    ),
                  ],
                ),
                if (item.reviewActorDisplay != null) ...[
                  const SizedBox(height: AppSpacing.xxs2),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: AppSizes.iconCompact,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xxs2),
                      Expanded(
                        child: Text(
                          context.tr('Reviewed by {reviewer}{typeSuffix}', {
                            'reviewer': item.reviewActorDisplay,
                            'typeSuffix': item.reviewActorType == null
                                ? ''
                                : ' (${item.reviewActorType})',
                          }),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: AppText.xs11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compact,
              vertical: AppSpacing.fine,
            ),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(AppAlpha.subtle),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              context.tr(item.status.name),
              style: TextStyle(
                color: statusColor,
                fontSize: AppText.xs,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, ContentStatus status) {
    return switch (status) {
      ContentStatus.published => AppTheme.approveColor,
      ContentStatus.rejected => AppTheme.rejectColor,
      ContentStatus.approved => AppTheme.warningColor,
      ContentStatus.editing => AppTheme.editColor,
      ContentStatus.pending => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  IconData _statusIcon(ContentStatus status) {
    return switch (status) {
      ContentStatus.published => Icons.check_circle_rounded,
      ContentStatus.rejected => Icons.cancel_rounded,
      ContentStatus.approved => Icons.schedule_rounded,
      ContentStatus.editing => Icons.edit_rounded,
      ContentStatus.pending => Icons.hourglass_empty_rounded,
    };
  }
}
