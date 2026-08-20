import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/content_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/project_picker_action.dart';
import '../../widgets/app_error_view.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(contentHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Schedule')),
        actions: const [ProjectPickerAction()],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            scope: 'calendar.load',
            title: context.tr('Failed to load the calendar'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(contentHistoryProvider),
          ),
        ),
        data: (items) => _CalendarBody(items: items),
      ),
    );
  }
}

class _CalendarBody extends ConsumerWidget {
  final List<ContentItem> items;
  const _CalendarBody({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvedItems = items
        .where((i) => i.status == ContentStatus.approved)
        .toList();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Week strip
        _buildWeekStrip(context),
        const SizedBox(height: AppSpacing.lg),

        // Approved items awaiting scheduling
        if (approvedItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              context.tr('Ready to Schedule'),
              style: TextStyle(
                fontSize: AppText.compact,
                fontWeight: FontWeight.w600,
                color: AppTheme.approveColor.withAlpha(AppAlpha.icon),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: approvedItems.length,
              itemBuilder: (context, i) =>
                  _buildScheduleChip(context, ref, approvedItems[i]),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Today's schedule
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            context.tr('Timeline'),
            style: TextStyle(
              fontSize: AppText.compact,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: AppSizes.emptyStateIcon,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        context.tr('Nothing scheduled yet'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: AppText.base,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: items.length,
                  itemBuilder: (context, i) =>
                      _buildScheduleItem(context, items[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildWeekStrip(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day + i),
    );
    final dayFormat = DateFormat('EEE d', context.localeTag);

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final day = days[i];
          final isToday = i == 0;
          final dayItems = items.where((item) {
            final d = item.publishedAt ?? item.createdAt;
            return d.year == day.year &&
                d.month == day.month &&
                d.day == day.day;
          }).length;

          return Container(
            width: 64,
            margin: const EdgeInsets.only(right: AppSpacing.xs),
            decoration: BoxDecoration(
              color: isToday
                  ? AppTheme.colorForContentType('Article').withAlpha(AppAlpha.glow)
                  : palette.elevatedSurface,
              borderRadius: BorderRadius.circular(AppRadii.badge),
              border: Border.all(
                color: isToday
                    ? AppTheme.colorForContentType('Article')
                    : palette.borderSubtle,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayFormat.format(day),
                  style: TextStyle(
                    color: isToday
                        ? AppTheme.colorForContentType('Article')
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: AppText.xs,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (dayItems > 0) ...[
                  const SizedBox(height: AppSpacing.xxs2),
                  Container(
                    width: AppSpacing.lg,
                    height: AppSpacing.lg,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.approveColor.withAlpha(AppAlpha.glow),
                    ),
                    child: Center(
                      child: Text(
                        '$dayItems',
                        style: TextStyle(
                          color: AppTheme.approveColor,
                          fontSize: AppText.xs11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleChip(
    BuildContext context,
    WidgetRef ref,
    ContentItem item,
  ) {
    final typeColor = AppTheme.colorForContentType(item.typeLabel);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _showSchedulePicker(context, ref, item),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: AppSpacing.compact),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppTheme.approveColor.withAlpha(AppAlpha.faint),
          borderRadius: BorderRadius.circular(AppRadii.badge),
          border: Border.all(color: AppTheme.approveColor.withAlpha(AppAlpha.tint)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs2,
                    vertical: AppSpacing.xxsHalf,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(AppAlpha.glow),
                    borderRadius: BorderRadius.circular(AppRadii.compactControl),
                  ),
                  child: Text(
                    item.typeLabel,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: AppText.xxs,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.schedule, size: AppSizes.icon, color: AppTheme.approveColor),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs2),
            Text(
              item.title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: AppText.compact,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.reviewActorDisplay != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                context.tr('Reviewer: {reviewer}', {
                  'reviewer': item.reviewActorDisplay,
                }),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: AppText.xxs,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSchedulePicker(
    BuildContext context,
    WidgetRef ref,
    ContentItem item,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (time == null || !context.mounted) return;

    final scheduledFor = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    try {
      final api = ref.read(apiServiceProvider);
      await api.scheduleContent(item.id, scheduledFor);
      ref.invalidate(contentHistoryProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Scheduled "{title}" for {date}', {
                'title': item.title,
                'date': DateFormat(
                  'MMM d, HH:mm',
                  context.localeTag,
                ).format(scheduledFor),
              }),
            ),
            backgroundColor: AppTheme.approveColor.withAlpha(AppAlpha.text),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Failed to schedule. Check backend connection.'),
            ),
            backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
        );
      }
    }
  }

  Widget _buildScheduleItem(BuildContext context, ContentItem item) {
    final typeColor = AppTheme.colorForContentType(item.typeLabel);
    final time = DateFormat(
      'HH:mm',
      context.localeTag,
    ).format(item.publishedAt ?? item.createdAt);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.compact),
      child: Row(
        children: [
          // Time
          SizedBox(
            width: 50,
            child: Text(
              time,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: AppText.compact,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Line
          Container(width: AppSpacing.xxsHalf, height: 60, color: typeColor.withAlpha(AppAlpha.soft)),
          const SizedBox(width: AppSpacing.contentInset),
          // Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.contentInset),
              decoration: BoxDecoration(
                color: typeColor.withAlpha(AppAlpha.faint),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: typeColor.withAlpha(AppAlpha.glow)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xxsHalf,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withAlpha(AppAlpha.glow),
                          borderRadius: BorderRadius.circular(AppRadii.compactControl),
                        ),
                        child: Text(
                          item.typeLabel,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: AppText.xxs,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.channelLabels,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: AppText.xs11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs2),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: AppText.sm,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
