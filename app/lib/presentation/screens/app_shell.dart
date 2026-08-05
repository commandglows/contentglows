import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_access_state.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_exit_confirmation.dart';

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;
}

class _NavSection {
  const _NavSection({required this.label, required this.items});
  final String label;
  final List<_NavItem> items;
}

const _sections = [
  _NavSection(
    label: 'Content',
    items: [
      _NavItem(icon: Icons.dynamic_feed_rounded, label: 'Feed', path: '/feed'),
      _NavItem(
        icon: Icons.calendar_month_rounded,
        label: 'Schedule',
        path: '/calendar',
      ),
      _NavItem(icon: Icons.history_rounded, label: 'History', path: '/history'),
      _NavItem(icon: Icons.water_drop_rounded, label: 'Drip', path: '/drip'),
      _NavItem(
        icon: Icons.build_circle_rounded,
        label: 'Tools',
        path: '/content-tools',
      ),
    ],
  ),
  _NavSection(
    label: 'Create',
    items: [
      _NavItem(
        icon: Icons.auto_stories_rounded,
        label: 'Ritual',
        path: '/ritual',
      ),
      _NavItem(
        icon: Icons.description_rounded,
        label: 'Templates',
        path: '/templates',
      ),
      _NavItem(
        icon: Icons.email_rounded,
        label: 'Newsletter',
        path: '/newsletter',
      ),
      _NavItem(
        icon: Icons.slow_motion_video_rounded,
        label: 'Reels',
        path: '/reels',
      ),
      _NavItem(
        icon: Icons.screen_share_rounded,
        label: 'Capture',
        path: '/capture',
      ),
      _NavItem(
        icon: Icons.link_rounded,
        label: 'Affiliations',
        path: '/affiliations',
      ),
    ],
  ),
  _NavSection(
    label: 'Analyze',
    items: [
      _NavItem(
        icon: Icons.analytics_rounded,
        label: 'Research',
        path: '/research',
      ),
      _NavItem(icon: Icons.hub_rounded, label: 'SEO', path: '/seo'),
      _NavItem(
        icon: Icons.insights_rounded,
        label: 'Analytics',
        path: '/analytics',
      ),
      _NavItem(
        icon: Icons.psychology_alt_rounded,
        label: 'Intelligence',
        path: '/project-intelligence',
      ),
      _NavItem(
        icon: Icons.bar_chart_rounded,
        label: 'Perf',
        path: '/performance',
      ),
    ],
  ),
  _NavSection(
    label: 'System',
    items: [
      _NavItem(
        icon: Icons.folder_copy_rounded,
        label: 'Projects',
        path: '/projects',
      ),
      _NavItem(icon: Icons.smart_toy_rounded, label: 'Runs', path: '/runs'),
      _NavItem(
        icon: Icons.timeline_rounded,
        label: 'Activity',
        path: '/activity',
      ),
      _NavItem(
        icon: Icons.workspaces_rounded,
        label: 'Domains',
        path: '/work-domains',
      ),
      _NavItem(
        icon: Icons.monitor_heart_rounded,
        label: 'Uptime',
        path: '/uptime',
      ),
      _NavItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        path: '/settings',
      ),
    ],
  ),
];

final _allItems = _sections.expand((s) => s.items).toList();

/// Breakpoint: above this width we show side rail instead of bottom nav.
const _desktopBreakpoint = 800.0;

