import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/content_audit.dart';
import '../../../data/models/content_item.dart';
import '../../../data/models/affiliate_link.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/project_asset_picker.dart';
import 'editor_formatting.dart';
import 'placement_panel.dart';
import 'platform_preview_sheet.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final String contentId;

  const EditorScreen({super.key, required this.contentId});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  bool _isEditing = false;
  bool _isPreview = true;
  bool _hasChanges = false;

  ContentItem? _item;
  Future<ContentAuditTrail>? _auditFuture;
  String? _placementLoadKey;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _initFromItem(ContentItem item) {
    if (_item?.id != item.id) {
      _item = item;
      _titleController.text = item.title;
      _bodyController.text = item.body;
      _hasChanges = false;
      _auditFuture = _loadAuditTrail(item.id);
      _schedulePlacementRefresh(item);
    }
  }

  void _schedulePlacementRefresh(ContentItem item) {
    final key = '${item.id}:${item.channels.map((channel) => channel.name).join(',')}';
    if (_placementLoadKey == key) return;
    _placementLoadKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshPlacements(item);
    });
  }

  Future<void> _refreshPlacements(ContentItem item) async {
    if (item.channels.isEmpty) return;
    final accountsState = await ref.read(publishAccountsStateProvider.future);
    if (!mounted || _item?.id != item.id) return;
    await ref
        .read(socialPlacementProvider(item.id).notifier)
        .refresh(
          planPlatforms: item.channels.map((channel) => channel.name).toList(),
          publishTargets: publishPlacementTargetsFor(
            item.channels,
            accountsState.accounts,
          ),
          locale: ref.read(projectAssetCategoryLocaleProvider),
        );
  }

  Future<ContentAuditTrail> _loadAuditTrail(String contentId) async {
    final api = ref.read(apiServiceProvider);
    return api.fetchContentAuditTrail(contentId);
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(contentDetailProvider(widget.contentId));

    return contentAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Error'))),
        body: Center(
          child: AppErrorView(
            scope: 'editor.load_pending_content',
            title: context.tr('Could not open the editor'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () =>
                ref.invalidate(contentDetailProvider(widget.contentId)),
          ),
        ),
      ),
      data: (item) {
        _initFromItem(item);

        return Scaffold(
          appBar: _buildAppBar(item),
          body: _buildBody(item),
          bottomNavigationBar: _buildBottomBar(item),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ContentItem item) {
    final typeColor = AppTheme.colorForContentType(item.typeLabel);
    final theme = Theme.of(context);
    final projectId = ref.watch(activeProjectIdProvider);
    final canOpenAssetLibrary =
        projectId != null && projectId.trim().isNotEmpty;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (_hasChanges) {
            _showDiscardDialog();
          } else {
            context.pop();
          }
        },
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compact,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: typeColor.withAlpha(AppAlpha.tint),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Text(
              item.typeLabel,
              style: TextStyle(color: typeColor, fontSize: AppText.compact),
            ),
          ),
          if (item.projectName != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              item.projectName!,
              style: TextStyle(
                fontSize: AppText.compact,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        // Platform preview
        if (item.channels.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.devices_rounded),
            tooltip: context.tr('Platform preview'),
            onPressed: () => _showPlatformPreview(item),
          ),
        if (item.channels.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.view_module_outlined),
            tooltip: context.tr('Publication assets'),
            onPressed: () => _showPlacementPanel(item),
          ),
        IconButton(
          icon: const Icon(Icons.perm_media_rounded),
          tooltip: context.tr('Project assets'),
          onPressed: canOpenAssetLibrary
              ? () => _showProjectAssetPicker(item)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.video_library_rounded),
          tooltip: context.tr('Prepare video sources'),
          onPressed: canOpenAssetLibrary
              ? () => context.push('/editor/${item.id}/video/sources')
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.video_settings_rounded),
          tooltip: 'Video timeline',
          onPressed: () => context.push('/editor/${item.id}/video'),
        ),
        // Toggle edit/preview
        IconButton(
          icon: Icon(
            _isPreview ? Icons.edit_rounded : Icons.visibility_rounded,
          ),
          tooltip: _isPreview ? context.tr('Edit') : context.tr('Preview'),
          onPressed: () => setState(() {
            _isPreview = !_isPreview;
            _isEditing = !_isPreview;
          }),
        ),
      ],
    );
  }

  Widget _buildBody(ContentItem item) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    return Column(
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: _isEditing
              ? TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('Title'),
                    border: InputBorder.none,
                    filled: false,
                  ),
                  onChanged: (_) => setState(() => _hasChanges = true),
                )
              : Text(
                  _titleController.text,
                  style: TextStyle(
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
        ),
        // Channels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.send_rounded,
                size: AppSizes.iconSm,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              ...item.channels.map(
                (ch) => Container(
                  margin: const EdgeInsets.only(right: AppSpacing.xxs2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.micro,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(
                      alpha: AppOpacity.threeQuarter,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    ch.name,
                    style: TextStyle(
                      fontSize: AppText.xs11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Format-specific metadata bar
        if (_item != null) _buildFormatMetaBar(_item!),
        if (_auditFuture != null) _buildAuditPanel(),
        const SizedBox(height: AppSpacing.sm),
        Divider(height: AppSpacing.thin, color: theme.colorScheme.outlineVariant),
        if (_isEditing) _buildToolbar(),
        // Body content
        Expanded(
          child: _isEditing
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: TextField(
                    controller: _bodyController,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                      fontSize: AppText.medium,
                      color: theme.colorScheme.onSurface,
                      height: AppLineHeight.spacious,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('Content body...'),
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (_) => setState(() => _hasChanges = true),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Markdown(
                    data: _bodyController.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: AppText.medium,
                        color: theme.colorScheme.onSurface,
                        height: AppLineHeight.spacious,
                      ),
                      h1: TextStyle(
                        fontSize: AppText.xxxl,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      h2: TextStyle(
                        fontSize: AppText.xxl,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      h3: TextStyle(
                        fontSize: AppText.tall,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      code: TextStyle(
                        backgroundColor: palette.surface.withValues(
                          alpha: AppOpacity.prominent,
                        ),
                        color: AppTheme.colorForContentType('Article'),
                        fontSize: AppText.sm,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: palette.surface.withValues(
                          alpha: AppOpacity.threeQuarter,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                            width: AppStroke.strong,
                          ),
                        ),
                      ),
                      listBullet: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: AppOpacity.threeQuarter),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolbarButton(
              tooltip: context.tr('Bold'),
              icon: Icons.format_bold_rounded,
              onTap: () => _applyFormatting(EditorFormatting.toggleBold),
            ),
            _toolbarButton(
              tooltip: context.tr('Italic'),
              icon: Icons.format_italic_rounded,
              onTap: () => _applyFormatting(EditorFormatting.toggleItalic),
            ),
            _toolbarButton(
              tooltip: context.tr('Heading'),
              icon: Icons.title_rounded,
              onTap: () => _applyFormatting(EditorFormatting.toggleHeading),
            ),
            _toolbarButton(
              tooltip: context.tr('Bulleted list'),
              icon: Icons.format_list_bulleted_rounded,
              onTap: () =>
                  _applyFormatting(EditorFormatting.toggleBulletedList),
            ),
            _toolbarButton(
              tooltip: context.tr('Quote'),
              icon: Icons.format_quote_rounded,
              onTap: () => _applyFormatting(EditorFormatting.toggleQuote),
            ),
            _toolbarButton(
              tooltip: context.tr('Insert link'),
              icon: Icons.link_rounded,
              onTap: _showInsertLinkDialog,
            ),
            _toolbarButton(
              tooltip: context.tr('Clear formatting'),
              icon: Icons.format_clear_rounded,
              onTap: () =>
                  _applyFormatting(EditorFormatting.clearBasicFormatting),
            ),
            _toolbarButton(
              tooltip: context.tr('Delete paragraph'),
              icon: Icons.backspace_outlined,
              onTap: () =>
                  _applyFormatting(EditorFormatting.deleteCurrentParagraph),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xxs2),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: AppSizes.iconXl),
        onPressed: onTap,
      ),
    );
  }

  void _applyFormatting(
    EditorFormattingResult Function(String text, TextSelection selection)
    formatter,
  ) {
    final current = _bodyController.value;
    final result = formatter(current.text, current.selection);
    _bodyController.value = TextEditingValue(
      text: result.text,
      selection: result.selection,
      composing: TextRange.empty,
    );
    setState(() => _hasChanges = true);
  }

  Future<void> _showInsertLinkDialog() async {
    final affiliationsAsync = ref.read(affiliationsProvider);
    final List<AffiliateLink> affiliations;
    if (affiliationsAsync.hasValue) {
      affiliations = (affiliationsAsync.value ?? const [])
          .where((link) => link.status == 'active' && !link.isExpired)
          .toList();
    } else {
      affiliations = const [];
    }
    final selectedUrl = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: AppSizes.handle,
              height: AppSpacing.xxs,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadii.xxs),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('Insert link'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  if (affiliations.isNotEmpty) ...[
                    Text(
                      context.tr('Affiliate links'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ...affiliations.map((link) {
                      final display = link.slug != null && link.slug!.isNotEmpty
                          ? '/r/${link.slug}'
                          : link.url;
                      return ListTile(
                        title: Text(link.name),
                        subtitle: Text(
                          display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          Icons.link_rounded,
                          size: AppSizes.iconLarge,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onTap: () {
                          final url = link.slug != null && link.slug!.isNotEmpty
                              ? '/r/${link.slug}'
                              : link.url;
                          Navigator.of(context).pop(url);
                        },
                      );
                    }),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    context.tr('Custom URL'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('https://example.com'),
                    ),
                    keyboardType: TextInputType.url,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        Navigator.of(context).pop(value.trim());
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedUrl == null || selectedUrl.isEmpty) return;

    final labelController = TextEditingController();
    final labelAccepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Insert link')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: InputDecoration(
                hintText: context.tr('Label (optional)'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Insert')),
          ),
        ],
      ),
    );

    if (labelAccepted != true) {
      labelController.dispose();
      return;
    }

    final current = _bodyController.value;
    final result = EditorFormatting.insertLink(
      current.text,
      current.selection,
      url: selectedUrl,
      label: labelController.text.trim().isEmpty
          ? null
          : labelController.text.trim(),
    );
    _bodyController.value = TextEditingValue(
      text: result.text,
      selection: result.selection,
      composing: TextRange.empty,
    );
    setState(() => _hasChanges = true);
    labelController.dispose();
  }

  Widget _buildFormatMetaBar(ContentItem item) {
    final chips = <Widget>[];

    switch (item.type) {
      case ContentType.blogPost:
        if (item.seoKeyword != null) {
          chips.add(_editorChip(Icons.search, 'SEO: ${item.seoKeyword}'));
        }
        if (item.seoVolume != null) {
          chips.add(_editorChip(Icons.trending_up, '${item.seoVolume} vol'));
        }
      case ContentType.short:
        if (item.shortPlatform != null) {
          chips.add(_editorChip(Icons.play_arrow_rounded, item.shortPlatform!));
        }
        if (item.shortDuration != null) {
          chips.add(
            _editorChip(Icons.timer_outlined, '${item.shortDuration}s'),
          );
        }
        if (item.shortHashtags.isNotEmpty) {
          chips.add(
            _editorChip(Icons.tag, item.shortHashtags.take(3).join(' ')),
          );
        }
      case ContentType.socialPost:
        for (final p in item.socialPlatforms) {
          chips.add(_editorChip(Icons.public, p));
        }
      case ContentType.newsletter:
        // Newsletter-specific: could show subject line, CTA etc.
        break;
      case ContentType.videoScript || ContentType.reel:
        break;
    }

    if (item.narrativeThread != null) {
      chips.add(_editorChip(Icons.auto_stories, item.narrativeThread!));
    }
    if (item.angleConfidence != null) {
      chips.add(_editorChip(Icons.psychology, '${item.angleConfidence}% conf'));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        children: chips,
      ),
    );
  }

  Widget _editorChip(IconData icon, String label) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.compact,
        vertical: AppSpacing.fine,
      ),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: AppOpacity.strong76),
        borderRadius: BorderRadius.circular(AppRadii.narrow),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppSizes.iconCompact,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.fine),
          Text(
            label,
            style: TextStyle(
              fontSize: AppText.xs,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditPanel() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: FutureBuilder<ContentAuditTrail>(
        future: _auditFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _auditContainer(
              child: Row(
                children: [
                  const SizedBox(
                    width: AppSizes.icon,
                    height: AppSizes.icon,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.medium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.compact),
                  Text(
                    context.tr('Loading audit trail...'),
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return _auditContainer(
              child: Text(
                context.tr('Audit trail unavailable: {error}', {
                  'error': '${snapshot.error}',
                }),
                style: TextStyle(color: AppTheme.rejectColor),
              ),
            );
          }

          final trail =
              snapshot.data ??
              const ContentAuditTrail(transitions: [], edits: []);
          if (trail.isEmpty) {
            return _auditContainer(
              child: Text(
                context.tr('No audit events yet.'),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }

          return _auditContainer(
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0,
                ),
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  context.tr('Audit Trail'),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${trail.transitions.length} ${context.tr('transitions')} • ${trail.edits.length} ${context.tr('edits')}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                trailing: IconButton(
                  tooltip: context.tr('Copy audit trail'),
                  onPressed: () => _copyAuditTrail(trail),
                  icon: Icon(
                    Icons.copy_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                children: [
                  if (trail.transitions.isNotEmpty) ...[
                    _auditSectionTitle(context.tr('Status transitions')),
                    ...trail.transitions.take(8).map(_buildTransitionTile),
                  ],
                  if (trail.edits.isNotEmpty) ...[
                    _auditSectionTitle(context.tr('Body edits')),
                    ...trail.edits.take(8).map(_buildEditTile),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _auditContainer({required Widget child}) {
    final palette = AppTheme.paletteOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.contentInset),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: AppOpacity.strong72),
        borderRadius: BorderRadius.circular(AppRadii.badge),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: child,
    );
  }

  Widget _auditSectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxs,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: AppText.xs,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTransitionTile(ContentStatusChange event) {
    return _auditEventTile(
      icon: Icons.swap_horiz_rounded,
      accent: AppTheme.warningColor,
      title: '${event.fromStatus} → ${event.toStatus}',
      actor: event.actor,
      timestamp: event.timestamp,
      note: event.reason,
    );
  }

  Widget _buildEditTile(ContentEditEvent event) {
    return _auditEventTile(
      icon: Icons.edit_note_rounded,
      accent: AppTheme.editColor,
      title: 'v${event.previousVersion} → v${event.newVersion}',
      actor: event.actor,
      timestamp: event.createdAt,
      note: event.editNote,
    );
  }

  Widget _auditEventTile({
    required IconData icon,
    required Color accent,
    required String title,
    required AuditActor actor,
    required DateTime timestamp,
    String? note,
  }) {
    final date = DateFormat('MMM d, HH:mm').format(timestamp.toLocal());
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.compact),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: AppOpacity.strong),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSizes.iconHero,
                height: AppSizes.iconHero,
                decoration: BoxDecoration(
                  color: accent.withAlpha(AppAlpha.glow),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(icon, size: AppSizes.icon, color: accent),
              ),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: AppText.compact,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      '${actor.actorLabel} (${actor.actorType}:${actor.actorId})',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: AppText.xs11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: AppText.xs11,
                ),
              ),
            ],
          ),
          if (note != null && note.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              note.trim(),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: AppText.xs,
                height: AppLineHeight.body,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copyAuditTrail(ContentAuditTrail trail) async {
    final lines = <String>[
      'ContentGlows audit trail',
      if (_item != null) 'content_id: ${_item!.id}',
      if (_item != null) 'title: ${_item!.title}',
      'transitions: ${trail.transitions.length}',
      ...trail.transitions.map(
        (event) =>
            '- transition ${event.fromStatus} -> ${event.toStatus} | actor=${event.actor.actorType}:${event.actor.actorId} | label=${event.actor.actorLabel} | at=${event.timestamp.toIso8601String()}${event.reason == null ? '' : ' | reason=${event.reason}'}',
      ),
      'edits: ${trail.edits.length}',
      ...trail.edits.map(
        (event) =>
            '- edit v${event.previousVersion} -> v${event.newVersion} | actor=${event.actor.actorType}:${event.actor.actorId} | label=${event.actor.actorLabel} | at=${event.createdAt.toIso8601String()}${event.editNote == null ? '' : ' | note=${event.editNote}'}',
      ),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Audit trail copied')),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ContentItem item) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    final placementState = ref.watch(socialPlacementProvider(item.id));
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Reject button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _reject(item),
              icon: const Icon(Icons.close_rounded),
              label: Text(context.tr('Skip')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.rejectColor,
                side: BorderSide(
                  color: AppTheme.rejectColor.withAlpha(AppAlpha.strong100),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.contentInset,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.badge),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Publish button
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => _publish(item),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                placementState.hasBlockingIssues
                    ? context.tr('Fix publication assets')
                    : _hasChanges
                    ? context.tr('Save & Publish')
                    : context.tr('Publish'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.approveColor,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.contentInset,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.badge),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publish(ContentItem item) async {
    final placementState = ref.read(socialPlacementProvider(item.id));
    if (placementState.isBusy || placementState.needsRegistryRefresh) {
      await _refreshPlacements(item);
      if (!mounted) return;
    }
    if (ref.read(socialPlacementProvider(item.id)).hasBlockingIssues) {
      _showPlacementPanel(item);
      return;
    }
    if (_hasChanges) {
      try {
        final api = ref.read(apiServiceProvider);
        final savedOnline = await api.saveContentBody(
          item.id,
          _bodyController.text,
        );
        if (!savedOnline) {
          if (!mounted) return;
          showCopyableDiagnosticSnackBar(
            context,
            ref,
            message: context.tr(
              'Changes are queued for sync. Publishing is blocked until the full body is saved online.',
            ),
            scope: 'editor.save_body_queued',
            backgroundColor: AppTheme.warningColor.withAlpha(AppAlpha.text),
          );
          return;
        }
        await api.updateContent(item.id, title: _titleController.text);

        final updated = item.copyWith(
          title: _titleController.text,
          body: _bodyController.text,
        );
        ref.read(pendingContentProvider.notifier).updateItem(updated);
      } catch (error, stackTrace) {
        if (!mounted) return;
        showCopyableDiagnosticSnackBar(
          context,
          ref,
          message: context.tr('Could not save changes: {error}', {
            'error': '$error',
          }),
          scope: 'editor.save_changes',
          error: error,
          stackTrace: stackTrace,
          contextData: {'contentId': item.id},
          backgroundColor: AppTheme.warningColor.withAlpha(AppAlpha.text),
        );
        return;
      }
    }
    final result = await ref
        .read(pendingContentProvider.notifier)
        .approve(
          item.id,
          bodyOverride: _bodyController.text,
          titleOverride: _titleController.text,
        );
    if (!mounted) return;
    final resultColor = _colorForApproveSeverity(result.severity);
    final shouldShowCopyAction =
        result.severity == ApproveSeverity.warning ||
        result.severity == ApproveSeverity.error;
    if (shouldShowCopyAction) {
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: result.message,
        scope: 'editor.publish',
        backgroundColor: resultColor.withAlpha(AppAlpha.text),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: resultColor.withAlpha(AppAlpha.text),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      );
    }
    if (result.approved) {
      context.pop();
    }
  }

  void _reject(ContentItem item) {
    ref.read(pendingContentProvider.notifier).reject(item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Skipped: {title}', {'title': item.title})),
        backgroundColor: AppTheme.rejectColor.withAlpha(AppAlpha.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    );
    context.pop();
  }

  void _showPlatformPreview(ContentItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlatformPreviewSheet(
        contentId: item.id,
        title: _titleController.text,
        body: _bodyController.text,
        channels: item.channels,
        type: item.type,
      ),
    );
  }

  Future<void> _showPlacementPanel(ContentItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: PlacementPanelSheet(item: item),
      ),
    );
  }

  Future<void> _showProjectAssetPicker(ContentItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: ProjectAssetPicker(
            targetType: 'content',
            targetId: item.id,
            usageAction: 'select_for_content',
            placement: 'editor_body',
            onSelected: (usage) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.tr('Asset linked: {id}', {'id': usage.assetId}),
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Discard changes?')),
        content: Text(context.tr('You have unsaved edits.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Keep editing')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: Text(
              context.tr('Discard'),
              style: TextStyle(color: AppTheme.rejectColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForApproveSeverity(ApproveSeverity severity) =>
      switch (severity) {
        ApproveSeverity.success => AppTheme.approveColor,
        ApproveSeverity.info => AppTheme.infoColor,
        ApproveSeverity.warning => AppTheme.warningColor,
        ApproveSeverity.error => AppTheme.rejectColor,
      };
}
