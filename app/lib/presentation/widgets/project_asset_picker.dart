import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/project_asset.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../theme/app_theme_tokens.dart';

class ProjectAssetPicker extends ConsumerWidget {
  const ProjectAssetPicker({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.usageAction,
    this.placement,
    this.allowedMediaKinds,
    this.platformLabel,
    this.slotLabel,
    this.selectAsPrimary = false,
    this.onSelected,
  });

  final String targetType;
  final String targetId;
  final String usageAction;
  final String? placement;
  final Set<String>? allowedMediaKinds;
  final String? platformLabel;
  final String? slotLabel;
  final bool selectAsPrimary;
  final void Function(ProjectAssetUsage usage)? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(projectAssetLibraryProvider);
    final controller = ref.read(projectAssetLibraryProvider.notifier);
    final theme = Theme.of(context);

    return library.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(context.tr('Asset library unavailable'))),
      data: (state) {
        final selectedId = state.selectedAssetId;
        final selectedAsset = state.selectedAsset;
        final visibleAssets = state.assets;
        final usage = selectedId == null
            ? const <ProjectAssetUsage>[]
            : (state.assetUsage[selectedId] ?? const <ProjectAssetUsage>[]);
        final events = selectedId == null
            ? const <ProjectAssetEvent>[]
            : (state.assetEvents[selectedId] ?? const <ProjectAssetEvent>[]);
        final understanding = selectedId == null
            ? null
            : state.assetUnderstanding[selectedId];
        final selectedRecommendations = selectedId == null
            ? null
            : state.assetRecommendations[selectedId];
        final recommendation =
            (selectedRecommendations == null || selectedRecommendations.isEmpty)
            ? null
            : selectedRecommendations.first;

        return LayoutBuilder(
          builder: (context, constraints) {
            final twoPanels = constraints.maxWidth >= 760;
            final listPane = _AssetListPane(
              state: state,
              assets: visibleAssets,
              onRefresh: controller.refresh,
              onMediaKindChanged: controller.setMediaKindFilter,
              onSourceChanged: controller.setSourceFilter,
              onCategoryChanged: controller.setCategoryFilter,
              onSubcategoryChanged: controller.setSubcategoryFilter,
              onIncludeTombstonedChanged: controller.setIncludeTombstoned,
              onAssetTap: controller.selectAsset,
              incompatibilityFor: _incompatibilityFor,
            );
            final detailPane = _AssetDetailPane(
              asset: selectedAsset,
              usage: usage,
              events: events,
              understanding: understanding,
              recommendation: recommendation,
              categoryCatalog: state.categoryCatalog,
              isMutating: state.isMutating,
              platformLabel: platformLabel,
              slotLabel: slotLabel,
              incompatibilityReason: selectedAsset == null
                  ? null
                  : _incompatibilityFor(selectedAsset),
              onSelect: selectedAsset == null
                  ? null
                  : () async {
                      final result = await controller.selectForTarget(
                        assetId: selectedAsset.id,
                        targetType: targetType,
                        targetId: targetId,
                        usageAction: usageAction,
                        placement: placement,
                        isPrimary: selectAsPrimary,
                      );
                      if (result != null) {
                        onSelected?.call(result);
                      }
                    },
              onSetPrimary: selectedAsset == null
                  ? null
                  : () => controller.setPrimary(
                      assetId: selectedAsset.id,
                      targetType: targetType,
                      targetId: targetId,
                      usageAction: usageAction,
                      placement: placement,
                    ),
              onClearPrimary: () => controller.clearPrimary(
                targetType: targetType,
                targetId: targetId,
                placement: placement,
              ),
              onTombstone: selectedAsset == null
                  ? null
                  : () => controller.tombstoneAsset(selectedAsset.id),
              onRestore: selectedAsset == null
                  ? null
                  : () => controller.restoreAsset(selectedAsset.id),
              onQueueUnderstanding: selectedAsset == null
                  ? null
                  : () => controller.queueUnderstanding(
                      assetId: selectedAsset.id,
                    ),
              onRefreshUnderstanding: selectedAsset == null
                  ? null
                  : () => controller.refreshUnderstandingStatus(
                      assetId: selectedAsset.id,
                    ),
              onAttachGlobal: selectedAsset == null
                  ? null
                  : () => controller.attachGlobalAsset(
                      globalAssetId: selectedAsset.id,
                      selectForAssetIdAfterAttach: selectedAsset.id,
                    ),
              onCategoryAssigned: selectedAsset == null
                  ? null
                  : (categoryId, subcategoryId) async {
                      await controller.assignCategory(
                        assetId: selectedAsset.id,
                        categoryId: categoryId,
                        subcategoryId: subcategoryId,
                      );
                    },
            );

            if (!twoPanels) {
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Expanded(child: listPane),
                    detailPane,
                  ],
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(flex: 4, child: listPane),
                  VerticalDivider(
                    width: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  Expanded(flex: 3, child: detailPane),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String? _incompatibilityFor(ProjectAsset asset) {
    if (asset.status != 'active' || asset.tombstonedAt != null) {
      return 'This asset is not active.';
    }
    final accepted = allowedMediaKinds;
    if (accepted == null || accepted.isEmpty) return null;
    final family = switch (asset.mediaKind) {
      'image' || 'thumbnail' || 'video_cover' || 'capture' => 'image',
      'video' || 'render_output' => 'video',
      'audio' || 'music' => 'audio',
      _ => asset.mediaKind,
    };
    if (!accepted.contains(family)) {
      return 'This asset type is not compatible with the placement.';
    }
    return null;
  }
}

class _AssetListPane extends StatelessWidget {
  const _AssetListPane({
    required this.state,
    required this.assets,
    required this.onRefresh,
    required this.onMediaKindChanged,
    required this.onSourceChanged,
    required this.onCategoryChanged,
    required this.onSubcategoryChanged,
    required this.onIncludeTombstonedChanged,
    required this.onAssetTap,
    required this.incompatibilityFor,
  });

  final ProjectAssetLibraryState state;
  final List<ProjectAsset> assets;
  final Future<void> Function() onRefresh;
  final void Function(String?) onMediaKindChanged;
  final void Function(String?) onSourceChanged;
  final void Function(String?) onCategoryChanged;
  final void Function(String?) onSubcategoryChanged;
  final void Function(bool) onIncludeTombstonedChanged;
  final Future<void> Function(String?) onAssetTap;
  final String? Function(ProjectAsset asset) incompatibilityFor;

  static const _mediaKindOptions = <String>[
    'image',
    'video',
    'audio',
    'music',
    'thumbnail',
    'video_cover',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = state.categoryCatalog;
    final selectedCategory = catalog?.categoryById(state.categoryFilter);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String?>(
                  initialValue: state.mediaKindFilter,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  hint: Text(context.tr('Kind')),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(context.tr('All')),
                    ),
                    ..._mediaKindOptions.map(
                      (kind) => DropdownMenuItem<String>(
                        value: kind,
                        child: Text(kind),
                      ),
                    ),
                  ],
                  onChanged: onMediaKindChanged,
                ),
              ),
              SizedBox(
                width: 150,
                child: TextFormField(
                  initialValue: state.sourceFilter ?? '',
                  decoration: InputDecoration(
                    hintText: context.tr('Source'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onFieldSubmitted: (value) =>
                      onSourceChanged(value.trim().isEmpty ? null : value),
                ),
              ),
              if (catalog != null)
                SizedBox(
                  width: AppThemeTokens.inputCompactWidth,
                  child: DropdownButtonFormField<String?>(
                    initialValue: state.categoryFilter,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(isDense: true),
                    hint: Text(context.tr('Category')),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(context.tr('All')),
                      ),
                      ...catalog.categories.map(
                        (category) => DropdownMenuItem<String>(
                          value: category.categoryId,
                          child: Text(category.label),
                        ),
                      ),
                    ],
                    onChanged: onCategoryChanged,
                  ),
                ),
              if (selectedCategory != null)
                SizedBox(
                  width: AppThemeTokens.inputCompactWidth,
                  child: DropdownButtonFormField<String?>(
                    initialValue: state.subcategoryFilter,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(isDense: true),
                    hint: Text(context.tr('Subcategory')),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(context.tr('All')),
                      ),
                      ...selectedCategory.subcategories.map(
                        (subcategory) => DropdownMenuItem<String>(
                          value: subcategory.subcategoryId,
                          child: Text(subcategory.label),
                        ),
                      ),
                    ],
                    onChanged: onSubcategoryChanged,
                  ),
                ),
              FilterChip(
                label: Text(context.tr('Tombstoned')),
                selected: state.includeTombstoned,
                onSelected: onIncludeTombstonedChanged,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: context.tr('Refresh'),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: assets.isEmpty
              ? Center(child: Text(context.tr('No assets')))
              : ListView.separated(
                  itemCount: assets.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    final selected = state.selectedAssetId == asset.id;
                    final incompatibility = incompatibilityFor(asset);
                    final category = catalog?.categoryById(asset.categoryId);
                    return ListTile(
                      dense: true,
                      selected: selected,
                      onTap: () => onAssetTap(asset.id),
                      leading: Icon(_iconForKind(asset.mediaKind)),
                      title: Text(
                        asset.fileName ?? asset.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        incompatibility == null
                            ? '${category?.label ?? context.tr('Uncategorized')} · ${asset.mediaKind} · ${asset.source}'
                            : context.tr(incompatibility),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (asset.metadata['candidate_type'] ==
                              'candidate_global_asset')
                            const Icon(Icons.public_rounded, size: 16),
                          if (asset.status == 'tombstoned')
                            const Icon(Icons.archive_rounded, size: 16),
                          if (incompatibility != null)
                            Icon(
                              Icons.block_rounded,
                              size: AppThemeTokens.spacing4,
                              color: theme.colorScheme.error,
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _iconForKind(String mediaKind) {
    switch (mediaKind) {
      case 'audio':
      case 'music':
        return Icons.graphic_eq_rounded;
      case 'video':
      case 'video_cover':
        return Icons.videocam_rounded;
      default:
        return Icons.image_rounded;
    }
  }
}

class _AssetDetailPane extends StatelessWidget {
  const _AssetDetailPane({
    required this.asset,
    required this.usage,
    required this.events,
    required this.understanding,
    required this.recommendation,
    required this.categoryCatalog,
    required this.isMutating,
    this.platformLabel,
    this.slotLabel,
    this.incompatibilityReason,
    this.onSelect,
    this.onSetPrimary,
    required this.onClearPrimary,
    this.onTombstone,
    this.onRestore,
    this.onQueueUnderstanding,
    this.onRefreshUnderstanding,
    this.onAttachGlobal,
    this.onCategoryAssigned,
  });

  final ProjectAsset? asset;
  final List<ProjectAssetUsage> usage;
  final List<ProjectAssetEvent> events;
  final AssetUnderstandingStatusResponse? understanding;
  final ProjectAssetRecommendationItem? recommendation;
  final ProjectAssetCategoryCatalog? categoryCatalog;
  final bool isMutating;
  final String? platformLabel;
  final String? slotLabel;
  final String? incompatibilityReason;
  final Future<void> Function()? onSelect;
  final Future<void> Function()? onSetPrimary;
  final Future<void> Function() onClearPrimary;
  final Future<void> Function()? onTombstone;
  final Future<void> Function()? onRestore;
  final Future<void> Function()? onQueueUnderstanding;
  final Future<void> Function()? onRefreshUnderstanding;
  final Future<void> Function()? onAttachGlobal;
  final Future<void> Function(String?, String?)? onCategoryAssigned;

  @override
  Widget build(BuildContext context) {
    if (asset == null) {
      return SizedBox(
        height: 180,
        child: Center(child: Text(context.tr('Select an asset'))),
      );
    }
    final isTombstoned = asset!.status == 'tombstoned';
    final category = categoryCatalog?.categoryById(asset!.categoryId);
    final result = understanding?.result;
    final suggestedTags =
        result?.tags
            .where((tag) => !tag.acceptedByUser && !tag.rejectedByUser)
            .toList() ??
        const <AssetSemanticTag>[];
    final acceptedTags =
        result?.tags.where((tag) => tag.acceptedByUser).toList() ??
        const <AssetSemanticTag>[];
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (slotLabel != null) ...[
            Text(
              platformLabel == null
                  ? slotLabel!
                  : '$platformLabel · $slotLabel',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppThemeTokens.spacing2),
          ],
          Text(
            asset!.fileName ?? asset!.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text('${asset!.mediaKind} · ${asset!.source}'),
          if (incompatibilityReason != null) ...[
            const SizedBox(height: AppThemeTokens.spacing2),
            Text(
              context.tr(incompatibilityReason!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (categoryCatalog != null) ...[
            const SizedBox(height: AppThemeTokens.spacing2),
            DropdownButtonFormField<String?>(
              initialValue: asset!.categoryId,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.tr('Category')),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(context.tr('Uncategorized')),
                ),
                ...categoryCatalog!.categories.map(
                  (item) => DropdownMenuItem<String>(
                    value: item.categoryId,
                    child: Text(item.label),
                  ),
                ),
              ],
              onChanged: isMutating
                  ? null
                  : (value) => onCategoryAssigned?.call(value, null),
            ),
            if (category != null && category.subcategories.isNotEmpty) ...[
              const SizedBox(height: AppThemeTokens.spacing2),
              DropdownButtonFormField<String?>(
                initialValue: asset!.subcategoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('Subcategory'),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(context.tr('No subcategory')),
                  ),
                  ...category.subcategories.map(
                    (item) => DropdownMenuItem<String>(
                      value: item.subcategoryId,
                      child: Text(item.label),
                    ),
                  ),
                ],
                onChanged: isMutating
                    ? null
                    : (value) =>
                          onCategoryAssigned?.call(category.categoryId, value),
              ),
            ],
            if (asset!.suggestedExportFileName != null)
              Text(
                context.tr('Export name: {name}', {
                  'name': asset!.suggestedExportFileName,
                }),
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilledButton.tonal(
                onPressed: isMutating || incompatibilityReason != null
                    ? null
                    : onSelect,
                child: Text(context.tr('Select')),
              ),
              OutlinedButton(
                onPressed: isMutating ? null : onSetPrimary,
                child: Text(context.tr('Primary')),
              ),
              OutlinedButton(
                onPressed: isMutating ? null : onClearPrimary,
                child: Text(context.tr('Clear')),
              ),
              OutlinedButton(
                onPressed: isMutating
                    ? null
                    : (isTombstoned ? onRestore : onTombstone),
                child: Text(context.tr(isTombstoned ? 'Restore' : 'Remove')),
              ),
              OutlinedButton(
                onPressed: isMutating ? null : onQueueUnderstanding,
                child: Text(context.tr('Analyze')),
              ),
              OutlinedButton(
                onPressed: isMutating ? null : onRefreshUnderstanding,
                child: Text(context.tr('Status')),
              ),
              if (recommendation?.requiresProjectAttachment == true)
                FilledButton.tonal(
                  onPressed: isMutating ? null : onAttachGlobal,
                  child: Text(context.tr('Attach global')),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (understanding?.job != null)
            Text(
              context.tr('Understanding: {status}', {
                'status': understanding!.job!.status,
              }),
            ),
          if (acceptedTags.isNotEmpty)
            Text(
              context.tr('Accepted tags: {tags}', {
                'tags': acceptedTags.map((tag) => tag.label).join(', '),
              }),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (suggestedTags.isNotEmpty)
            Text(
              context.tr('Suggested tags: {tags}', {
                'tags': suggestedTags.map((tag) => tag.label).join(', '),
              }),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (recommendation != null && recommendation!.fitReasons.isNotEmpty)
            Text(
              context.tr('Fit: {reason}', {
                'reason': recommendation!.fitReasons.first.toString(),
              }),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (recommendation != null && recommendation!.warnings.isNotEmpty)
            Text(
              context.tr('Warnings: {warnings}', {
                'warnings': recommendation!.warnings.join(', '),
              }),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (recommendation?.candidateGlobalAsset == true)
            Text(context.tr('Global candidate')),
          Text(context.tr('Usage: {count}', {'count': '${usage.length}'})),
          Text(context.tr('Events: {count}', {'count': '${events.length}'})),
        ],
      ),
    );
  }
}