@visibleForTesting
bool shouldConfirmShellExit({
  required bool routeIsFirst,
  required bool routerCanPop,
}) {
  return routeIsFirst && !routerCanPop;
}

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final appAccess = ref.watch(appAccessStateProvider).value;
    final degradedMode = appAccess?.isDegraded == true;
    final currentRoute = GoRouterState.of(context).uri.path;
    final shouldWatchPendingCount = !degradedMode && currentRoute == '/feed';
    final pendingCount = shouldWatchPendingCount
        ? ref.watch(pendingCountProvider)
        : 0;
    final selectedPath = _selectedPath(currentRoute);
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;
    final sections = _sections;
    final allItems = _allItems;

    if (isWide) {
      return _wrapWithExitConfirmation(
        context,
        Scaffold(
          body: Row(
            children: [
              _SideRail(
                sections: sections,
                selectedPath: selectedPath,
                pendingCount: pendingCount,
                colorScheme: colorScheme,
                onNavigate: (path) => context.go(path),
              ),
              VerticalDivider(
                width: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _ShellContent(
                  degradedMode: degradedMode,
                  appAccess: appAccess,
                  ref: ref,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _wrapWithExitConfirmation(
      context,
      Scaffold(
        body: _ShellContent(
          degradedMode: degradedMode,
          appAccess: appAccess,
          ref: ref,
          child: widget.child,
        ),
        bottomNavigationBar: _BottomNav(
          sections: sections,
          items: allItems,
          degradedMode: degradedMode,
          selectedPath: selectedPath,
          pendingCount: pendingCount,
          colorScheme: colorScheme,
          onNavigate: (path) => context.go(path),
        ),
      ),
    );
  }

  Widget _wrapWithExitConfirmation(BuildContext context, Widget child) {
    final routeIsFirst = ModalRoute.of(context)?.isFirst ?? true;
    final routerCanPop = GoRouter.of(context).canPop();
    final shouldConfirmExit = shouldConfirmShellExit(
      routeIsFirst: routeIsFirst,
      routerCanPop: routerCanPop,
    );
    return PopScope<void>(
      canPop: !shouldConfirmExit,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !shouldConfirmExit) return;
        unawaited(confirmAndExitApp(context));
      },
      child: child,
    );
  }

  String _selectedPath(String route) {
    final items = _allItems;
    for (final item in items) {
      if (route.startsWith(item.path)) return item.path;
    }
    return '/feed';
  }
}

class _ShellContent extends StatelessWidget {
  const _ShellContent({
    required this.degradedMode,
    required this.appAccess,
    required this.ref,
    required this.child,
  });

  final bool degradedMode;
  final AppAccessState? appAccess;
  final WidgetRef ref;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final offlineSync = ref.watch(offlineSyncStateProvider);
    final showSyncBanner =
        degradedMode ||
        offlineSync.hasQueuedActions ||
        offlineSync.hasStaleData ||
        offlineSync.failedCount > 0 ||
        offlineSync.isReplaying;
    final bannerColor = degradedMode
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final bannerTextColor = degradedMode
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;
    final bannerParts = <String>[
      if (degradedMode)
        switch (appAccess?.stage) {
          AppAccessStage.apiUnavailable => context.tr(
            'FastAPI is unavailable. ContentGlows is running in degraded mode until the backend responds again.',
          ),
          AppAccessStage.bootstrapFailed => context.tr(
            'Clerk is connected, but workspace bootstrap failed. ContentGlows stays in degraded mode until FastAPI returns a usable bootstrap.',
          ),
          _ => context.tr(
            'ContentGlows is running in degraded mode while backend access is limited.',
          ),
        },
      if (offlineSync.hasStaleData)
        context.tr('Some screens are using cached data and may be stale.'),
      if (offlineSync.isReplaying)
        context.tr('Queued actions are replaying in the background.'),
      if (offlineSync.pendingCount > 0)
        context.tr('{count} actions are waiting to sync.', {
          'count': '${offlineSync.pendingCount}',
        }),
      if (offlineSync.blockedDependencyCount > 0)
        context.tr('{count} queued actions are waiting for dependency sync.', {
          'count': '${offlineSync.blockedDependencyCount}',
        }),
      if (offlineSync.requiresReauth)
        context.tr('Queued actions are paused until you sign in again.'),
      if (offlineSync.failedCount > 0)
        context.tr('{count} queued actions need manual review.', {
          'count': '${offlineSync.failedCount}',
        }),
    ];

    return Column(
      children: [
        if (showSyncBanner)
          Material(
            color: bannerColor,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      offlineSync.isReplaying
                          ? Icons.sync_rounded
                          : Icons.warning_amber_rounded,
                      color: bannerTextColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        bannerParts.join(' '),
                        style: TextStyle(
                          color: bannerTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => context.go('/uptime'),
                      child: Text(
                        context.tr('Open Uptime'),
                        style: TextStyle(color: bannerTextColor),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Copy diagnostics'),
                      onPressed: () {
                        final isAccessDegraded = appAccess?.isDegraded == true;
                        final staleKeyList = offlineSync.staleKeys.toList()
                          ..sort();
                        copyDiagnosticsToClipboard(
                          context,
                          ref,
                          title: isAccessDegraded
                              ? 'ContentGlows degraded mode diagnostics'
                              : 'ContentGlows sync diagnostics',
                          scope: isAccessDegraded
                              ? 'app_shell.degraded_mode'
                              : 'app_shell.sync_warning',
                          currentError: isAccessDegraded
                              ? appAccess?.message
                              : null,
                          contextData: {
                            'accessStage':
                                appAccess?.diagnosticsLabel ?? 'unknown',
                            'backendStatus':
                                appAccess?.backendStatusLabel ?? 'unknown',
                            'queuedPending': offlineSync.pendingCount,
                            'queuedBlocked': offlineSync.blockedDependencyCount,
                            'queuedPaused': offlineSync.pausedAuthCount,
                            'queuedFailed': offlineSync.failedCount,
                            'staleKeys': offlineSync.staleKeys.length,
                            'staleKeyList': staleKeyList.isEmpty
                                ? 'none'
                                : staleKeyList.join(', '),
                          },
                          successMessage: isAccessDegraded
                              ? 'Degraded mode diagnostics copied.'
                              : 'Sync diagnostics copied.',
                        );
                      },
                      icon: Icon(Icons.copy_rounded, color: bannerTextColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

// ─── Desktop: Side Rail ──────────────────────────────────────

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.sections,
    required this.selectedPath,
    required this.pendingCount,
    required this.colorScheme,
    required this.onNavigate,
  });

  final List<_NavSection> sections;
  final String selectedPath;
  final int pendingCount;
  final ColorScheme colorScheme;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Logo area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('ContentGlows'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Sections
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                      child: Text(
                        context.tr(section.label).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.outlineVariant,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    for (final item in section.items)
                      _SideNavItem(
                        icon: item.icon,
                        label: item.label,
                        isSelected: item.path == selectedPath,
                        badgeCount: item.path == '/feed' && pendingCount > 0
                            ? pendingCount
                            : null,
                        colorScheme: colorScheme,
                        onTap: () => onNavigate(item.path),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final int? badgeCount;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final bgColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.12)
        : colorScheme.surface.withValues(alpha: 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Badge(
                  isLabelVisible: badgeCount != null,
                  label: badgeCount != null ? Text('$badgeCount') : null,
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(label),
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
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

// ─── Mobile: Bottom Nav ──────────────────────────────────────

/// Primary tabs shown in the bottom bar on mobile.
const _mobileTabPaths = ['/feed', '/calendar', '/history', '/drip'];

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.sections,
    required this.items,
    required this.degradedMode,
    required this.selectedPath,
    required this.pendingCount,
    required this.colorScheme,
    required this.onNavigate,
  });

  final List<_NavSection> sections;
  final List<_NavItem> items;
  final bool degradedMode;
  final String selectedPath;
  final int pendingCount;
  final ColorScheme colorScheme;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final primaryItems = items
        .where((i) => _mobileTabPaths.contains(i.path))
        .toList();
    final isMoreSelected = !_mobileTabPaths.contains(selectedPath);
    final showMoreTab = true;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final item in primaryItems)
              Expanded(
                child: _NavTab(
                  icon: item.icon,
                  label: item.label,
                  isSelected: item.path == selectedPath,
                  badgeCount: item.path == '/feed' && pendingCount > 0
                      ? pendingCount
                      : null,
                  colorScheme: colorScheme,
                  onTap: () => onNavigate(item.path),
                ),
              ),
            if (showMoreTab)
              Expanded(
                child: _NavTab(
                  icon: Icons.grid_view_rounded,
                  label: 'More',
                  isSelected: isMoreSelected,
                  colorScheme: colorScheme,
                  onTap: () => _showMoreSheet(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.48,
        minChildSize: 0.30,
        maxChildSize: 0.50,
        builder: (sheetContext, scrollController) => SafeArea(
          top: false,
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                12 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                for (final section in sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.tr(section.label).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.outlineVariant,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 2,
                    runSpacing: 2,
                    children: section.items.map((item) {
                      final isSelected = item.path == selectedPath;
                      final color = isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant;
                      final bgColor = isSelected
                          ? colorScheme.primary.withValues(alpha: 0.12)
                          : colorScheme.surface.withValues(alpha: 0);
                      return Material(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(ctx);
                            onNavigate(item.path);
                          },
                          child: SizedBox(
                            width: 76,
                            height: 60,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(item.icon, color: color, size: 22),
                                const SizedBox(height: 3),
                                Text(
                                  context.tr(item.label),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final int? badgeCount;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badgeCount != null,
              label: badgeCount != null ? Text('$badgeCount') : null,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(label),
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
