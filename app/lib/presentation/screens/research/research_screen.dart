import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/openrouter_guard.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/project_picker_action.dart';

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  final _targetUrlCtrl = TextEditingController();
  final _competitorsCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  bool _analyzing = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _targetUrlCtrl.dispose();
    _competitorsCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Research')),
        actions: const [ProjectPickerAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            context.tr('Competitor Analysis'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.tr('Analyze your site against competitors'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _targetUrlCtrl,
            decoration: InputDecoration(
              labelText: context.tr('Your site URL'),
              hintText: context.tr('https://yoursite.com'),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.sm),

          TextField(
            controller: _competitorsCtrl,
            decoration: InputDecoration(
              labelText: context.tr('Competitor URLs (one per line)'),
              hintText: context.tr(
                'https://competitor1.com\nhttps://competitor2.com',
              ),
            ),
            maxLines: 3,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.sm),

          TextField(
            controller: _keywordsCtrl,
            decoration: InputDecoration(
              labelText: context.tr('Keywords (comma-separated)'),
              hintText: context.tr('saas, flutter, ai'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          FilledButton.icon(
            onPressed: _analyzing ? null : _analyze,
            icon: _analyzing
                ? const SizedBox(
                    height: AppSizes.iconLarge,
                    width: AppSizes.iconLarge,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.medium,
                    ),
                  )
                : const Icon(Icons.analytics),
            label: Text(
              _analyzing ? context.tr('Analyzing...') : context.tr('Analyze'),
            ),
          ),

          if (_result != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Analysis Results'),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ..._buildResults(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildResults() {
    if (_result == null) return [];
    final competitors = _result!['competitors'] as List? ?? [];
    return [
      for (final comp in competitors) ...[
        Text(
          (comp as Map)['name']?.toString() ?? context.tr('Unknown'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: AppText.compact,
          ),
        ),
        if (comp['strengths'] case final List strengths
            when strengths.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.sm,
              top: AppSpacing.xxs,
            ),
            child: Text(
              context.tr('Strengths: {list}', {'list': strengths.join(', ')}),
              style: TextStyle(fontSize: AppText.xs),
            ),
          ),
        if (comp['weaknesses'] case final List weaknesses
            when weaknesses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.sm,
              top: AppSpacing.xxsHalf,
            ),
            child: Text(
              context.tr('Weaknesses: {list}', {'list': weaknesses.join(', ')}),
              style: TextStyle(fontSize: AppText.xs),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
      ],
      if (competitors.isEmpty)
        Text(
          context.tr('No competitor data returned.'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
    ];
  }

  Future<void> _analyze() async {
    if (_targetUrlCtrl.text.trim().isEmpty ||
        _competitorsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Site URL and at least one competitor are required'),
          ),
        ),
      );
      return;
    }

    final keywords = _keywordsCtrl.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    if (keywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Add at least one keyword before running research.'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _analyzing = true;
      _result = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.runCompetitorAnalysis(
        targetUrl: _targetUrlCtrl.text.trim(),
        competitors: _competitorsCtrl.text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList(),
        keywords: keywords,
      );
      setState(() => _result = result);
    } catch (error, stackTrace) {
      if (mounted) {
        final requiresOpenRouterKey = requiresOpenRouterCredential(error);
        showDiagnosticSnackBar(
          context,
          ref,
          message: requiresOpenRouterKey
              ? context.tr(
                  'OpenRouter key required. Go to Settings > OpenRouter, save + validate your key, then retry.',
                )
              : context.tr('Analysis failed: {error}', {'error': '$error'}),
          scope: 'research.competitor_analysis',
          error: error,
          stackTrace: stackTrace,
          contextData: {
            'targetUrl': _targetUrlCtrl.text.trim(),
            'competitors': _competitorsCtrl.text.trim(),
          },
        );
        if (requiresOpenRouterKey) {
          context.push('/settings');
        }
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }
}
