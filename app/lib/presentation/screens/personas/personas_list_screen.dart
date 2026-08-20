import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/offline_sync_status_chip.dart';

class PersonasListScreen extends ConsumerWidget {
  const PersonasListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personasAsync = ref.watch(personasProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppTheme.paletteOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Personas'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/personas/new'),
        child: const Icon(Icons.add),
      ),
      body: personasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            scope: 'personas.load',
            title: context.tr('Failed to load personas'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(personasProvider),
          ),
        ),
        data: (personas) {
          if (personas.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline,
                      size: AppSizes.heroIcon,
                      color: colorScheme.outlineVariant),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.tr('No personas yet'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.tr(
                      'Create a customer persona to help\nthe AI generate targeted content',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: () => context.push('/personas/new'),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr('Create Persona')),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: personas.length,
            itemBuilder: (context, index) {
              final p = personas[index];
              final syncInfo = ref.watch(
                offlineEntitySyncProvider(offlineEntityKey('persona', p.id ?? '')),
              );
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.xs,
                      ),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: AppOpacity.selection,
                    ),
                    child: Text(
                      p.avatar ?? p.name.substring(0, 1).toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Text(p.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                  subtitle: Text(
                    p.demographics?.role ?? context.tr('No role defined'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _confidenceBadge(p.confidence),
                      if (syncInfo != null) ...[
                        const SizedBox(height: AppSpacing.xxs2),
                        OfflineSyncStatusChip(info: syncInfo, compact: true),
                      ],
                    ],
                  ),
                  onTap: () => context.push('/personas/${p.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _confidenceBadge(int confidence) {
    final color = confidence >= 70
        ? AppTheme.approveColor
        : confidence >= 40
            ? AppTheme.warningColor
            : AppTheme.rejectColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.compact,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(AppAlpha.subtle),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        '$confidence%',
        style:
            TextStyle(
              color: color,
              fontSize: AppText.compact,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
