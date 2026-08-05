import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../data/models/video_source_intake.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../../providers/video_source_intake_provider.dart';
import '../../../data/services/video_source_device_media_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_tokens.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/project_picker_action.dart';

class VideoSourceIntakeScreen extends ConsumerStatefulWidget {
  const VideoSourceIntakeScreen({
    super.key,
    required this.contentId,
    this.projectId,
  });

  final String contentId;
  final String? projectId;

  @override
  ConsumerState<VideoSourceIntakeScreen> createState() =>
      _VideoSourceIntakeScreenState();
}

class _VideoSourceIntakeScreenState
    extends ConsumerState<VideoSourceIntakeScreen> {
  _SourceFilter _filter = _SourceFilter.all;

  @override
  Widget build(BuildContext context) {
    final projectId = widget.projectId ?? ref.watch(activeProjectIdProvider);
    if (projectId == null || projectId.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Prepare video sources')),
          actions: const [ProjectPickerAction()],
        ),
        body: Center(
          child: Padding(
            padding: AppSpacing.page(context),
            child: Text(
              context.tr('Select a project before preparing video sources.'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final intakeKey = VideoSourceIntakeKey(projectId, widget.contentId);
    final state = ref.watch(videoSourceIntakeProvider(intakeKey));
    final controller = ref.read(videoSourceIntakeProvider(intakeKey).notifier);
    final deviceMediaStore = ref.watch(videoSourceDeviceMediaStoreProvider);

    ref.listen(videoSourceIntakeProvider(intakeKey), (previous, next) {
      if (!mounted) return;
      if (next.notice != null && next.notice != previous?.notice) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(next.notice!)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Prepare video sources')),
        actions: widget.projectId == null
            ? const [ProjectPickerAction()]
            : const [],
      ),
      body: _buildBody(
        context,
        state: state,
        controller: controller,
        intakeKey: intakeKey,
        deviceMediaStore: deviceMediaStore,
      ),
      bottomNavigationBar: state.folder == null
          ? null
          : _FinalActions(
              state: state,
              onReady: controller.markSourcesReady,
              onGenerate: controller.generateVideo,
            ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required VideoSourceIntakeState state,
    required VideoSourceIntakeController controller,
    required VideoSourceIntakeKey intakeKey,
    required VideoSourceDeviceMediaStore deviceMediaStore,
  }) {
    if (state.isLoading && state.folder == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.folder == null) {
      return Center(
        child: Padding(
          padding: AppSpacing.page(context),
          child: AppErrorView(
            scope: 'video_source_intake.load',
            title: 'Could not open the source folder',
            message: state.lastError,
            onRetry: controller.load,
            contextData: {
              'projectId': intakeKey.projectId,
              'contentId': intakeKey.contentId,
            },
          ),
        ),
      );
    }

    final folder = state.folder!;
    final sources = _filteredSources(folder.activeSources);
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: AppSpacing.page(context),
        children: [
          _IntakeHeader(folder: folder),
          const SizedBox(height: AppSpacing.lg),
          _AddSourcePanel(
            busy: state.isBusy,
            onFiles: () => _pickFiles(controller),
            onDeviceMedia: deviceMediaStore.isAndroidMediaLibraryAvailable
                ? () => _pickDeviceMedia(controller)
                : null,
            onText: () => _showTextSheet(controller),
            onScript: () => _pasteScript(controller),
            onLink: () => _showLinkSheet(controller),
          ),
          if (state.isUploading) ...[
            const SizedBox(height: AppSpacing.md),
            _UploadProgress(progress: state.uploadProgress),
          ],
          if (state.lastError != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineMessage(
              message: context.tr(state.lastError!),
              isError: true,
              onDismiss: controller.clearMessages,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _LibraryHeader(
            total: folder.activeSources.length,
            filter: _filter,
            onFilterChanged: (filter) => setState(() => _filter = filter),
          ),
          const SizedBox(height: AppSpacing.md),
          if (sources.isEmpty)
            _EmptyLibrary(hasAnySources: folder.activeSources.isNotEmpty)
          else
            ...sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SourceCard(
                  source: source,
                  busy: state.isBusy,
                  onRetry: source.type.isBinary
                      ? null
                      : () => controller.retrySource(source.id),
                  onReplace: source.type.isBinary
                      ? () => _pickReplacement(controller, source.id)
                      : null,
                  onRemove: () => _confirmRemove(controller, source),
                  canDeleteFromDevice:
                      deviceMediaStore.isAndroidMediaLibraryAvailable &&
                      source.status == VideoSourceStatus.ready &&
                      state.deletableSourceIds.contains(source.id),
                  isDeletingFromDevice: state.isDeletingDeviceMedia,
                  onDeleteFromDevice: () =>
                      _confirmDeviceDeletion(controller, source),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  List<VideoSource> _filteredSources(List<VideoSource> sources) {
    return switch (_filter) {
      _SourceFilter.all => sources,
      _SourceFilter.files =>
        sources.where((source) => source.type.isBinary).toList(growable: false),
      _SourceFilter.text =>
        sources
            .where((source) => source.type == VideoSourceType.pastedText)
            .toList(growable: false),
      _SourceFilter.links =>
        sources
            .where((source) => source.type == VideoSourceType.publicLink)
            .toList(growable: false),
    };
  }

  Future<void> _pickFiles(VideoSourceIntakeController controller) async {
    final files = await ref
        .read(videoSourceFilePickerProvider)
        .pickMediaFiles();
    if (files.isEmpty) return;
    await controller.addFiles(files);
  }

  Future<void> _pickDeviceMedia(VideoSourceIntakeController controller) async {
    final selected = await ref
        .read(androidMediaLibraryProvider)
        .pickPhotoAndVideoFiles();
    if (selected.isEmpty) return;

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    await controller.addFiles(
      selected.indexed
          .map(
            (entry) => VideoSourceUploadFile(
              clientFileId: 'device-media-$timestamp-${entry.$1}',
              fileName: entry.$2.fileName,
              mimeType: entry.$2.mimeType,
              sizeBytes: entry.$2.sizeBytes,
              path: entry.$2.cachePath,
              deviceMediaUri: entry.$2.contentUri,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _pickReplacement(
    VideoSourceIntakeController controller,
    String sourceId,
  ) async {
    final files = await ref
        .read(videoSourceFilePickerProvider)
        .pickMediaFiles();
    if (files.isEmpty) return;
    await controller.replaceSource(sourceId, files.first);
  }

  Future<void> _showTextSheet(VideoSourceIntakeController controller) async {
    final textController = TextEditingController();
    final labelController = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => _TextSourceSheet(
          textController: textController,
          labelController: labelController,
          onSubmit: () async {
            if (textController.text.trim().isEmpty) return;
            Navigator.of(sheetContext).pop();
            await controller.addText(
              text: textController.text,
              label: labelController.text,
            );
          },
        ),
      );
    } finally {
      textController.dispose();
      labelController.dispose();
    }
  }

  Future<void> _pasteScript(VideoSourceIntakeController controller) async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final script = clipboard?.text?.trim() ?? '';
    if (script.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('The clipboard does not contain any text.')),
        ),
      );
      return;
    }
    await controller.addText(text: script, label: 'Script de la vidéo');
  }

  Future<void> _showLinkSheet(VideoSourceIntakeController controller) async {
    final urlController = TextEditingController();
    final labelController = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => _LinkSourceSheet(
          urlController: urlController,
          labelController: labelController,
          onSubmit: () async {
            if (urlController.text.trim().isEmpty) return;
            Navigator.of(sheetContext).pop();
            await controller.addLink(
              url: urlController.text,
              label: labelController.text,
            );
          },
        ),
      );
    } finally {
      urlController.dispose();
      labelController.dispose();
    }
  }

  Future<void> _confirmRemove(
    VideoSourceIntakeController controller,
    VideoSource source,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Remove this source?')),
        content: Text(
          context.tr(
            'The source leaves this folder. A reusable project asset is not deleted from other content.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('Remove source')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.removeSource(source.id);
  }

  Future<void> _confirmDeviceDeletion(
    VideoSourceIntakeController controller,
    VideoSource source,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Delete from this device?')),
        content: Text(
          context.tr(
            'This copy is stored safely in ContentGlows. Android will ask you for final confirmation before it is deleted from this device.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('Delete from device')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteFromDevice(source);
  }
}

class _IntakeHeader extends StatelessWidget {
  const _IntakeHeader({required this.folder});
  final VideoSourceFolder folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReady = folder.isCurrentRevisionReady;
    return Card(
      child: Padding(
        padding: AppSpacing.card(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.video_library_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Build your source folder'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        context.tr(
                          'Gather the material first. Save it for later or request generation when everything is ready.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  label: context.tr(isReady ? 'Ready' : 'Collecting'),
                  icon: isReady
                      ? Icons.check_circle_outline_rounded
                      : Icons.pending_outlined,
                  color: isReady
                      ? AppTheme.approveColor
                      : theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr(
                '“Sources ready” stores this revision without generating. “Generate video” sends this revision once to the video workflow.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSourcePanel extends StatelessWidget {
  const _AddSourcePanel({
    required this.busy,
    required this.onFiles,
    this.onDeviceMedia,
    required this.onText,
    required this.onScript,
    required this.onLink,
  });

  final bool busy;
  final VoidCallback onFiles;
  final VoidCallback? onDeviceMedia;
  final VoidCallback onText;
  final VoidCallback onScript;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('Add sources'), style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.tr(
            'Select one or several videos, images or audio files at once. You can also add pasted text or a public link.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : onFiles,
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(context.tr('Select media')),
            ),
            if (onDeviceMedia != null)
              OutlinedButton.icon(
                onPressed: busy ? null : onDeviceMedia,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(context.tr('Select photos and videos')),
              ),
            OutlinedButton.icon(
              onPressed: busy ? null : onText,
              icon: const Icon(Icons.notes_rounded),
              label: Text(context.tr('Pasted text')),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onScript,
              icon: const Icon(Icons.content_paste_rounded),
              label: Text(context.tr('Paste video script')),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onLink,
              icon: const Icon(Icons.link_rounded),
              label: Text(context.tr('Public link')),
            ),
          ],
        ),
      ],
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.progress});
  final Map<String, double> progress;

  @override
  Widget build(BuildContext context) {
    final values = progress.values;
    final average = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    return Semantics(
      label: context.tr('Uploading media sources'),
      value: average == null ? null : '${(average * 100).round()}%',
      child: Card(
        child: Padding(
          padding: AppSpacing.card(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Uploading {count} file(s)', {
                  'count': progress.length,
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(value: average),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.total,
    required this.filter,
    required this.onFilterChanged,
  });

  final int total;
  final _SourceFilter filter;
  final ValueChanged<_SourceFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Source library'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _SourceFilter.values
              .map(
                (entry) => ChoiceChip(
                  selected: entry == filter,
                  onSelected: (_) => onFilterChanged(entry),
                  label: Text(
                    entry == _SourceFilter.all
                        ? '${context.tr(entry.labelKey)} ($total)'
                        : context.tr(entry.labelKey),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.busy,
    required this.onReplace,
    required this.onRemove,
    required this.canDeleteFromDevice,
    required this.isDeletingFromDevice,
    required this.onDeleteFromDevice,
    this.onRetry,
  });

  final VideoSource source;
  final bool busy;
  final VoidCallback? onRetry;
  final VoidCallback? onReplace;
  final VoidCallback onRemove;
  final bool canDeleteFromDevice;
  final bool isDeletingFromDevice;
  final VoidCallback onDeleteFromDevice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: AppSpacing.card(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SourcePreview(source: source),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _metadataLabel(context, source),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _StatusChip(
                        label: context.tr(source.status.labelKey),
                        icon: source.status.icon,
                        color: source.status.color(theme),
                      ),
                      if (source.status.canRetry && onRetry != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: busy ? null : onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(context.tr('Retry')),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<_SourceMenuAction>(
                  enabled: !busy,
                  tooltip: context.tr('Source actions'),
                  onSelected: (action) {
                    switch (action) {
                      case _SourceMenuAction.retry:
                        onRetry?.call();
                      case _SourceMenuAction.replace:
                        onReplace?.call();
                      case _SourceMenuAction.remove:
                        onRemove();
                    }
                  },
                  itemBuilder: (context) => [
                    if (source.status.canRetry && onRetry != null)
                      PopupMenuItem(
                        value: _SourceMenuAction.retry,
                        child: Text(context.tr('Retry')),
                      ),
                    if (onReplace != null)
                      PopupMenuItem(
                        value: _SourceMenuAction.replace,
                        child: Text(context.tr('Replace')),
                      ),
                    PopupMenuItem(
                      value: _SourceMenuAction.remove,
                      child: Text(context.tr('Remove source')),
                    ),
                  ],
                ),
              ],
            ),
            if (canDeleteFromDevice) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                container: true,
                label: context.tr('Stored safely on ContentGlows'),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Stored safely on ContentGlows'),
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        context.tr(
                          'You can delete this phone copy. Android will ask for final confirmation.',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: busy ? null : onDeleteFromDevice,
                        icon: isDeletingFromDevice
                            ? const _ButtonProgress()
                            : const Icon(Icons.delete_outline_rounded),
                        label: Text(context.tr('Delete from device')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourcePreview extends StatelessWidget {
  const _SourcePreview({required this.source});
  final VideoSource source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = source.safeMetadata.previewUrl;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: previewUrl != null && source.type.isBinary
          ? Image.network(
              previewUrl,
              width: AppThemeTokens.spacing6 * 2,
              height: AppThemeTokens.spacing6 * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(source.type.icon),
            )
          : Icon(
              source.type.icon,
              color: theme.colorScheme.onSecondaryContainer,
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Chip(
        avatar: Icon(icon, color: color),
        label: Text(label),
        side: BorderSide(color: color),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isError ? scheme.errorContainer : scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: AppSpacing.card(context),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color: isError
                  ? scheme.onErrorContainer
                  : scheme.onSecondaryContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
            IconButton(
              onPressed: onDismiss,
              tooltip: context.tr('Dismiss'),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.hasAnySources});
  final bool hasAnySources;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.card(context),
        child: Column(
          children: [
            const Icon(Icons.folder_open_rounded),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr(
                hasAnySources
                    ? 'No sources match this filter.'
                    : 'Add your first source to prepare the video.',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalActions extends StatelessWidget {
  const _FinalActions({
    required this.state,
    required this.onReady,
    required this.onGenerate,
  });

  final VideoSourceIntakeState state;
  final Future<void> Function() onReady;
  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    final folder = state.folder!;
    final blockingCount = folder.blockingSourceCount;
    final blockingMessage = blockingCount == 0
        ? null
        : blockingCount == 1
        ? context.tr('1 source must be fixed before continuing.')
        : context.tr('{count} sources must be fixed before continuing.', {
            'count': blockingCount,
          });
    final canAct = state.canFinalize;
    final readyAlready = folder.isCurrentRevisionReady;
    final pending =
        state.isGenerating ||
        folder.enqueueStatus == VideoSourceEnqueueStatus.enqueuePending;

    return SafeArea(
      child: Material(
        elevation: AppSpacing.xs,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: AppSpacing.page(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (blockingMessage != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        blockingMessage,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < AppThemeTokens.mobileBreakpoint;
                  final readyButton = OutlinedButton.icon(
                    onPressed: canAct && !readyAlready ? onReady : null,
                    icon: state.isMarkingReady
                        ? const _ButtonProgress()
                        : const Icon(Icons.inventory_2_outlined),
                    label: Text(context.tr('Sources ready')),
                  );
                  final generateButton = FilledButton.icon(
                    onPressed: canAct && !pending ? onGenerate : null,
                    icon: pending
                        ? const _ButtonProgress()
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(context.tr('Generate video')),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        readyButton,
                        const SizedBox(height: AppSpacing.sm),
                        generateButton,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: readyButton),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: generateButton),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: AppSpacing.md,
      child: CircularProgressIndicator(strokeWidth: AppSpacing.xxs),
    );
  }
}

class _TextSourceSheet extends StatelessWidget {
  const _TextSourceSheet({
    required this.textController,
    required this.labelController,
    required this.onSubmit,
  });

  final TextEditingController textController;
  final TextEditingController labelController;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Add pasted text'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: labelController,
            decoration: InputDecoration(
              labelText: context.tr('Label (optional)'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: textController,
            minLines: 5,
            maxLines: 10,
            maxLength: 100000,
            decoration: InputDecoration(
              labelText: context.tr('Source text'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.add_rounded),
            label: Text(context.tr('Add text')),
          ),
        ],
      ),
    );
  }
}

class _LinkSourceSheet extends StatelessWidget {
  const _LinkSourceSheet({
    required this.urlController,
    required this.labelController,
    required this.onSubmit,
  });

  final TextEditingController urlController;
  final TextEditingController labelController;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Add public link'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: labelController,
            decoration: InputDecoration(
              labelText: context.tr('Label (optional)'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            maxLength: 2048,
            decoration: InputDecoration(
              labelText: context.tr('Public HTTP(S) link'),
              hintText: 'https://example.com',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.add_link_rounded),
            label: Text(context.tr('Add link')),
          ),
        ],
      ),
    );
  }
}

enum _SourceFilter {
  all('All'),
  files('Files'),
  text('Text'),
  links('Links');

  const _SourceFilter(this.labelKey);
  final String labelKey;
}

enum _SourceMenuAction { retry, replace, remove }

extension on VideoSourceType {
  bool get isBinary => switch (this) {
    VideoSourceType.binaryVideo ||
    VideoSourceType.binaryImage ||
    VideoSourceType.binaryAudio => true,
    _ => false,
  };

  IconData get icon => switch (this) {
    VideoSourceType.binaryVideo => Icons.movie_outlined,
    VideoSourceType.binaryImage => Icons.image_outlined,
    VideoSourceType.binaryAudio => Icons.graphic_eq_rounded,
    VideoSourceType.publicLink => Icons.link_rounded,
    VideoSourceType.pastedText => Icons.notes_rounded,
    VideoSourceType.unknown => Icons.insert_drive_file_outlined,
  };
}

extension on VideoSourceStatus {
  String get labelKey => switch (this) {
    VideoSourceStatus.pendingValidation => 'Validation pending',
    VideoSourceStatus.processing => 'Processing',
    VideoSourceStatus.ready => 'Ready',
    VideoSourceStatus.metadataUnavailable => 'Preview unavailable',
    VideoSourceStatus.failed => 'Needs attention',
    VideoSourceStatus.replacementPending => 'Replacement pending',
    VideoSourceStatus.orphanCleanupNeeded => 'Recovery required',
    VideoSourceStatus.superseded => 'Replaced',
    VideoSourceStatus.removed => 'Removed',
    VideoSourceStatus.unknown => 'Unknown',
  };

  IconData get icon => switch (this) {
    VideoSourceStatus.ready => Icons.check_circle_outline_rounded,
    VideoSourceStatus.processing ||
    VideoSourceStatus.pendingValidation ||
    VideoSourceStatus.replacementPending => Icons.pending_outlined,
    VideoSourceStatus.failed ||
    VideoSourceStatus.metadataUnavailable ||
    VideoSourceStatus.orphanCleanupNeeded => Icons.error_outline_rounded,
    VideoSourceStatus.superseded ||
    VideoSourceStatus.removed => Icons.archive_outlined,
    VideoSourceStatus.unknown => Icons.help_outline_rounded,
  };

  Color color(ThemeData theme) => switch (this) {
    VideoSourceStatus.ready => AppTheme.approveColor,
    VideoSourceStatus.processing ||
    VideoSourceStatus.pendingValidation ||
    VideoSourceStatus.replacementPending => theme.colorScheme.primary,
    VideoSourceStatus.failed ||
    VideoSourceStatus.metadataUnavailable ||
    VideoSourceStatus.orphanCleanupNeeded => theme.colorScheme.error,
    _ => theme.colorScheme.onSurfaceVariant,
  };
}

String _metadataLabel(BuildContext context, VideoSource source) {
  final metadata = source.safeMetadata;
  final parts = <String>[];
  if (metadata.mimeType != null) parts.add(metadata.mimeType!);
  if (metadata.sizeBytes != null) parts.add(_formatBytes(metadata.sizeBytes!));
  if (metadata.durationMs != null) {
    parts.add(_formatDuration(metadata.durationMs!));
  }
  if (metadata.width != null && metadata.height != null) {
    parts.add('${metadata.width} × ${metadata.height}');
  }
  if (metadata.characterCount != null) {
    parts.add(
      context.tr('{count} characters', {'count': metadata.characterCount}),
    );
  }
  if (metadata.publicHost != null) parts.add(metadata.publicHost!);
  return parts.isEmpty
      ? context.tr('Safe metadata pending')
      : parts.join(' • ');
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String _formatDuration(int milliseconds) {
  final totalSeconds = Duration(milliseconds: milliseconds).inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
