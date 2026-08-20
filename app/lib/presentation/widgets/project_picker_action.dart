import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_settings.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../theme/app_theme.dart';
import 'app_error_view.dart';

class ProjectPickerAction extends ConsumerWidget {
  const ProjectPickerAction({super.key});

  static const _commandNoSelection = '__no_selection__';
  static const _commandCreateProject = '__create_project__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(projectsStateProvider);
    final activeProject = ref.watch(activeProjectProvider);
    final settings = ref.watch(currentUserSettingsProvider).value;
    final isNoSelectionMode =
        normalizeProjectSelectionMode(settings?.projectSelectionMode) ==
        projectSelectionModeNone;
    final isSwitching = ref.watch(activeProjectControllerProvider).isLoading;
    final activeLabel =
        activeProject?.name ?? context.tr('No project selected');
    final activeColor = Theme.of(context).colorScheme.onSurface;

    if (isSwitching) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: SizedBox(
          width: AppSizes.iconLarge,
          height: AppSizes.iconLarge,
          child: CircularProgressIndicator(strokeWidth: AppStroke.medium),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: context.tr('Switch project'),
      onSelected: (selection) async {
        if (selection == _commandCreateProject) {
          context.push('/onboarding?mode=create&intent=project-manage');
          return;
        }

        final projectId = selection == _commandNoSelection ? null : selection;
        if (selection != _commandNoSelection &&
            projectId == activeProject?.id) {
          return;
        }
        try {
          await ref
              .read(activeProjectControllerProvider.notifier)
              .setActiveProject(projectId);
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          showCopyableDiagnosticSnackBar(
            context,
            ref,
            message: context.tr('Could not switch project: {error}', {
              'error': '$error',
            }),
            scope: 'project_picker.switch',
            error: error,
          );
        }
      },
      itemBuilder: (context) => projectsState.when(
        data: (state) {
          final availableProjects = state.items
              .where((project) => !project.isArchived && !project.isDeleted)
              .toList();

          return [
            PopupMenuItem<String>(
              value: _commandCreateProject,
              child: ListTile(
                leading: const Icon(Icons.add_rounded),
                title: Text(context.tr('Create project')),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: _commandNoSelection,
              child: ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text(context.tr('No project selected')),
                trailing: isNoSelectionMode
                    ? const Icon(
                        Icons.check_rounded,
                        size: AppSizes.iconLarge,
                      )
                    : null,
              ),
            ),
            if (availableProjects.isNotEmpty) const PopupMenuDivider(),
            for (final project in availableProjects)
              PopupMenuItem<String>(
                value: project.id,
                child: ListTile(
                  leading: const Icon(Icons.folder_copy_rounded),
                  title: Text(project.name),
                  subtitle: project.url.trim().isEmpty
                      ? Text(context.tr('No source linked'))
                      : Text(
                          project.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: activeProject?.id == project.id
                      ? const Icon(
                          Icons.check_rounded,
                          size: AppSizes.iconLarge,
                        )
                      : null,
                ),
              ),
          ];
        },
        loading: () => [
          PopupMenuItem<String>(
            enabled: false,
            child: Text(context.tr('Loading projects...')),
          ),
        ],
        error: (_, _) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Text(context.tr('Project management unavailable')),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_copy_rounded),
            const SizedBox(width: AppSpacing.xxs2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                activeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppText.compact,
                  color: activeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: AppSizes.iconLarge,
            ),
          ],
        ),
      ),
    );
  }
}
