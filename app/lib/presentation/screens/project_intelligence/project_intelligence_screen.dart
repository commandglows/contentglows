import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/project_intelligence.dart';
import '../../../data/services/api_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

class ProjectIntelligenceScreen extends ConsumerStatefulWidget {
  const ProjectIntelligenceScreen({super.key});

  @override
  ConsumerState<ProjectIntelligenceScreen> createState() =>
      _ProjectIntelligenceScreenState();
}

class _ProjectIntelligenceScreenState
    extends ConsumerState<ProjectIntelligenceScreen> {
  final TextEditingController _fileNameCtrl = TextEditingController(
    text: 'project-notes.md',
  );
  final TextEditingController _textCtrl = TextEditingController();

  @override
  void dispose() {
    _fileNameCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeProjectId = ref.watch(activeProjectIdProvider);
    final statusAsync = ref.watch(projectIntelligenceStatusProvider);
    final sourcesAsync = ref.watch(projectIntelligenceSourcesProvider);
    final factsAsync = ref.watch(projectIntelligenceFactsProvider);
    final recommendationsAsync = ref.watch(
      projectIntelligenceRecommendationsProvider,
    );
    final readinessAsync = ref.watch(
      projectIntelligenceProviderReadinessProvider,
    );
    final controllerState = ref.watch(projectIntelligenceControllerProvider);

    if (activeProjectId == null) {
      return _ProjectRequiredState();
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _HeaderCard(
          statusAsync: statusAsync,
          readinessAsync: readinessAsync,
          controllerState: controllerState,
          onSync: _syncConnectors,
        ),
        const SizedBox(height: AppSpacing.contentInset),
        _UploadPanel(
          fileNameCtrl: _fileNameCtrl,
          textCtrl: _textCtrl,
          busy: controllerState.isUploading,
          onSubmit: _uploadTextSource,
        ),
        const SizedBox(height: AppSpacing.contentInset),
        _SectionCard(
          title: context.tr('Source Inventory'),
          child: sourcesAsync.when(
            loading: () => const _InlineLoading(),
            error: (error, stackTrace) => AppErrorView(
              scope: 'project_intelligence.sources',
              title: context.tr('Failed to load sources'),
              error: error,
              stackTrace: stackTrace,
              onRetry: () => ref.invalidate(projectIntelligenceSourcesProvider),
            ),
            data: (items) => _SourcesList(
              items: items,
              isMutating: controllerState.isMutating,
              onRemove: _removeSource,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.contentInset),
        _SectionCard(
          title: context.tr('Recommendations'),
          child: recommendationsAsync.when(
            loading: () => const _InlineLoading(),
            error: (error, stackTrace) => AppErrorView(
              scope: 'project_intelligence.recommendations',
              title: context.tr('Failed to load recommendations'),
              error: error,
              stackTrace: stackTrace,
              onRetry: () =>
                  ref.invalidate(projectIntelligenceRecommendationsProvider),
            ),
            data: (items) => _RecommendationsList(
              items: items,
              isMutating: controllerState.isMutating,
              onAddToIdeaPool: _addRecommendationToIdeaPool,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.contentInset),
        _SectionCard(
          title: context.tr('Facts'),
          child: factsAsync.when(
            loading: () => const _InlineLoading(),
            error: (error, stackTrace) => AppErrorView(
              scope: 'project_intelligence.facts',
              title: context.tr('Failed to load facts'),
              error: error,
              stackTrace: stackTrace,
              onRetry: () => ref.invalidate(projectIntelligenceFactsProvider),
            ),
            data: (items) => _FactsList(items: items),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadTextSource() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      return;
    }
    try {
      await ref
          .read(projectIntelligenceControllerProvider.notifier)
          .uploadTextSource(fileName: _fileNameCtrl.text.trim(), text: text);
      if (!mounted) return;
      _textCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Project intelligence source uploaded.')),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message.trim().isEmpty
                ? context.tr('Upload failed.')
                : error.message.trim(),
          ),
          backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
        ),
      );
    }
  }

  Future<void> _syncConnectors() async {
    try {
      await ref
          .read(projectIntelligenceControllerProvider.notifier)
          .syncConnectors();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Connector sync completed.'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message.trim().isEmpty
                ? context.tr('Connector sync failed.')
                : error.message.trim(),
          ),
          backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
        ),
      );
    }
  }

  Future<void> _removeSource(ProjectIntelligenceSource source) async {
    try {
      await ref
          .read(projectIntelligenceControllerProvider.notifier)
          .removeSource(source.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Source removed.'))));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message.trim().isEmpty
                ? context.tr('Failed to remove source.')
                : error.message.trim(),
          ),
          backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
        ),
      );
    }
  }

  Future<void> _addRecommendationToIdeaPool(
    ProjectIntelligenceRecommendation recommendation,
  ) async {
    try {
      await ref
          .read(projectIntelligenceControllerProvider.notifier)
          .addRecommendationToIdeaPool(recommendation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Recommendation added to Idea Pool.')),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message.trim().isEmpty
                ? context.tr('Failed to add recommendation to Idea Pool.')
                : error.message.trim(),
          ),
          backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
        ),
      );
    }
  }
}

