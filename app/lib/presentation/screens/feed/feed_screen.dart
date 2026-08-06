import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/content_item.dart';
import '../../../data/models/offline_sync.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/project_picker_action.dart';
import '../../widgets/skeleton_loader.dart';
import 'content_card.dart';

const int _kMaxVisibleCards = 3;
const double _kActionDoneAllIconSize = 18.0;
const double _kFeedDeckBottomPadding = AppSpacing.lg;
const double _kFeedDeckOffsetY = 30.0;
const double _kFeedDeckPaddingHorizontal = AppSpacing.sm;
const double _kFeedDeckPaddingVertical = AppSpacing.xl;
const double _kFeedDeckBottomActionOffset = AppSpacing.lg;
const double _kFeedActionButtonMin = 52.0;
const double _kFeedActionButtonLarge = 64.0;
const double _kFeedActionIconSizeSmall = 26.0;
const double _kFeedActionIconSizeLarge = 32.0;
const double _kFeedOverlayIconSize = 28.0;
const double _kFeedOverlayPaddingH = 32.0;
const double _kFeedOverlayPaddingV = 16.0;
const double _kFeedOverlayLetterSpacing = 2.0;

const _kFeedActionCaptionSpacing = AppSpacing.xxs;

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  final CardSwiperController _swiperController = CardSwiperController();
  String? _swipeOverlay;
  int _activeCardIndex = 0;
  late AnimationController _overlayAnimation;

  @override
  void initState() {
    super.initState();
    _overlayAnimation = AnimationController(
      vsync: this,
      duration: AppMotion.base,
    );
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _overlayAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(pendingContentProvider);
    final canSeedBatch =
        contentAsync.value != null && contentAsync.value!.isEmpty;
    final isCompactAppBar = MediaQuery.sizeOf(context).width < 430;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Content Feed')),
        actions: [
          if (contentAsync.value != null && contentAsync.value!.length > 1)
            isCompactAppBar
                ? IconButton(
                    tooltip: context.tr('All ({count})', {
                      'count': contentAsync.value!.length,
                    }),
                    onPressed: () => _bulkApprove(contentAsync.value!),
                    icon: const Icon(Icons.done_all),
                    color: AppTheme.approveColor,
                  )
                : TextButton.icon(
                    onPressed: () => _bulkApprove(contentAsync.value!),
                    icon: const Icon(
                      Icons.done_all,
                      size: _kActionDoneAllIconSize,
                    ),
                    label: Text(
                      context.tr('All ({count})', {
                        'count': contentAsync.value!.length,
                      }),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.approveColor,
                    ),
                  ),
          const ProjectPickerAction(),
          if (canSeedBatch)
            IconButton(
              tooltip: context.tr('Generate test content'),
              icon: const Icon(Icons.playlist_add_rounded),
              onPressed: _seedTestBatch,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(pendingContentProvider.notifier).refresh(),
          ),
        ],
      ),
      body: contentAsync.when(
        loading: () => const FeedSkeletonLoader(),
        error: (err, stackTrace) => Center(
          child: AppErrorView(
            scope: 'feed.load_pending',
            title: context.tr('Could not load the review queue'),
            error: err,
            stackTrace: stackTrace,
            onRetry: () => ref.read(pendingContentProvider.notifier).refresh(),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _buildEmptyState();
          }
          return _buildSwiper(items);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const _FeedEmptyDashboard();
  }

  Widget _buildSwiper(List<ContentItem> items) {
    final activeItem = _currentItem(items);
    final canPublishCurrent =
        activeItem != null && _canPublishFromFeed(activeItem);
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: _kFeedDeckBottomPadding),
          child: CardSwiper(
            controller: _swiperController,
            cardsCount: items.length,
            numberOfCardsDisplayed: items.length.clamp(1, _kMaxVisibleCards),
            backCardOffset: const Offset(0, -_kFeedDeckOffsetY),
            padding: const EdgeInsets.symmetric(
              horizontal: _kFeedDeckPaddingHorizontal,
              vertical: _kFeedDeckPaddingVertical,
            ),
            scale: 0.95,
            isLoop: false,
            onSwipe: (prevIndex, currentIndex, direction) =>
                _onSwipe(items, prevIndex, direction),
            onSwipeDirectionChange: (horizontalDirection, verticalDirection) {
              final currentItem = _currentItem(items);
              setState(() {
                if (verticalDirection == CardSwiperDirection.top) {
                  _swipeOverlay = 'edit';
                } else if (horizontalDirection == CardSwiperDirection.right) {
                  _swipeOverlay =
                      currentItem != null && _canPublishFromFeed(currentItem)
                      ? 'approve'
                      : 'wait';
                } else if (horizontalDirection == CardSwiperDirection.left) {
                  _swipeOverlay = 'reject';
                } else {
                  _swipeOverlay = null;
                }
              });
            },
            cardBuilder:
                (context, index, percentThresholdX, percentThresholdY) {
                  if (index >= items.length) return const SizedBox.shrink();
                  return ContentCard(
                    item: items[index],
                    onTap: () => _openEditor(items[index]),
                  );
                },
          ),
        ),
        // Swipe direction overlay
        if (_swipeOverlay != null) _buildOverlay(),
        // Bottom action buttons
        Positioned(
          bottom: _kFeedDeckBottomActionOffset,
          left: 0,
          right: 0,
          child: _buildActionButtons(
            canPublishCurrent: canPublishCurrent,
            publishLabel: _publishActionLabel(activeItem),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay() {
    final (label, color, icon) = switch (_swipeOverlay) {
      'approve' => ('PUBLISH', AppTheme.approveColor, Icons.check_circle),
      'reject' => ('SKIP', AppTheme.rejectColor, Icons.cancel),
      'edit' => ('EDIT', AppTheme.editColor, Icons.edit),
      'wait' => ('WAIT', AppTheme.warningColor, Icons.hourglass_top_rounded),
      _ => (
        '',
        Theme.of(context).colorScheme.surface.withValues(alpha: 0),
        Icons.circle,
      ),
    };

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                color.withAlpha(30),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0),
              ],
              radius: 1.5,
            ),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _kFeedOverlayPaddingH,
                vertical: _kFeedOverlayPaddingV,
              ),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: color, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: _kFeedOverlayIconSize),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    context.tr(label),
                    style: TextStyle(
                      color: color,
      fontSize: AppText.xxxl,
                      fontWeight: FontWeight.bold,
                      letterSpacing: _kFeedOverlayLetterSpacing,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons({
    required bool canPublishCurrent,
    required String publishLabel,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionButton(
          key: const Key('feed-action-skip'),
          icon: Icons.close_rounded,
          color: AppTheme.rejectColor,
          label: 'Skip',
          onTap: () => _swiperController.swipe(CardSwiperDirection.left),
        ),
        _actionButton(
          key: const Key('feed-action-edit'),
          icon: Icons.edit_rounded,
          color: AppTheme.editColor,
          label: 'Edit',
          onTap: () => _swiperController.swipe(CardSwiperDirection.top),
          large: true,
        ),
        _actionButton(
          key: const Key('feed-action-publish'),
          icon: Icons.check_rounded,
          color: canPublishCurrent
              ? AppTheme.approveColor
              : AppTheme.warningColor,
          label: publishLabel,
          onTap: canPublishCurrent
              ? () => _swiperController.swipe(CardSwiperDirection.right)
              : null,
        ),
      ],
    );
  }

  Widget _actionButton({
    Key? key,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback? onTap,
    bool large = false,
  }) {
    final size = large ? _kFeedActionButtonLarge : _kFeedActionButtonMin;
    final isEnabled = onTap != null;
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withAlpha(isEnabled ? 30 : 18),
          shape: CircleBorder(
            side: BorderSide(
              color: color.withAlpha(isEnabled ? 150 : 90),
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            splashColor: color.withAlpha(60),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                color: color.withAlpha(isEnabled ? 255 : 150),
                size: large
                    ? _kFeedActionIconSizeLarge
                    : _kFeedActionIconSizeSmall,
              ),
            ),
          ),
        ),
        const SizedBox(height: _kFeedActionCaptionSpacing),
        Text(
          context.tr(label),
          style: TextStyle(
            color: color.withAlpha(isEnabled ? 180 : 130),
            fontSize: AppText.xs,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _bulkApprove(List<ContentItem> items) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Approve all?')),
        content: Text(
          context.tr('This will approve and publish {count} content item(s).', {
            'count': items.length,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.approveColor,
            ),
            child: Text(context.tr('Approve {count}', {'count': items.length})),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final notifier = ref.read(pendingContentProvider.notifier);
    var approved = 0;
    var failed = 0;

    for (final item in List.of(items)) {
      try {
        final result = await notifier.approve(item.id);
        if (result.approved) {
          approved++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }

    if (mounted) {
      final msg = failed == 0
          ? context.tr('Approved {approved} items', {'approved': approved})
          : context.tr('Approved {approved}, failed {failed}', {
              'approved': approved,
              'failed': failed,
            });
      _showSnackBar(
        msg,
        failed == 0 ? AppTheme.approveColor : AppTheme.warningColor,
        includeCopyAction: failed > 0,
        diagnosticScope: 'feed.bulk_approve',
      );
    }
  }

  bool _onSwipe(
    List<ContentItem> items,
    int prevIndex,
    CardSwiperDirection direction,
  ) {
    if (prevIndex >= items.length) return false;
    final item = items[prevIndex];

    setState(() => _swipeOverlay = null);

    switch (direction) {
      case CardSwiperDirection.right:
        if (!_canPublishFromFeed(item)) {
          _showSnackBar(
            _publishBlockedMessage(item),
            _colorForBlockedPublish(item),
            includeCopyAction: item.videoGenerationBlockers.isNotEmpty,
            diagnosticScope: 'feed.swipe_publish_blocked',
          );
          return false;
        }
        // Approve & publish
        ref.read(pendingContentProvider.notifier).approve(item.id).then((
          result,
        ) {
          if (!mounted) return;
          if (result.openVideoEditor) {
            _openEditor(item);
          }
          _showSnackBar(
            result.message,
            _colorForApproveSeverity(result.severity),
            includeCopyAction:
                result.severity == ApproveSeverity.warning ||
                result.severity == ApproveSeverity.error,
            diagnosticScope: 'feed.swipe_approve',
          );
        });
        setState(() {
          _activeCardIndex = math.min(prevIndex, math.max(items.length - 2, 0));
        });
        return true;

      case CardSwiperDirection.left:
        // Reject
        ref.read(pendingContentProvider.notifier).reject(item.id);
        _showSnackBar(
          context.tr('Skipped: {title}', {'title': item.title}),
          AppTheme.rejectColor,
        );
        setState(() {
          _activeCardIndex = math.min(prevIndex, math.max(items.length - 2, 0));
        });
        return true;

      case CardSwiperDirection.top:
        // Edit
        _openEditor(item);
        return false; // Don't remove from stack

      default:
        return false;
    }
  }

  void _openEditor(ContentItem item) {
    if (_usesVideoEditor(item)) {
      context.push('/editor/${item.id}/video');
      return;
    }
    context.push('/editor/${item.id}');
  }

  bool _usesVideoEditor(ContentItem item) => item.isVideoType;

  ContentItem? _currentItem(List<ContentItem> items) {
    if (items.isEmpty) return null;
    final index = _activeCardIndex.clamp(0, items.length - 1);
    return items[index];
  }

  bool _canPublishFromFeed(ContentItem item) {
    if (!item.isVideoType) return true;
    return item.isVideoReadyToPublish &&
        item.videoGenerationTimelineId != null &&
        item.videoGenerationVersionId != null;
  }

  String _publishActionLabel(ContentItem? item) {
    if (item == null || !item.isVideoType) {
      return context.tr('Publish');
    }
    return switch (item.videoFeedState) {
      'ready' => context.tr('Publish'),
      'rendering' => context.tr('Rendering'),
      'blocked' => context.tr('Blocked'),
      _ => context.tr('Needs review'),
    };
  }

  Color _colorForBlockedPublish(ContentItem item) {
    return switch (item.videoFeedState) {
      'rendering' => AppTheme.infoColor,
      'blocked' => AppTheme.rejectColor,
      _ => AppTheme.warningColor,
    };
  }

  String _publishBlockedMessage(ContentItem item) {
    final blockerSummary = item.videoGenerationBlockerSummary?.trim();
    final blockers = item.videoGenerationBlockers;
    return switch (item.videoFeedState) {
      'rendering' =>
        'Video render is still in progress. Publish will unlock when the final asset is ready.',
      'blocked' =>
        blockerSummary?.isNotEmpty == true
            ? 'Publish blocked: $blockerSummary'
            : 'Publish blocked: ${blockers.join(', ')}',
      _ =>
        'This video still needs review before the feed can publish it. Use Edit video to inspect the timeline.',
    };
  }

  void _showSnackBar(
    String message,
    Color color, {
    bool includeCopyAction = false,
    String diagnosticScope = 'feed.snackbar',
  }) {
    if (includeCopyAction) {
      showCopyableDiagnosticSnackBar(
        context,
        ref,
        message: message,
        scope: diagnosticScope,
        backgroundColor: color.withAlpha(200),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color.withAlpha(200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        duration: AppMotion.long,
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

  Future<void> _seedTestBatch() async {
    final count = await ref
        .read(pendingContentProvider.notifier)
        .seedTestContentBatch();
    if (!mounted) return;
    if (count <= 0) {
      _showSnackBar(
        context.tr('Select an active project first.'),
        AppTheme.warningColor,
      );
      return;
    }
    _showSnackBar(
      context.tr('{count} test content items generated', {'count': count}),
      AppTheme.approveColor,
    );
  }
}

class _FeedEmptyDashboard extends ConsumerStatefulWidget {
  const _FeedEmptyDashboard();

  @override
  ConsumerState<_FeedEmptyDashboard> createState() =>
      _FeedEmptyDashboardState();
}

class _FeedEmptyDashboardState extends ConsumerState<_FeedEmptyDashboard> {
  final Set<String> _dismissedActionIds = <String>{};
  int _deckGeneration = 0;

  @override
  Widget build(BuildContext context) {
    final dripPlansAsync = ref.watch(dripPlansProvider);
    final queueAsync = ref.watch(offlineQueueEntriesProvider);
    final historyAsync = ref.watch(contentHistoryProvider);
    final activeProjectId = ref.watch(activeProjectIdProvider);

    final dripCount = dripPlansAsync.value?.length;
    final queuedActions = queueAsync.value == null
        ? null
        : _countPendingQueueActions(queueAsync.value);
    final publishedCount = historyAsync.value?.length;
    final onboardingSetupRoute = _buildOnboardingSetupRoute(activeProjectId);
    final actions = _buildDashboardActions(
      context,
      onboardingSetupRoute: onboardingSetupRoute,
      dripCount: dripCount,
      queuedActions: queuedActions,
      publishedCount: publishedCount,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 640;
        final isNarrow = width < 420;

        return RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: isCompact
              ? _buildMobileDeck(context, constraints, actions, isNarrow)
              : _buildDesktopDashboard(context, actions),
        );
      },
    );
  }

  List<_DashboardAction> _buildDashboardActions(
    BuildContext context, {
    required String onboardingSetupRoute,
    required int? dripCount,
    required int? queuedActions,
    required int? publishedCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = <_DashboardAction>[
      _DashboardAction(
        id: 'setup',
        icon: Icons.tune_rounded,
        color: AppTheme.approveColor,
        eyebrow: context.tr('Workspace setup'),
        title: context.tr('Your content machine is ready to be configured.'),
        subtitle: context.tr(
          'Confirm the project, content types, channels, and rhythm before the first run.',
        ),
        details: [
          _DashboardActionDetail(
            icon: Icons.account_tree_outlined,
            title: context.tr('Content rules'),
            body: context.tr('Lock the formats, cadence, and review gates.'),
          ),
          _DashboardActionDetail(
            icon: Icons.hub_outlined,
            title: context.tr('Connected context'),
            body: context.tr(
              'Make sure ContentGlows knows what product to use.',
            ),
          ),
          _DashboardActionDetail(
            icon: Icons.swipe_right_alt_rounded,
            title: context.tr('Next swipe'),
            body: context.tr('After setup, drafts can arrive as review cards.'),
          ),
        ],
        footnote: context.tr(
          'Best first move when the workspace is empty or newly connected.',
        ),
        primaryLabel: context.tr('Review creation settings'),
        route: onboardingSetupRoute,
      ),
      _DashboardAction(
        id: 'create',
        icon: Icons.auto_awesome_rounded,
        color: AppTheme.warningColor,
        eyebrow: context.tr('First draft'),
        title: context.tr('Create your first content'),
        subtitle: context.tr(
          'Generate angles and turn the strongest one into a draft ready for review.',
        ),
        details: [
          _DashboardActionDetail(
            icon: Icons.lightbulb_outline,
            title: context.tr('Angle first'),
            body: context.tr('Start from a clear hook before writing.'),
          ),
          _DashboardActionDetail(
            icon: Icons.auto_fix_high_outlined,
            title: context.tr('Draft output'),
            body: context.tr('Create a piece that can enter the review queue.'),
          ),
          _DashboardActionDetail(
            icon: Icons.fact_check_outlined,
            title: context.tr('Human gate'),
            body: context.tr('Nothing publishes before you approve it.'),
          ),
        ],
        footnote: context.tr(
          'Use this when you want momentum more than configuration.',
        ),
        primaryLabel: context.tr('Create content'),
        route: '/angles',
      ),
      _DashboardAction(
        id: 'templates',
        icon: Icons.description_outlined,
        color: AppTheme.infoColor,
        eyebrow: context.tr('Content formats'),
        title: context.tr('Templates'),
        subtitle: context.tr(
          'Check the structures available for articles, newsletters, videos, and shorts.',
        ),
        details: [
          _DashboardActionDetail(
            icon: Icons.article_outlined,
            title: context.tr('Long form'),
            body: context.tr('Article and newsletter structures.'),
          ),
          _DashboardActionDetail(
            icon: Icons.play_circle_outline,
            title: context.tr('Video-ready'),
            body: context.tr('Scripts, shorts, reels, and hook formats.'),
          ),
          _DashboardActionDetail(
            icon: Icons.dashboard_customize_outlined,
            title: context.tr('Reusable patterns'),
            body: context.tr('Pick the shape before generating volume.'),
          ),
        ],
        footnote: context.tr(
          'Templates keep the output consistent when the queue grows.',
        ),
        primaryLabel: context.tr('Open templates'),
        route: '/templates',
      ),
    ];

    if (dripCount != null && dripCount > 0) {
      actions.add(
        _DashboardAction(
          id: 'drip',
          icon: Icons.water_drop_outlined,
          color: colorScheme.primary,
          eyebrow: context.tr('Scheduled content'),
          title: context.tr('Upcoming content queue'),
          subtitle: context.tr(
            'Review the planned queue before the next content items arrive.',
          ),
          details: [
            _DashboardActionDetail(
              icon: Icons.calendar_month_outlined,
              title: context.tr('Upcoming slots'),
              body: context.tr('See what is already planned.'),
            ),
            _DashboardActionDetail(
              icon: Icons.water_drop_outlined,
              title: context.tr('Drip rhythm'),
              body: context.tr('Check cadence before drafts land.'),
            ),
            _DashboardActionDetail(
              icon: Icons.route_outlined,
              title: context.tr('Queue control'),
              body: context.tr('Adjust the flow before review work piles up.'),
            ),
          ],
          footnote: context.tr(
            'Only shown when upcoming content is actually scheduled.',
          ),
          primaryLabel: context.tr('Open drip queue'),
          route: '/drip',
          metric: context.tr('{count} plan(s)', {'count': dripCount}),
        ),
      );
    }

    if (queuedActions != null && queuedActions > 0) {
      actions.add(
        _DashboardAction(
          id: 'sync',
          icon: Icons.sync_rounded,
          color: AppTheme.warningColor,
          eyebrow: context.tr('Sync queue'),
          title: context.tr('Queued actions'),
          subtitle: context.tr(
            'Inspect the local actions waiting for backend sync.',
          ),
          details: [
            _DashboardActionDetail(
              icon: Icons.cloud_sync_outlined,
              title: context.tr('Pending sync'),
              body: context.tr('Review actions that still need the backend.'),
            ),
            _DashboardActionDetail(
              icon: Icons.warning_amber_rounded,
              title: context.tr('Risk check'),
              body: context.tr('Spot blocked or repeated actions early.'),
            ),
            _DashboardActionDetail(
              icon: Icons.refresh_rounded,
              title: context.tr('Recovery path'),
              body: context.tr('Retry when the workspace is healthy again.'),
            ),
          ],
          footnote: context.tr(
            'Only shown when local work is waiting to sync.',
          ),
          primaryLabel: context.tr('Open diagnostics'),
          route: '/uptime',
          metric: context.tr('{count} waiting', {'count': queuedActions}),
        ),
      );
    }

    if (publishedCount != null && publishedCount > 0) {
      actions.add(
        _DashboardAction(
          id: 'history',
          icon: Icons.history_rounded,
          color: AppTheme.infoColor,
          eyebrow: context.tr('Published content'),
          title: context.tr('Review published history'),
          subtitle: context.tr(
            'Open the content already approved or published from this workspace.',
          ),
          details: [
            _DashboardActionDetail(
              icon: Icons.history_edu_outlined,
              title: context.tr('Published trail'),
              body: context.tr('Inspect what already left the queue.'),
            ),
            _DashboardActionDetail(
              icon: Icons.repeat_rounded,
              title: context.tr('Repurpose signal'),
              body: context.tr('Find pieces that can feed the next batch.'),
            ),
            _DashboardActionDetail(
              icon: Icons.verified_outlined,
              title: context.tr('Audit context'),
              body: context.tr('Keep a clear memory of approved output.'),
            ),
          ],
          footnote: context.tr(
            'Only shown after at least one content item exists in history.',
          ),
          primaryLabel: context.tr('Open history'),
          route: '/history',
          metric: context.tr('{count} item(s)', {'count': publishedCount}),
        ),
      );
    }

    return actions;
  }

  Widget _buildMobileDeck(
    BuildContext context,
    BoxConstraints constraints,
    List<_DashboardAction> actions,
    bool isNarrow,
  ) {
    final visibleActions = actions
        .where((action) => !_dismissedActionIds.contains(action.id))
        .toList();
    final deckHeight = math.max<double>(
      constraints.hasBoundedHeight ? constraints.maxHeight - 28 : 540,
      540.0,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 14 : 18,
        12,
        isNarrow ? 14 : 18,
        16,
      ),
      children: [
        SizedBox(
          height: deckHeight,
          child: visibleActions.isEmpty
              ? _DashboardCompleteState(
                  onRefresh: () {
                    setState(_dismissedActionIds.clear);
                    ref.invalidate(pendingContentProvider);
                    ref.invalidate(dripPlansProvider);
                    ref.invalidate(offlineQueueEntriesProvider);
                    ref.invalidate(contentHistoryProvider);
                  },
                  onCreate: () => context.push('/angles'),
                )
              : _MobileActionDeck(
                  key: ValueKey(
                    'flow-action-deck-${visibleActions.first.id}-$_deckGeneration',
                  ),
                  action: visibleActions.first,
                  nextAction: visibleActions.length > 1
                      ? visibleActions[1]
                      : null,
                  positionLabel: context.tr('{index} of {count}', {
                    'index': actions.indexOf(visibleActions.first) + 1,
                    'count': actions.length,
                  }),
                  onLater: () => _dismissAction(visibleActions.first),
                  onStart: () => _startAction(visibleActions.first),
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopDashboard(
    BuildContext context,
    List<_DashboardAction> actions,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.wide,
      ),
      children: [
        Text(
          context.tr('Swipe to Publish'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'One clear action at a time. Empty workspace metrics stay hidden until there is something useful to inspect.',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              _DesktopDashboardActionCard(
                action: action,
                onTap: () => _startAction(action),
              ),
          ],
        ),
      ],
    );
  }

  void _dismissAction(_DashboardAction action) {
    setState(() {
      _dismissedActionIds.add(action.id);
      _deckGeneration++;
    });
  }

  void _startAction(_DashboardAction action) {
    if (!mounted) return;
    context.push(action.route);
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _dismissedActionIds.clear();
      _deckGeneration++;
    });
    await ref.read(pendingContentProvider.notifier).refresh();
    ref.invalidate(dripPlansProvider);
    ref.invalidate(offlineQueueEntriesProvider);
    ref.invalidate(contentHistoryProvider);
  }

  int _countPendingQueueActions(List<QueuedOfflineAction>? entries) {
    if (entries == null) {
      return 0;
    }
    return entries.where((entry) => !entry.isTerminal).length;
  }

  String _buildOnboardingSetupRoute(String? activeProjectId) {
    final queryParameters = <String, String>{'intent': 'entry'};
    if (activeProjectId != null && activeProjectId.trim().isNotEmpty) {
      queryParameters['mode'] = 'edit';
      queryParameters['projectId'] = activeProjectId;
    } else {
      queryParameters['mode'] = 'create';
    }
    return Uri(
      path: '/onboarding',
      queryParameters: queryParameters,
    ).toString();
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.id,
    required this.icon,
    required this.color,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.details = const <_DashboardActionDetail>[],
    this.footnote,
    required this.primaryLabel,
    required this.route,
    this.metric,
  });

  final String id;
  final IconData icon;
  final Color color;
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<_DashboardActionDetail> details;
  final String? footnote;
  final String primaryLabel;
  final String route;
  final String? metric;
}

class _DashboardActionDetail {
  const _DashboardActionDetail({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _MobileActionDeck extends StatefulWidget {
  const _MobileActionDeck({
    super.key,
    required this.action,
    required this.positionLabel,
    required this.onLater,
    required this.onStart,
    this.nextAction,
  });

  final _DashboardAction action;
  final _DashboardAction? nextAction;
  final String positionLabel;
  final VoidCallback onLater;
  final VoidCallback onStart;

  @override
  State<_MobileActionDeck> createState() => _MobileActionDeckState();
}

class _MobileActionDeckState extends State<_MobileActionDeck> {
  static const double _commitDistance = 96;
  static const double _commitVelocity = 420;
  static const Duration _settleDuration = AppMotion.settle;

  double _dragX = 0;
  bool _isDragging = false;
  bool _isCommitting = false;

  @override
  void didUpdateWidget(covariant _MobileActionDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action.id != widget.action.id) {
      _dragX = 0;
      _isDragging = false;
      _isCommitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final progress = (_dragX.abs() / math.max(width * 0.42, 1)).clamp(0.0, 1.0);
    final rotation = (_dragX / math.max(width, 1) * 0.16).clamp(-0.16, 0.16);

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.nextAction != null)
                Positioned.fill(
                  top: 18,
                  left: 12,
                  right: 12,
                  child: AnimatedScale(
                    duration: _settleDuration,
                    curve: Curves.easeOutCubic,
                    scale: 0.96 + (progress * 0.03),
                    child: _DashboardActionCard(
                      action: widget.nextAction!,
                      positionLabel: '',
                      isPreview: true,
                    ),
                  ),
                ),
              Positioned.fill(
                child: GestureDetector(
                  key: Key('flow-action-card-${widget.action.id}'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    if (_isCommitting) return;
                    setState(() => _isDragging = true);
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_isCommitting) return;
                    setState(() => _dragX += details.delta.dx);
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isCommitting) return;
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > _commitVelocity ||
                        _dragX > _commitDistance) {
                      _commitSwipe(SwipeDirection.right, width);
                    } else if (velocity < -_commitVelocity ||
                        _dragX < -_commitDistance) {
                      _commitSwipe(SwipeDirection.left, width);
                    } else {
                      setState(() {
                        _dragX = 0;
                        _isDragging = false;
                      });
                    }
                  },
                  onHorizontalDragCancel: _resetDrag,
                  child: AnimatedContainer(
                    duration: _isDragging ? Duration.zero : _settleDuration,
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.identity()
                      ..translateByDouble(_dragX, 0, 0, 1)
                      ..rotateZ(rotation),
                    transformAlignment: Alignment.center,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _DashboardActionCard(
                            action: widget.action,
                            positionLabel: widget.positionLabel,
                          ),
                        ),
                        if (_dragX > 8)
                          Positioned(
                            top: 22,
                            right: 22,
                            child: _SwipeCue(
                              label: context.tr('START'),
                              icon: Icons.arrow_forward_rounded,
                              color: AppTheme.approveColor,
                              opacity: progress,
                            ),
                          ),
                        if (_dragX < -8)
                          Positioned(
                            top: 22,
                            left: 22,
                            child: _SwipeCue(
                              label: context.tr('LATER'),
                              icon: Icons.close_rounded,
                              color: AppTheme.rejectColor,
                              opacity: progress,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _MobileDeckControls(
          action: widget.action,
          onLater: widget.onLater,
          onStart: widget.onStart,
        ),
      ],
    );
  }

  void _resetDrag() {
    if (_isCommitting) return;
    _resetSwipeState();
  }

  void _resetSwipeState() {
    setState(() {
      _dragX = 0;
      _isDragging = false;
      _isCommitting = false;
    });
  }

  void _commitSwipe(SwipeDirection direction, double width) {
    setState(() {
      _isDragging = false;
      _isCommitting = true;
      _dragX = direction == SwipeDirection.right ? width * 1.25 : -width * 1.25;
    });

    Future<void>.delayed(_settleDuration, () {
      if (!mounted) return;
      if (direction == SwipeDirection.right) {
        widget.onStart();
      } else {
        widget.onLater();
      }
    });
  }
}

enum SwipeDirection { left, right }

class _SwipeCue extends StatelessWidget {
  const _SwipeCue({
    required this.label,
    required this.icon,
    required this.color,
    required this.opacity,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: AppText.xs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.action,
    required this.positionLabel,
    this.isPreview = false,
  });

  final _DashboardAction action;
  final String positionLabel;
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: isPreview ? 0.42 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.dense),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isPreview
                ? colorScheme.outlineVariant.withValues(alpha: 0.55)
                : action.color.withValues(alpha: 0.45),
            width: isPreview ? 1 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: isPreview ? 18 : 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Icon(action.icon, color: action.color, size: 28),
                ),
                const Spacer(),
                if (action.metric != null)
                  _InlineCountBadge(label: action.metric!)
                else if (positionLabel.isNotEmpty)
                  _InlineCountBadge(label: positionLabel),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.eyebrow,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: action.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      action.subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (action.details.isNotEmpty)
                      _DashboardDetailsPanel(action: action),
                    if (action.footnote != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        action.footnote!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppText.sm),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      action.primaryLabel,
                      style: TextStyle(
                        color: action.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: action.color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDeckControls extends StatelessWidget {
  const _MobileDeckControls({
    required this.action,
    required this.onLater,
    required this.onStart,
  });

  final _DashboardAction action;
  final VoidCallback onLater;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: Key('flow-action-later-${action.id}'),
            onPressed: onLater,
            icon: const Icon(Icons.close_rounded),
            label: Text(context.tr('Later')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            key: Key('flow-action-start-${action.id}'),
            onPressed: onStart,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(context.tr('Start')),
          ),
        ),
      ],
    );
  }
}

class _DashboardDetailsPanel extends StatelessWidget {
  const _DashboardDetailsPanel({required this.action});

  final _DashboardAction action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < action.details.length; index++) ...[
            _DashboardDetailRow(
              detail: action.details[index],
              color: action.color,
            ),
            if (index != action.details.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DashboardDetailRow extends StatelessWidget {
  const _DashboardDetailRow({required this.detail, required this.color});

  final _DashboardActionDetail detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(detail.icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail.body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.28,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopDashboardActionCard extends StatelessWidget {
  const _DesktopDashboardActionCard({
    required this.action,
    required this.onTap,
  });

  final _DashboardAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: action.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Icon(action.icon, color: action.color),
                    ),
                    const Spacer(),
                    if (action.metric != null)
                      _InlineCountBadge(label: action.metric!),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  action.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  action.subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (action.details.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.md),
                  _DashboardDetailsPanel(action: action),
                ],
                SizedBox(height: AppSpacing.md),
                Text(
                  action.primaryLabel,
                  style: TextStyle(
                    color: action.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardCompleteState extends StatelessWidget {
  const _DashboardCompleteState({
    required this.onRefresh,
    required this.onCreate,
  });

  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.mid),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.approveColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: AppTheme.approveColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('All caught up'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('No dashboard action is waiting in this session.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.45),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('Refresh')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(context.tr('Create content')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineCountBadge extends StatelessWidget {
  const _InlineCountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.compact,
        vertical: AppSpacing.compactStack,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: AppText.xs,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
