import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/models/content_item.dart';
import '../../../data/models/social_placement.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_tokens.dart';
import '../../widgets/project_asset_picker.dart';

class PlacementPanelSheet extends ConsumerStatefulWidget {
  const PlacementPanelSheet({super.key, required this.item});

  final ContentItem item;

  @override
  ConsumerState<PlacementPanelSheet> createState() =>
      _PlacementPanelSheetState();
}

class _PlacementPanelSheetState extends ConsumerState<PlacementPanelSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final accountsState = await ref.read(publishAccountsStateProvider.future);
    if (!mounted) return;
    await ref
        .read(socialPlacementProvider(widget.item.id).notifier)
        .refresh(
          planPlatforms: widget.item.channels
              .map((channel) => channel.name)
              .toList(),
          publishTargets: publishPlacementTargetsFor(
            widget.item.channels,
            accountsState.accounts,
          ),
          locale: ref.read(projectAssetCategoryLocaleProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(socialPlacementProvider(widget.item.id));
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppThemeTokens.spacing4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Publication assets'),
                        style: theme.textTheme.titleLarge,
                      ),
                      if (state.registryVersion != null)
                        Text(
                          context.tr('Registry {version}', {
                            'version': state.registryVersion,
                          }),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Refresh'),
                  onPressed: state.isBusy ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: context.tr('Close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (state.isBusy) const LinearProgressIndicator(),
          if (state.needsRegistryRefresh)
            _PanelNotice(
              icon: Icons.sync_problem_rounded,
              message: context.tr(
                'The placement rules changed. Refresh before publishing.',
              ),
              color: theme.colorScheme.error,
            ),
          if (state.lastError != null)
            _PanelNotice(
              icon: Icons.cloud_off_rounded,
              message: context.tr('Placement readiness is unavailable.'),
              color: theme.colorScheme.error,
            ),
          Expanded(
            child: state.displayPlatforms.isEmpty && !state.isBusy
                ? Center(
                    child: Text(
                      widget.item.channels.isEmpty
                          ? context.tr('No publishing channels selected')
                          : context.tr('No asset placements for this content'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppThemeTokens.spacing4,
                      AppThemeTokens.spacing1,
                      AppThemeTokens.spacing4,
                      AppThemeTokens.spacing6,
                    ),
                    children: [
                      for (final platform in state.displayPlatforms)
                        _PlatformSection(
                          platform: platform,
                          onChoose: (slot) => _choose(platform, slot),
                          onGenerate: (slot) => _generate(platform, slot),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _choose(
    PlatformPlacementPlan platform,
    PlacementSlot slot,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: const EdgeInsets.all(AppThemeTokens.spacing4),
          child: ProjectAssetPicker(
            targetType: 'content',
            targetId: widget.item.id,
            usageAction: 'publish_media',
            placement: slot.placementId,
            allowedMediaKinds: slot.mediaKinds.toSet(),
            platformLabel: platform.label,
            slotLabel: slot.label,
            selectAsPrimary: true,
            onSelected: (_) {
              Navigator.pop(context);
              _refresh();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _generate(
    PlatformPlacementPlan platform,
    PlacementSlot slot,
  ) async {
    final projectId = ref.read(activeProjectIdProvider);
    if (projectId == null || !slot.mediaKinds.contains('image')) return;
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.listImageProfiles(projectId: projectId);
      if (!mounted) return;
      final profiles = response.items.where((profile) => profile.isFlux).toList();
      if (profiles.isEmpty) {
        _showMessage(
          context.tr(
            'No compatible image profile is available. Choose an existing asset.',
          ),
        );
        return;
      }
      final profile = await showModalBottomSheet(
        context: context,
        useSafeArea: true,
        builder: (context) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppThemeTokens.spacing4),
          children: [
            Text(
              '${platform.label} · ${slot.label}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppThemeTokens.spacing3),
            for (final profile in profiles)
              ListTile(
                title: Text(profile.name),
                subtitle: Text(profile.description),
                onTap: () => Navigator.pop(context, profile),
              ),
          ],
        ),
      );
      if (profile == null || !mounted) return;
      final result = await api.queueImageGenerationFromProfile(
        projectId: projectId,
        profileId: profile.profileId,
        titleText: widget.item.title,
        subtitleText: widget.item.summary,
        altText: '${widget.item.title} — ${slot.label}',
        customPrompt:
            'Create the ${slot.label} asset for ${platform.label}.',
      );
      final assetId = result.assetId;
      if (assetId != null && assetId.isNotEmpty) {
        await api.setProjectAssetPrimary(
          projectId: projectId,
          assetId: assetId,
          targetType: 'content',
          targetId: widget.item.id,
          usageAction: 'publish_media',
          placement: slot.placementId,
        );
        await ref.read(projectAssetLibraryProvider.notifier).refresh();
        await _refresh();
        if (mounted) _showMessage(context.tr('Generated asset attached'));
      } else if (mounted) {
        _showMessage(
          context.tr(
            'Image generation started. Refresh when the asset is ready.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.tr('Could not start image generation.'));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _PlatformSection extends StatelessWidget {
  const _PlatformSection({
    required this.platform,
    required this.onChoose,
    required this.onGenerate,
  });

  final PlatformPlacementPlan platform;
  final void Function(PlacementSlot slot) onChoose;
  final void Function(PlacementSlot slot) onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppThemeTokens.spacing5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                platform.canPublish
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                color: platform.canPublish
                    ? AppTheme.approveColor
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: AppThemeTokens.spacing2),
              Expanded(
                child: Text(
                  platform.label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                platform.canPublish
                    ? context.tr('Ready')
                    : context.tr('Blocked'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: platform.canPublish
                      ? AppTheme.approveColor
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeTokens.spacing2),
          for (final slot in platform.slots)
            _SlotCard(
              slot: slot,
              onChoose: () => onChoose(slot),
              onGenerate: slot.mediaKinds.contains('image')
                  ? () => onGenerate(slot)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.onChoose,
    this.onGenerate,
  });

  final PlacementSlot slot;
  final VoidCallback onChoose;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocking = slot.hasBlockingIssue;
    final warning = slot.issues.isNotEmpty;
    final color = slot.isAttached
        ? AppTheme.approveColor
        : blocking
        ? theme.colorScheme.error
        : warning
        ? AppTheme.warningColor
        : theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.only(bottom: AppThemeTokens.spacing2),
      child: Padding(
        padding: const EdgeInsets.all(AppThemeTokens.spacing3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              slot.isAttached
                  ? Icons.check_circle_rounded
                  : blocking
                  ? Icons.error_rounded
                  : warning
                  ? Icons.warning_amber_rounded
                  : Icons.add_photo_alternate_outlined,
              color: color,
            ),
            const SizedBox(width: AppThemeTokens.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.label, style: theme.textTheme.titleSmall),
                  Text(
                    slot.required
                        ? context.tr('Required')
                        : slot.recommended
                        ? context.tr('Recommended')
                        : context.tr('Optional'),
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                  if (slot.issues.isNotEmpty)
                    Text(
                      _issueLabel(context, slot.issues.first),
                      style: theme.textTheme.bodySmall,
                    ),
                  if (slot.selectedAssetId != null)
                    Text(
                      context.tr('Asset {id}', {'id': slot.selectedAssetId}),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppThemeTokens.spacing2),
            Column(
              children: [
                TextButton(
                  key: Key('placement-choose-${slot.placementId}'),
                  onPressed: onChoose,
                  child: Text(context.tr('Choose')),
                ),
                if (onGenerate != null && !slot.isAttached)
                  TextButton(
                    key: Key('placement-generate-${slot.placementId}'),
                    onPressed: onGenerate,
                    child: Text(context.tr('Generate')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelNotice extends StatelessWidget {
  const _PanelNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemeTokens.spacing4,
        vertical: AppThemeTokens.spacing2,
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppThemeTokens.spacing2),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

List<PublishPlatformTarget> publishPlacementTargetsFor(
  List<PublishingChannel> channels,
  List<PublishAccount> accounts,
) {
  final targets = <PublishPlatformTarget>[];
  for (final channel in channels) {
    final candidates = accounts
        .where(
          (account) =>
              account.isActive && account.platform == channel.name.toLowerCase(),
        )
        .toList();
    final selected = candidates.where((account) => account.isDefault).firstOrNull ??
        (candidates.length == 1 ? candidates.single : null);
    if (selected != null) {
      targets.add(
        PublishPlatformTarget(platform: channel.name, accountId: selected.id),
      );
    }
  }
  return targets;
}

String _issueLabel(BuildContext context, PlacementIssue issue) {
  return switch (issue.code) {
    'PFL_MISSING_REQUIRED' => issue.isBlocking
        ? context.tr('A required asset is missing.')
        : context.tr('A recommended asset is missing.'),
    'PFL_ASSET_STATUS_BLOCKED' =>
      context.tr('The selected asset is unavailable.'),
    'PFL_ASSET_INCOMPATIBLE' =>
      context.tr('The selected asset is incompatible.'),
    'PFL_STORAGE_UNAVAILABLE' =>
      context.tr('The selected asset is not ready for publishing.'),
    'PFL_REGISTRY_STALE' => context.tr('Placement rules must be refreshed.'),
    _ => issue.message.isEmpty
        ? context.tr('This placement needs attention.')
        : issue.message,
  };
}
