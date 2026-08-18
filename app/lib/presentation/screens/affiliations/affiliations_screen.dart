import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/affiliate_link.dart';
import '../../../data/models/link_webhook.dart';
import '../../../data/models/utm_template.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/offline_sync_status_chip.dart';
import '../../widgets/project_picker_action.dart';
import 'affiliation_form_sheet.dart';
import '../../../l10n/app_localizations.dart';

const _statusFilters = ['all', 'active', 'paused', 'expired'];

class AffiliationsScreen extends ConsumerStatefulWidget {
  const AffiliationsScreen({super.key});

  @override
  ConsumerState<AffiliationsScreen> createState() => _AffiliationsScreenState();
}

class _AffiliationsScreenState extends ConsumerState<AffiliationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Affiliations')),
        actions: [
          const ProjectPickerAction(),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _handleAdd(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.tr('Links')),
            Tab(text: context.tr('Webhooks')),
            Tab(text: context.tr('Conversions')),
            Tab(text: context.tr('UTM')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AffiliationsTab(),
          _WebhooksTab(),
          _ConversionsTab(),
          _UtmTemplatesTab(),
        ],
      ),
    );
  }

  void _handleAdd(BuildContext context) {
    switch (_tabController.index) {
      case 0:
        _openForm(context);
        break;
      case 1:
        _openWebhookForm(context);
        break;
      case 3:
        _openUtmForm(context);
        break;
      default:
        break;
    }
  }

  Future<void> _openForm(BuildContext context, [AffiliateLink? existing]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AffiliationFormSheet(affiliation: existing),
    );
    if (result == true && mounted) {
      ref.invalidate(affiliationsProvider);
    }
  }

  Future<void> _openWebhookForm(BuildContext context, [LinkWebhook? existing]) async {
    final l10n = context.l10n;
    final urlController = TextEditingController(text: existing?.url ?? '');
    final secretController = TextEditingController(text: existing?.secret ?? '');
    final eventsController = TextEditingController(
      text: existing?.events.join(', ') ?? 'link.clicked',
    );
    final enabled = ValueNotifier<bool>(existing?.enabled ?? true);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setState) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? l10n.tr('Add webhook') : l10n.tr('Edit webhook'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: l10n.tr('Webhook URL'),
                    hintText: 'https://example.com/webhook',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: secretController,
                  decoration: InputDecoration(
                    labelText: l10n.tr('Secret (optional)'),
                    hintText: l10n.tr('Optional signing secret'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: eventsController,
                  decoration: InputDecoration(
                    labelText: l10n.tr('Events'),
                    hintText: l10n.tr('Comma-separated event types'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(l10n.tr('Enabled')),
                    const Spacer(),
                    ValueListenableBuilder<bool>(
                      valueListenable: enabled,
                      builder: (context, value, _) => Switch(
                        value: value,
                        onChanged: (v) => setState(() => enabled.value = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.tr('Cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final api = ref.read(apiServiceProvider);
                          try {
                            if (existing == null) {
                              await api.createLinkWebhook(
                                url: urlController.text.trim(),
                                events: eventsController.text
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList(),
                                enabled: enabled.value,
                                secret: secretController.text.trim().isEmpty
                                    ? null
                                    : secretController.text.trim(),
                              );
                            } else {
                              await api.updateLinkWebhook(existing.id!, {
                                'url': urlController.text.trim(),
                                'events': eventsController.text
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList(),
                                'enabled': enabled.value,
                                'secret': secretController.text.trim().isEmpty
                                    ? null
                                    : secretController.text.trim(),
                              });
                            }
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${l10n.tr('Error')}: $e')),
                              );
                            }
                          }
                        },
                        child: Text(l10n.tr('Save')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      ref.invalidate(linkWebhooksProvider);
    }
  }

  Future<void> _openUtmForm(BuildContext context, [UtmTemplate? existing]) async {
    final l10n = context.l10n;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final sourceController = TextEditingController(text: existing?.utmSource ?? '');
    final mediumController = TextEditingController(text: existing?.utmMedium ?? '');
    final campaignController = TextEditingController(text: existing?.utmCampaign ?? '');
    final termController = TextEditingController(text: existing?.utmTerm ?? '');
    final contentController = TextEditingController(text: existing?.utmContent ?? '');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? l10n.tr('Add UTM template') : l10n.tr('Edit UTM template'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.tr('Template name')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sourceController,
                decoration: const InputDecoration(labelText: 'UTM Source'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mediumController,
                decoration: const InputDecoration(labelText: 'UTM Medium'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: campaignController,
                decoration: const InputDecoration(labelText: 'UTM Campaign'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: termController,
                decoration: const InputDecoration(labelText: 'UTM Term (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'UTM Content (optional)'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.tr('Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final api = ref.read(apiServiceProvider);
                        try {
                          if (existing == null) {
                            await api.createUtmTemplate(
                              name: nameController.text.trim(),
                              utmSource: sourceController.text.trim().isEmpty ? null : sourceController.text.trim(),
                              utmMedium: mediumController.text.trim().isEmpty ? null : mediumController.text.trim(),
                              utmCampaign: campaignController.text.trim().isEmpty ? null : campaignController.text.trim(),
                              utmTerm: termController.text.trim().isEmpty ? null : termController.text.trim(),
                              utmContent: contentController.text.trim().isEmpty ? null : contentController.text.trim(),
                            );
                          } else {
                            await api.updateUtmTemplate(existing.id!, {
                              'name': nameController.text.trim(),
                              'utmSource': sourceController.text.trim().isEmpty ? null : sourceController.text.trim(),
                              'utmMedium': mediumController.text.trim().isEmpty ? null : mediumController.text.trim(),
                              'utmCampaign': campaignController.text.trim().isEmpty ? null : campaignController.text.trim(),
                              'utmTerm': termController.text.trim().isEmpty ? null : termController.text.trim(),
                              'utmContent': contentController.text.trim().isEmpty ? null : contentController.text.trim(),
                            });
                          }
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${l10n.tr('Error')}: $e')),
                            );
                          }
                        }
                      },
                      child: Text(l10n.tr('Save')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      ref.invalidate(utmTemplatesProvider);
    }
  }
}

class _AffiliationsTab extends ConsumerStatefulWidget {
  const _AffiliationsTab();

  @override
  ConsumerState<_AffiliationsTab> createState() => _AffiliationsTabState();
}

class _AffiliationsTabState extends ConsumerState<_AffiliationsTab> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final affiliationsAsync = ref.watch(affiliationsProvider);

    return affiliationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          scope: 'affiliations.load',
          title: context.tr('Failed to load affiliations'),
          error: error,
          stackTrace: stackTrace,
          onRetry: () => ref.invalidate(affiliationsProvider),
        ),
      ),
      data: (affiliations) {
        final filtered = _statusFilter == 'all'
            ? affiliations
            : affiliations.where((a) {
                if (_statusFilter == 'expired') {
                  return a.isExpired || a.status == 'expired';
                }
                return a.status == _statusFilter;
              }).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(affiliationsProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _StatsRow(affiliations: affiliations)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    children: _statusFilters.map((filter) {
                      final isSelected = _statusFilter == filter;
                      return FilterChip(
                        label: Text(context.tr(
                          switch (filter) {
                            'all' => 'All',
                            'active' => 'Active',
                            'paused' => 'Paused',
                            'expired' => 'Expired',
                            _ => filter,
                          },
                        )),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _statusFilter = filter),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: _EmptyState(
                    hasFilter: _statusFilter != 'all',
                    onAdd: () => _openForm(context),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _AffiliationCard(
                      affiliation: filtered[index],
                      onTap: () => _openForm(context, filtered[index]),
                      onDelete: () => _delete(context, filtered[index]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openForm(BuildContext context, [AffiliateLink? existing]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AffiliationFormSheet(affiliation: existing),
    );
    if (result == true && context.mounted) {
      ref.invalidate(affiliationsProvider);
    }
  }

  Future<void> _delete(BuildContext context, AffiliateLink affiliation) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.tr('Delete affiliate link?')),
        content: Text(
          l10n.tr(
            'Remove "{name}"? This cannot be undone.',
            params: {'name': affiliation.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: errorColor),
            child: Text(l10n.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final api = ref.read(apiServiceProvider);
    try {
      await api.deleteAffiliation(affiliation.id!);
      if (!context.mounted) return;
      ref.invalidate(affiliationsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.tr('Deleted "{name}"', params: {'name': affiliation.name}),
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (!context.mounted) return;
      showDiagnosticSnackBar(
        context,
        ref,
        message: l10n.tr('Failed to delete: {error}', params: {'error': '$error'}),
        scope: 'affiliations.delete',
        error: error,
        stackTrace: stackTrace,
        contextData: {'affiliationId': affiliation.id ?? 'unknown'},
      );
    }
  }
}

class _WebhooksTab extends ConsumerWidget {
  const _WebhooksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webhooksAsync = ref.watch(linkWebhooksProvider);

    return webhooksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          scope: 'webhooks.load',
          title: context.tr('Failed to load webhooks'),
          error: error,
          stackTrace: stackTrace,
          onRetry: () => ref.invalidate(linkWebhooksProvider),
        ),
      ),
      data: (webhooks) {
        if (webhooks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.webhook_rounded, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text(context.tr('No webhooks yet'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _showAddWebhook(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Add webhook')),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(linkWebhooksProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: webhooks.length,
            itemBuilder: (context, index) {
              final webhook = webhooks[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(webhook.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${webhook.events.join(', ')} • ${webhook.enabled ? context.tr('Enabled') : context.tr('Disabled')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history_rounded, size: 20),
                        onPressed: () => _showDeliveries(context, ref, webhook),
                      ),
                      IconButton(
                        icon: Icon(webhook.enabled ? Icons.toggle_on_rounded : Icons.toggle_off_rounded, size: 20),
                        onPressed: () async {
                          final api = ref.read(apiServiceProvider);
                          await api.updateLinkWebhook(webhook.id!, {'enabled': !webhook.enabled});
                          ref.invalidate(linkWebhooksProvider);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(context.tr('Delete webhook?')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                  child: Text(context.tr('Delete')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            final api = ref.read(apiServiceProvider);
                            await api.deleteLinkWebhook(webhook.id!);
                            ref.invalidate(linkWebhooksProvider);
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () => _showAddWebhook(context, ref, webhook),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showAddWebhook(BuildContext context, WidgetRef ref, [LinkWebhook? existing]) async {
    if (context.mounted) {
      final parent = context.findAncestorStateOfType<_AffiliationsScreenState>();
      await parent?._openWebhookForm(context, existing);
    }
  }

  Future<void> _showDeliveries(BuildContext context, WidgetRef ref, LinkWebhook webhook) async {
    final deliveriesAsync = ref.watch(linkWebhookDeliveriesProvider(webhook.id!));
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Webhook deliveries')),
        content: deliveriesAsync.when(
          loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) => Text('${context.tr('Error')}: $error'),
          data: (deliveries) {
            if (deliveries.isEmpty) {
              return Text(context.tr('No deliveries yet'));
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: deliveries.length,
                itemBuilder: (context, index) {
                  final d = deliveries[index];
                  return ListTile(
                    dense: true,
                    title: Text(d.eventType),
                    subtitle: Text('${d.url} • ${d.statusCode ?? 0}'),
                    trailing: d.error != null
                        ? Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error)
                        : Icon(Icons.check_circle_outline, size: 18, color: AppTheme.approveColor),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Close'))),
        ],
      ),
    );
  }
}

class _ConversionsTab extends ConsumerWidget {
  const _ConversionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final affiliationsAsync = ref.watch(affiliationsProvider);

    return affiliationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          scope: 'conversions.load',
          title: context.tr('Failed to load conversions'),
          error: error,
          stackTrace: stackTrace,
          onRetry: () => ref.invalidate(affiliationsProvider),
        ),
      ),
      data: (affiliations) {
        final linksWithClicks = affiliations.where((a) => a.clickCount > 0).toList();

        if (linksWithClicks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.show_chart_rounded, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text(context.tr('No conversions yet'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: linksWithClicks.length,
          itemBuilder: (context, index) {
            final link = linksWithClicks[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(link.name),
                subtitle: Text('${link.clickCount} clicks'),
                trailing: TextButton(
                  onPressed: () => _showConversions(context, ref, link),
                  child: Text(context.tr('View')),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showConversions(BuildContext context, WidgetRef ref, AffiliateLink link) async {
    final conversionsAsync = ref.watch(linkConversionsProvider(link.id!));
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(link.name),
        content: conversionsAsync.when(
          loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) => Text('${context.tr('Error')}: $error'),
          data: (conversions) {
            if (conversions.isEmpty) {
              return Text(context.tr('No conversions for this link'));
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: conversions.length,
                itemBuilder: (context, index) {
                  final c = conversions[index];
                  return ListTile(
                    dense: true,
                    title: Text(c.type),
                    subtitle: Text(c.createdAt.toLocal().toString().split(' ')[0]),
                    trailing: c.revenue != null
                        ? Text('${c.revenue!.toStringAsFixed(2)} ${c.currency ?? ''}')
                        : null,
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Close'))),
        ],
      ),
    );
  }
}

class _UtmTemplatesTab extends ConsumerWidget {
  const _UtmTemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utmAsync = ref.watch(utmTemplatesProvider);

    return utmAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          scope: 'utm.load',
          title: context.tr('Failed to load UTM templates'),
          error: error,
          stackTrace: stackTrace,
          onRetry: () => ref.invalidate(utmTemplatesProvider),
        ),
      ),
      data: (templates) {
        if (templates.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text(context.tr('No UTM templates yet'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _showAddTemplate(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Add template')),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(utmTemplatesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(template.name),
                  subtitle: Text(
                    [
                      if (template.utmSource != null) 'source=${template.utmSource}',
                      if (template.utmMedium != null) 'medium=${template.utmMedium}',
                      if (template.utmCampaign != null) 'campaign=${template.utmCampaign}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showAddTemplate(context, ref, template),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(context.tr('Delete UTM template?')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                  child: Text(context.tr('Delete')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            final api = ref.read(apiServiceProvider);
                            await api.deleteUtmTemplate(template.id!);
                            ref.invalidate(utmTemplatesProvider);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showAddTemplate(BuildContext context, WidgetRef ref, [UtmTemplate? existing]) async {
    if (context.mounted) {
      final parent = context.findAncestorStateOfType<_AffiliationsScreenState>();
      await parent?._openUtmForm(context, existing);
    }
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.affiliations});
  final List<AffiliateLink> affiliations;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppTheme.paletteOf(context);
    final active = affiliations.where((a) => a.status == 'active' && !a.isExpired).length;
    final paused = affiliations.where((a) => a.status == 'paused').length;
    final expired = affiliations.where((a) => a.isExpired || a.status == 'expired').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatChip(
            label: context.tr('Total'),
            value: '${affiliations.length}',
            color: colorScheme.primary,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: context.tr('Active'),
            value: '$active',
            color: AppTheme.approveColor,
            backgroundColor: AppTheme.approveColor.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: context.tr('Paused'),
            value: '$paused',
            color: AppTheme.warningColor,
            backgroundColor: AppTheme.warningColor.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: context.tr('Expired'),
            value: '$expired',
            color: AppTheme.rejectColor,
            backgroundColor: palette.mutedSurface,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.backgroundColor,
  });
  final String label;
  final String value;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _AffiliationCard extends ConsumerWidget {
  const _AffiliationCard({
    required this.affiliation,
    required this.onTap,
    required this.onDelete,
  });

  final AffiliateLink affiliation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final syncInfo = affiliation.id == null
        ? null
        : ref.watch(
            offlineEntitySyncProvider(
              offlineEntityKey('affiliation', affiliation.id!),
            ),
          );

    final isExpired = affiliation.isExpired;
    final displayStatus = isExpired ? 'expired' : affiliation.status;
    final statusColor = switch (displayStatus) {
      'active' => AppTheme.approveColor,
      'paused' => AppTheme.warningColor,
      'expired' => AppTheme.rejectColor,
      _ => colorScheme.outline,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: isExpired ? null : onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      affiliation.name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (syncInfo != null) ...[
                    OfflineSyncStatusChip(info: syncInfo, compact: true),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      displayStatus,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ),
                ],
              ),
              if (isExpired) ...[
                const SizedBox(height: 4),
                Text(
                  'Expires: ${affiliation.expiresAt?.toLocal().toString().split(' ')[0] ?? ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.rejectColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (affiliation.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  affiliation.description!,
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (affiliation.category != null)
                    _MetaChip(icon: Icons.category_outlined, text: affiliation.category!),
                  if (affiliation.commission != null)
                    _MetaChip(icon: Icons.payments_outlined, text: affiliation.commission!),
                  if (affiliation.keywords.isNotEmpty)
                    _MetaChip(icon: Icons.label_outline, text: affiliation.keywords.take(3).join(', ')),
                  if (affiliation.slug != null && affiliation.slug!.isNotEmpty)
                    _MetaChip(icon: Icons.link, text: '/r/${affiliation.slug}'),
                  if (affiliation.clickCount > 0)
                    _MetaChip(icon: Icons.bar_chart_outlined, text: '${affiliation.clickCount} clicks'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter, required this.onAdd});
  final bool hasFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off, size: 64, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? context.tr('No affiliate links match this filter')
                : context.tr('No affiliate links yet'),
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          if (!hasFilter) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add first link')),
            ),
          ],
        ],
      ),
    );
  }
}
