import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/in_app_tour/in_app_tour_controller.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class InAppTourOverlay extends ConsumerStatefulWidget {
  const InAppTourOverlay({super.key});

  @override
  ConsumerState<InAppTourOverlay> createState() => _InAppTourOverlayState();
}

class _InAppTourOverlayState extends ConsumerState<InAppTourOverlay> {
  Offset _position = Offset.zero;
  bool _positioned = false;

  void _initializePosition(
    BuildContext context,
    Size screenSize,
    Offset cardSize,
  ) {
    if (_positioned && _position != Offset.zero) return;
    final constrainedWidth = (screenSize.width - AppSpacing.md).clamp(
      0.0,
      420.0,
    );
    final estimatedCardWidth = constrainedWidth.isFinite ? constrainedWidth : 420.0;
    final estimatedCardHeight = 220.0;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    const bottomBarClearance = 100.0;
    _position = Offset(
      (screenSize.width - estimatedCardWidth) / 2,
      screenSize.height - estimatedCardHeight - safeBottom - bottomBarClearance,
    );
    _position = Offset(
      _position.dx.clamp(
        AppSpacing.xs,
        (screenSize.width - AppSpacing.xs).clamp(
          AppSpacing.xs,
          double.infinity,
        ),
      ),
      _position.dy.clamp(
        AppSpacing.xs,
        (screenSize.height - AppSpacing.xs - cardSize.dy).clamp(
          AppSpacing.xs,
          double.infinity,
        ),
      ),
    );
    _positioned = true;
  }

  @override
  Widget build(BuildContext context) {
    final tour = ref.watch(inAppTourProvider);
    if (!tour.active) return const SizedBox.shrink();

    final step = tour.currentStep;
    final controller = ref.read(inAppTourProvider.notifier);
    final palette = AppTheme.paletteOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final media = MediaQuery.sizeOf(context);

    final stepCardKey = GlobalKey();
    final stepCard = Material(
      key: stepCardKey,
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: palette.elevatedSurface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppTheme.approveColor.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, AppSpacing.xs),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, tour, controller),
            SizedBox(height: AppSpacing.xs),
            _buildProgressBar(context, tour),
            SizedBox(height: AppSpacing.sm),
            Text(
              context.tr(step.title),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: AppText.tall,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              context.tr(step.description),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: AppText.sm,
                height: 1.45,
              ),
            ),
            if (step.hint != null) ...[
              SizedBox(height: AppSpacing.xs),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.approveColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: AppTheme.approveColor.withAlpha(60),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: AppTheme.approveColor,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        context.tr(step.hint!),
                        style: TextStyle(
                          color: AppTheme.approveColor,
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: AppSpacing.md),
            _buildActions(context, tour, controller),
          ],
        ),
      ),
    );

    _initializePosition(context, media, const Offset(420, 250));

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final cardWidth = (screenWidth - AppSpacing.lg).clamp(0.0, 420.0);
        final cardHeightEstimate = 250.0;
        _position = Offset(
          _position.dx.clamp(
            AppSpacing.sm,
            (screenWidth - cardWidth - AppSpacing.sm).clamp(
              AppSpacing.sm,
              double.infinity,
            ),
          ),
          _position.dy.clamp(
            AppSpacing.sm,
            (screenHeight - cardHeightEstimate - AppSpacing.sm).clamp(
              AppSpacing.sm,
              double.infinity,
            ),
          ),
        );

        return Stack(
          children: [
            Positioned(
              left: _position.dx,
              top: _position.dy,
              width: cardWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    _position += details.delta;
                    _position = Offset(
                      _position.dx.clamp(
                        AppSpacing.sm,
                        (screenWidth - cardWidth - AppSpacing.sm).clamp(
                          AppSpacing.sm,
                          double.infinity,
                        ),
                      ),
                      _position.dy.clamp(
                        AppSpacing.sm,
                        (screenHeight - cardHeightEstimate - AppSpacing.sm).clamp(
                          AppSpacing.sm,
                          double.infinity,
                        ),
                      ),
                    );
                  });
                },
                child: SafeArea(
                  top: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      0,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: stepCard,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant InAppTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tour = ref.read(inAppTourProvider);
    if (!tour.active) {
      _positioned = false;
      _position = Offset.zero;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tour = ref.watch(inAppTourProvider);
    if (!tour.active) {
      _positioned = false;
      _position = Offset.zero;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildHeader(
    BuildContext context,
    InAppTourState tour,
    InAppTourController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr(
              'Guided tour · {current}/{total}',
              {
                'current': tour.stepIndex + 1,
                'total': tour.totalSteps,
              },
            ),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: AppText.xs,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Icon(Icons.tour_rounded, size: 18, color: AppTheme.approveColor),
        SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: context.tr('Pause tour'),
          onPressed: controller.pause,
          icon: Icon(
            Icons.close_rounded,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, InAppTourState tour) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(tour.totalSteps, (i) {
        final isActive = i <= tour.stepIndex;
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.thin),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.approveColor
                  : colorScheme.outlineVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadii.xxs),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActions(
    BuildContext context,
    InAppTourState tour,
    InAppTourController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentRoute = GoRouterState.of(context).uri.path;
    final route = tour.currentStep.routePath;
    final hasNavigationShortcut = route != null && route != currentRoute;
    return Row(
      children: [
        if (!tour.isFirst)
          TextButton.icon(
            onPressed: () => controller.previous(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(context.tr('Previous')),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.compact),
            ),
          ),
        TextButton(
          onPressed: controller.skip,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.compact),
          ),
          child: Text(context.tr('Skip tour')),
        ),
        if (hasNavigationShortcut) ...[
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => context.go(route),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.approveColor,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.compact),
            ),
            child: Text(
              context.tr(
                'Open {screen}',
                {'screen': context.tr(tour.currentStep.title)},
              ),
            ),
          ),
        ],
        const Spacer(),
        FilledButton.icon(
          onPressed: () => controller.next(context),
          icon: Icon(
            tour.isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
            size: 16,
          ),
          label: Text(context.tr(tour.isLast ? 'Finish' : 'Next')),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.approveColor,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.dense,
              vertical: AppSpacing.compact,
            ),
          ),
        ),
      ],
    );
  }
}
