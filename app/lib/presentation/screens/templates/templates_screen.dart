import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';
import '../../widgets/app_error_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/project_picker_action.dart';

final _templatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.fetchDefaultTemplates();
});

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(_templatesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Templates')),
        actions: const [ProjectPickerAction()],
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            scope: 'templates.load',
            title: context.tr('Failed to load templates'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(_templatesProvider),
          ),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined, size: AppSizes.heroIcon,
                      color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: AppSpacing.md),
                  Text(context.tr('No templates available'),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: templates.length,
            itemBuilder: (context, index) => _TemplateCard(template: templates[index]),
          );
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final Map<String, dynamic> template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = template['name'] as String? ?? context.tr('Unnamed');
    final description = template['description'] as String? ?? '';
    final contentType = template['content_type'] as String? ?? '';
    final sections = (template['sections'] as List?)?.length ?? 0;

    final typeIcon = switch (contentType) {
      'article' => Icons.article,
      'newsletter' => Icons.email,
      'video_script' => Icons.videocam,
      'short' => Icons.slow_motion_video,
      _ => Icons.description,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(typeIcon, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: AppSpacing.contentInset),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(description,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      if (contentType.isNotEmpty)
                        Chip(
                      label: Text(context.tr(contentType.replaceAll('_', ' ')),
                              style: TextStyle(fontSize: AppText.xs11)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      if (sections > 0)
                        Chip(
                      label: Text(context.tr('{count} sections', {'count': sections}),
                              style: TextStyle(fontSize: AppText.xs11)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