class _ProjectRequiredState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          context.tr('Select a project to use Project Intelligence.'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.statusAsync,
    required this.readinessAsync,
    required this.controllerState,
    required this.onSync,
  });

  final AsyncValue<ProjectIntelligenceStatus> statusAsync;
  final AsyncValue<ProjectIntelligenceProviderReadiness?> readinessAsync;
  final ProjectIntelligenceControllerState controllerState;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final status = statusAsync.value ?? ProjectIntelligenceStatus.empty();
    final readiness = readinessAsync.value;
    final counts = status.counts;

    return Container(
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        border: Border.all(color: palette.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.contentInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Project Intelligence'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: controllerState.isSyncing ? null : () => onSync(),
                icon: controllerState.isSyncing
                    ? const SizedBox(
                        width: AppSizes.iconSm,
                        height: AppSizes.iconSm,
                        child: CircularProgressIndicator(
                          strokeWidth: AppStroke.medium,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, size: AppSizes.icon),
                label: Text(context.tr('Sync')),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _MetricChip(
                label: context.tr('Sources'),
                value: '${counts['sources'] ?? 0}',
              ),
              _MetricChip(
                label: context.tr('Documents'),
                value: '${counts['documents'] ?? 0}',
              ),
              _MetricChip(
                label: context.tr('Facts'),
                value: '${counts['facts'] ?? 0}',
              ),
              _MetricChip(
                label: context.tr('Recommendations'),
                value: '${counts['recommendations'] ?? 0}',
              ),
            ],
          ),
          if (readiness != null) ...[
            const SizedBox(height: AppSpacing.compact),
            Text(
              '${context.tr('Provider readiness')}: ${readiness.readiness} (${readiness.score})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (status.degraded && (status.degradedReason ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              status.degradedReason!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.warningColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.compact,
        vertical: AppSpacing.xxs2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.paletteOf(context).mutedSurface,
        border: Border.all(color: AppTheme.paletteOf(context).borderSubtle),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _UploadPanel extends StatelessWidget {
  const _UploadPanel({
    required this.fileNameCtrl,
    required this.textCtrl,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController fileNameCtrl;
  final TextEditingController textCtrl;
  final bool busy;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: context.tr('Upload Source'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: fileNameCtrl,
            decoration: InputDecoration(labelText: context.tr('Filename')),
          ),
          const SizedBox(height: AppSpacing.compact),
          TextField(
            controller: textCtrl,
            maxLines: 8,
            minLines: 6,
            decoration: InputDecoration(
              labelText: context.tr('Text source'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.compact),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: busy ? null : () => onSubmit(),
              icon: busy
                  ? const SizedBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      child: CircularProgressIndicator(
                        strokeWidth: AppStroke.medium,
                      ),
                    )
                  : const Icon(
                      Icons.upload_file_rounded,
                      size: AppSizes.icon,
                    ),
              label: Text(context.tr('Upload')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.paletteOf(context).elevatedSurface,
        border: Border.all(color: AppTheme.paletteOf(context).borderSubtle),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.contentInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.compact),
          child,
        ],
      ),
    );
  }
}

class _SourcesList extends StatelessWidget {
  const _SourcesList({
    required this.items,
    required this.isMutating,
    required this.onRemove,
  });

  final List<ProjectIntelligenceSource> items;
  final bool isMutating;
  final Future<void> Function(ProjectIntelligenceSource source) onRemove;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(context.tr('No intelligence sources yet.'));
    }
    return Column(
      children: items
          .map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.sourceLabel),
              subtitle: Text(
                '${item.sourceType} • ${item.status}${item.originRef == null ? '' : ' • ${item.originRef}'}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: isMutating ? null : () => onRemove(item),
                tooltip: context.tr('Remove source'),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RecommendationsList extends StatelessWidget {
  const _RecommendationsList({
    required this.items,
    required this.isMutating,
    required this.onAddToIdeaPool,
  });

  final List<ProjectIntelligenceRecommendation> items;
  final bool isMutating;
  final Future<void> Function(ProjectIntelligenceRecommendation recommendation)
  onAddToIdeaPool;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(context.tr('No recommendations yet.'));
    }
    return Column(
      children: items
          .map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.title),
              subtitle: Text(
                '${item.summary}\n${context.tr('Confidence')}: ${(item.confidence * 100).toStringAsFixed(0)}% • ${context.tr('Evidence')}: ${item.evidenceIds.length}',
              ),
              isThreeLine: true,
              trailing: OutlinedButton(
                onPressed: isMutating ? null : () => onAddToIdeaPool(item),
                child: Text(context.tr('Add to Idea Pool')),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FactsList extends StatelessWidget {
  const _FactsList({required this.items});

  final List<ProjectIntelligenceFact> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(context.tr('No facts extracted yet.'));
    }
    return Column(
      children: items
          .take(20)
          .map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${item.category}: ${item.subject}'),
              subtitle: Text(item.statement),
              trailing: Text(
                '${(item.confidence * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: SizedBox(
          width: AppSizes.iconLarge,
          height: AppSizes.iconLarge,
          child: CircularProgressIndicator(strokeWidth: AppStroke.medium),
        ),
      ),
    );
  }
}
