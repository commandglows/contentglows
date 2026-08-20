import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/search_console.dart';
import '../../../data/services/api_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

class SearchConsolePanel extends ConsumerStatefulWidget {
  const SearchConsolePanel({super.key});

  @override
  ConsumerState<SearchConsolePanel> createState() => _SearchConsolePanelState();
}

class _SearchConsolePanelState extends ConsumerState<SearchConsolePanel> {
  final Set<String> _selectedOpportunityKeys = <String>{};
  bool _isSyncing = false;
  bool _isIngesting = false;

  @override
  Widget build(BuildContext context) {
    final activeProjectId = ref.watch(activeProjectIdProvider);
    final period = ref.watch(searchConsolePeriodProvider);
    final connection = ref.watch(searchConsoleConnectionStatusProvider);
    final summary = ref.watch(searchConsoleSummaryProvider);
    final opportunities = ref.watch(searchConsoleOpportunitiesProvider);
    final connectionStatus = connection.value;
    final canSync =
        activeProjectId != null &&
        connectionStatus?.connected == true &&
        connectionStatus?.propertyUrl?.isNotEmpty == true &&
        connectionStatus?.isInvalid != true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SeoStatsHeader(
          connection: connectionStatus,
          period: period,
          isSyncing: _isSyncing,
          onSync: !canSync ? null : () => _sync(activeProjectId, period),
        ),
        const SizedBox(height: AppSpacing.contentInset),
        _PeriodSelector(
          selected: period,
          onSelected: (next) {
            ref.read(searchConsolePeriodProvider.notifier).state = next;
            setState(_selectedOpportunityKeys.clear);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        summary.when(
          loading: () => const _PanelLoading(),
          error: (error, stackTrace) => AppErrorView(
            scope: 'search_console.summary',
            title: context.tr('Failed to load SEO Stats'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(searchConsoleSummaryProvider),
          ),
          data: (data) {
            if (activeProjectId == null) {
              return _PanelMessage(
                icon: Icons.folder_open_outlined,
                title: context.tr('Select a project'),
                body: context.tr(
                  'SEO Stats are project-scoped because Search Console properties and private traffic are project data.',
                ),
              );
            }
            if (data == null) {
              return _PanelMessage(
                icon: Icons.travel_explore_outlined,
                title: context.tr('No SEO Stats yet'),
                body: context.tr(
                  'Connect Google Search Console, then sync a period to populate this view.',
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OverviewCard(summary: data),
                const SizedBox(height: AppSpacing.contentInset),
                _GoogleSearchSection(section: data.googleSearch),
                const SizedBox(height: AppSpacing.contentInset),
                _SiteTrafficSection(section: data.siteTraffic),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.contentInset),
        opportunities.when(
          loading: () =>
              const _InlineLoading(label: 'Loading opportunities...'),
          error: (error, stackTrace) => AppErrorView(
            scope: 'search_console.opportunities',
            title: context.tr('Failed to load Search Console opportunities'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(searchConsoleOpportunitiesProvider),
          ),
          data: (items) => _OpportunitiesSection(
            opportunities: items,
            selectedKeys: _selectedOpportunityKeys,
            isIngesting: _isIngesting,
            onToggle: (item, selected) {
              setState(() {
                if (selected) {
                  _selectedOpportunityKeys.add(item.stableKey);
                } else {
                  _selectedOpportunityKeys.remove(item.stableKey);
                }
              });
            },
            onIngest: activeProjectId == null
                ? null
                : () => _ingest(activeProjectId, items),
          ),
        ),
      ],
    );
  }

  Future<void> _sync(String projectId, String period) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.syncSearchConsole(projectId: projectId, period: period);
      ref.invalidate(searchConsoleConnectionStatusProvider);
      ref.invalidate(searchConsoleSummaryProvider);
      ref.invalidate(searchConsoleOpportunitiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Search Console sync completed.'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: error.message.trim().isEmpty
            ? context.tr('Search Console sync failed.')
            : error.message.trim(),
        scope: 'search_console.sync',
        error: error,
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _ingest(
    String projectId,
    List<SearchConsoleOpportunity> opportunities,
  ) async {
    if (_isIngesting || _selectedOpportunityKeys.isEmpty) return;
    final selected = opportunities
        .where((item) => _selectedOpportunityKeys.contains(item.stableKey))
        .toList();
    if (selected.isEmpty) return;

    setState(() => _isIngesting = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.ingestSearchConsoleOpportunities(
        projectId: projectId,
        opportunities: selected,
      );
      ref.invalidate(ideasProvider);
      ref.invalidate(searchConsoleOpportunitiesProvider);
      if (!mounted) return;
      setState(_selectedOpportunityKeys.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Added {count} Search Console ideas. Skipped {skipped}.',
              {'count': result.ingested, 'skipped': result.skipped},
            ),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: error.message.trim().isEmpty
            ? context.tr('Failed to add opportunities to Idea Pool.')
            : error.message.trim(),
        scope: 'search_console.ingest',
        error: error,
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
      );
    } finally {
      if (mounted) setState(() => _isIngesting = false);
    }
  }
}

class _SeoStatsHeader extends StatelessWidget {
  const _SeoStatsHeader({
    required this.connection,
    required this.period,
    required this.isSyncing,
    required this.onSync,
  });

  final SearchConsoleConnectionStatus? connection;
  final String period;
  final bool isSyncing;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = connection;
    final color = _connectionColor(status, theme.colorScheme);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.paletteOf(context).elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppTheme.paletteOf(context).borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(AppAlpha.low24),
              borderRadius: BorderRadius.circular(AppRadii.narrow),
            ),
            child: Icon(Icons.query_stats_rounded, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('SEO Stats'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _connectionLabel(context, status),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: AppText.xs,
                    height: AppLineHeight.compact,
                  ),
                ),
                if (period == 'today') ...[
                  const SizedBox(height: AppSpacing.xs),
                  _SourceBadge(
                    label: context.tr('Today is partial'),
                    color: AppTheme.warningColor,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.compact),
          FilledButton.icon(
            onPressed: isSyncing ? null : onSync,
            icon: isSyncing
                ? const SizedBox(
                    width: AppSpacing.md,
                    height: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: AppStroke.medium),
                  )
                : const Icon(Icons.sync_rounded, size: AppSizes.iconLarge),
            label: Text(context.tr('Sync')),
          ),
        ],
      ),
    );
  }

  static String _connectionLabel(
    BuildContext context,
    SearchConsoleConnectionStatus? status,
  ) {
    if (status == null) {
      return context.tr('Checking Google Search Console connection...');
    }
    if (status.isValid) {
      return context.tr('Google Search Console is connected and valid.');
    }
    if (status.isDegraded) {
      return status.lastSyncMessage ??
          context.tr('Google Search Console is connected but degraded.');
    }
    if (status.isInvalid) {
      return status.lastSyncMessage ??
          context.tr('Reconnect Google Search Console to sync SEO data.');
    }
    if (status.connected) {
      return context.tr(
        'Google Search Console is connected. Validate it before syncing.',
      );
    }
    return context.tr(
      'Connect Google Search Console in Integrations to sync SEO data.',
    );
  }

  static Color _connectionColor(
    SearchConsoleConnectionStatus? status,
    ColorScheme colorScheme,
  ) {
    if (status == null || status.isMissing) return colorScheme.onSurfaceVariant;
    if (status.isValid) return AppTheme.approveColor;
    if (status.isDegraded) return AppTheme.warningColor;
    if (status.isInvalid) return AppTheme.rejectColor;
    return AppTheme.infoColor;
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: searchConsolePeriods.map((period) {
        return ChoiceChip(
          label: Text(context.tr(searchConsolePeriodLabel(period))),
          selected: selected == period,
          onSelected: (_) => onSelected(period),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.summary});

  final SearchConsoleSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(AppAlpha.low16),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(AppAlpha.mid45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: AppSizes.iconLarge,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  context.tr('Overview'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _SourceBadge(
                label: context.tr(searchConsolePeriodLabel(summary.period)),
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            summary.overview,
            style: TextStyle(color: theme.colorScheme.onSurface, height: AppLineHeight.readable),
          ),
          if (summary.googleSearch.isPartial ||
              summary.siteTraffic.isPartial) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr('Recent data can be delayed or incomplete.'),
              style: TextStyle(
                color: AppTheme.warningColor,
                fontSize: AppText.xs,
                height: AppLineHeight.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoogleSearchSection extends StatelessWidget {
  const _GoogleSearchSection({required this.section});

  final SearchConsoleSourceSection section;

  @override
  Widget build(BuildContext context) {
    final clicks = _intMetric(section.metrics, 'organic_clicks');
    final impressions = _intMetric(section.metrics, 'impressions');
    final ctr = _doubleMetric(section.metrics, 'ctr');
    final avgPosition = _nullableDoubleMetric(section.metrics, 'avg_position');
    final inspectedPages = _intMetric(section.metrics, 'inspected_pages');
    final inspectionIssues = _intMetric(
      section.metrics,
      'inspection_issue_count',
    );

    return _StatsSection(
      title: context.tr('Google Search'),
      sourceLabel: context.tr('Source: Google Search Console'),
      summary: section.summary,
      stale: section.stale,
      children: [
        _MetricWrap(
          cards: [
            _MetricCardData(
              label: context.tr('Organic clicks from Google'),
              value: _formatInt(clicks),
              icon: Icons.ads_click_rounded,
              color: AppTheme.infoColor,
            ),
            _MetricCardData(
              label: context.tr('Impressions'),
              value: _formatInt(impressions),
              icon: Icons.visibility_outlined,
              color: AppTheme.editColor,
            ),
            _MetricCardData(
              label: context.tr('CTR'),
              value: _formatPercent(ctr),
              icon: Icons.percent_rounded,
              color: AppTheme.approveColor,
            ),
            _MetricCardData(
              label: context.tr('Average position'),
              value: avgPosition == null ? '-' : avgPosition.toStringAsFixed(1),
              icon: Icons.format_list_numbered_rounded,
              color: AppTheme.warningColor,
            ),
            _MetricCardData(
              label: context.tr('Inspected URLs'),
              value: _formatInt(inspectedPages),
              icon: Icons.fact_check_outlined,
              color: AppTheme.infoColor,
            ),
            _MetricCardData(
              label: context.tr('Inspection issues'),
              value: _formatInt(inspectionIssues),
              icon: Icons.report_problem_outlined,
              color: inspectionIssues > 0
                  ? AppTheme.rejectColor
                  : AppTheme.approveColor,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.contentInset),
        _TopRows(
          title: context.tr('Top organic landing pages from Google'),
          rows: section.topPages,
          emptyText: context.tr('No Google landing pages synced yet.'),
          mode: _TopRowsMode.pages,
        ),
        const SizedBox(height: AppSpacing.contentInset),
        _TopRows(
          title: context.tr('Top queries'),
          rows: section.topQueries,
          emptyText: context.tr('No Google queries synced yet.'),
          mode: _TopRowsMode.queries,
        ),
        if (section.issues.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.contentInset),
          _InspectionIssues(issues: section.issues),
        ],
      ],
    );
  }
}

class _SiteTrafficSection extends StatelessWidget {
  const _SiteTrafficSection({required this.section});

  final SearchConsoleSiteTrafficSection section;

  @override
  Widget build(BuildContext context) {
    final pageviews = _intMetric(section.metrics, 'visits_pageviews');
    final uniquePages = _intMetric(section.metrics, 'unique_pages');

    return _StatsSection(
      title: context.tr('Site traffic'),
      sourceLabel: context.tr('Source: private analytics tracker'),
      summary:
          section.message ??
          context.tr(
            'Private tracker pageviews are separate from Google Search clicks.',
          ),
      stale: section.stale,
      children: [
        _MetricWrap(
          cards: [
            _MetricCardData(
              label: context.tr('Site visits/pageviews'),
              value: _formatInt(pageviews),
              icon: Icons.bar_chart_rounded,
              color: AppTheme.approveColor,
            ),
            _MetricCardData(
              label: context.tr('Unique tracked pages'),
              value: _formatInt(uniquePages),
              icon: Icons.article_outlined,
              color: AppTheme.infoColor,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.contentInset),
        Text(
          context.tr('Most visited pages on site'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (section.topPages.isEmpty)
          Text(
            context.tr('No private analytics pageviews for this period.'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: AppText.compact,
            ),
          )
        else
          ...section.topPages
              .take(8)
              .map(
                (page) => _SimpleRow(
                  title: page.path,
                  subtitle: context.tr('Private tracker'),
                  trailing: context.tr('{count} views', {'count': page.views}),
                ),
              ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.title,
    required this.sourceLabel,
    required this.summary,
    required this.children,
    this.stale = false,
  });

  final String title;
  final String sourceLabel;
  final String summary;
  final bool stale;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.paletteOf(context).surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppTheme.paletteOf(context).borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxsHalf),
                    Text(
                      sourceLabel,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: AppText.xs,
                      ),
                    ),
                  ],
                ),
              ),
              if (stale)
                _SourceBadge(
                  label: context.tr('Stale'),
                  color: AppTheme.warningColor,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            summary,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppText.compact,
              height: AppLineHeight.body,
            ),
          ),
          const SizedBox(height: AppSpacing.contentInset),
          ...children,
        ],
      ),
    );
  }
}

class _MetricWrap extends StatelessWidget {
  const _MetricWrap({required this.cards});

  final List<_MetricCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final width = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: _MetricCard(data: card),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: data.color.withAlpha(AppAlpha.low16),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: data.color.withAlpha(AppAlpha.mid45)),
      ),
      child: Row(
        children: [
          Icon(data.icon, color: data.color, size: 22),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.value,
                  style: TextStyle(
                    color: data.color,
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  data.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: AppText.xs,
                    height: AppLineHeight.quarter,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TopRowsMode { pages, queries }

class _TopRows extends StatelessWidget {
  const _TopRows({
    required this.title,
    required this.rows,
    required this.emptyText,
    required this.mode,
  });

  final String title;
  final List<SearchConsoleTopRow> rows;
  final String emptyText;
  final _TopRowsMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (rows.isEmpty)
          Text(
            emptyText,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppText.compact,
            ),
          )
        else
          ...rows.take(8).map((row) {
            final title = mode == _TopRowsMode.pages
                ? (row.url ?? row.key)
                : (row.query ?? row.key);
            final subtitle = context.tr(
              '{clicks} clicks · {impressions} impressions',
              {'clicks': row.clicks, 'impressions': row.impressions},
            );
            final trailing = row.position == null
                ? _formatPercent(row.ctr)
                : '#${row.position!.toStringAsFixed(1)}';
            return _SimpleRow(
              title: title,
              subtitle: subtitle,
              trailing: trailing,
            );
          }),
      ],
    );
  }
}

class _InspectionIssues extends StatelessWidget {
  const _InspectionIssues({required this.issues});

  final List<Map<String, dynamic>> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('URL Inspection issues'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...issues.take(5).map((issue) {
          final type = (issue['type'] ?? 'indexation_problem')
              .toString()
              .replaceAll('_', ' ');
          final url = (issue['url'] ?? '').toString();
          final detail =
              (issue['coverageState'] ??
                      issue['indexingState'] ??
                      issue['verdict'] ??
                      issue['googleCanonical'] ??
                      '')
                  .toString();
          return _SimpleRow(
            title: url.isEmpty ? type : url,
            subtitle: detail.isEmpty ? type : '$type · $detail',
            trailing: context.tr('Review'),
          );
        }),
      ],
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.controlGap),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: AppText.compact,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxsHalf),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: AppText.xs,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.compact),
          Text(
            trailing,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunitiesSection extends StatelessWidget {
  const _OpportunitiesSection({
    required this.opportunities,
    required this.selectedKeys,
    required this.isIngesting,
    required this.onToggle,
    required this.onIngest,
  });

  final List<SearchConsoleOpportunity> opportunities;
  final Set<String> selectedKeys;
  final bool isIngesting;
  final void Function(SearchConsoleOpportunity item, bool selected) onToggle;
  final VoidCallback? onIngest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.paletteOf(context).surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppTheme.paletteOf(context).borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Search Console opportunities'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _SourceBadge(
                label: context.tr('Google evidence'),
                color: AppTheme.infoColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          if (opportunities.isEmpty)
            Text(
              context.tr('No Search Console opportunities for this period.'),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: AppText.compact,
              ),
            )
          else ...[
            ...opportunities.take(12).map((item) {
              final selected = selectedKeys.contains(item.stableKey);
              return CheckboxListTile(
                value: selected,
                onChanged: isIngesting
                    ? null
                    : (value) => onToggle(item, value ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  item.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: _SourceBadge(
                  label: item.priorityScore.toStringAsFixed(0),
                  color: AppTheme.warningColor,
                ),
              );
            }),
            const SizedBox(height: AppSpacing.compact),
            FilledButton.icon(
              onPressed: selectedKeys.isEmpty || isIngesting ? null : onIngest,
              icon: isIngesting
                  ? const SizedBox(
                      width: AppSpacing.md,
                      height: AppSpacing.md,
                      child: CircularProgressIndicator(strokeWidth: AppStroke.medium),
                    )
                  : const Icon(Icons.add_task_rounded, size: AppSizes.iconLarge),
              label: Text(context.tr('Add to Idea Pool')),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withAlpha(AppAlpha.low22),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withAlpha(AppAlpha.mid55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: AppText.xs11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.wide),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: AppSpacing.md,
          height: AppSpacing.md,
          child: CircularProgressIndicator(strokeWidth: AppStroke.medium),
        ),
        const SizedBox(width: AppSpacing.compact),
        Text(
          context.tr(label),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.dense),
      decoration: BoxDecoration(
        color: AppTheme.paletteOf(context).surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppTheme.paletteOf(context).borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  body,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: AppText.compact,
                    height: AppLineHeight.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _intMetric(Map<String, dynamic> metrics, String key) {
  final value = metrics[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _doubleMetric(Map<String, dynamic> metrics, String key) {
  final value = metrics[key];
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double? _nullableDoubleMetric(Map<String, dynamic> metrics, String key) {
  if (!metrics.containsKey(key) || metrics[key] == null) return null;
  return _doubleMetric(metrics, key);
}

String _formatInt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _formatPercent(double value) {
  final pct = value <= 1 ? value * 100 : value;
  if (pct == 0) return '0%';
  if (pct < 1) return '${pct.toStringAsFixed(2)}%';
  return '${pct.toStringAsFixed(1)}%';
}
