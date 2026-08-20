import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/openrouter_guard.dart';
import '../../../data/models/ritual.dart';
import '../../../providers/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

class RitualScreen extends ConsumerStatefulWidget {
  const RitualScreen({super.key});

  @override
  ConsumerState<RitualScreen> createState() => _RitualScreenState();
}

class _RitualScreenState extends ConsumerState<RitualScreen> {
  final List<RitualEntry> _entries = EntryType.values
      .map((t) => RitualEntry(type: t))
      .toList();
  final Map<EntryType, TextEditingController> _controllers = {};

  bool _isSubmitting = false;
  NarrativeSynthesisResult? _result;

  @override
  void initState() {
    super.initState();
    for (final type in EntryType.values) {
      _controllers[type] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Ritual')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _result != null ? _buildResultView() : _buildEntryForm(),
    );
  }

  Widget _buildEntryForm() {
    final filledCount = _entries
        .where((e) => _controllers[e.type]!.text.trim().isNotEmpty)
        .length;
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xs,
            AppSpacing.xl,
            AppSpacing.xxs,
          ),
          child: Row(
            children: [
              Text(
                '${context.tr('Progress')}: $filledCount/${_entries.length}',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: AppText.compact,
                ),
              ),
              const Spacer(),
              Text(
                context.tr('Fill at least {count}', {'count': '2'}),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: AppText.compact,
                ),
              ),
            ],
          ),
        ),
        // Entries
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: _entries.length,
            itemBuilder: (context, index) => _buildEntryCard(_entries[index]),
          ),
        ),
        // Submit
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.sm + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: palette.elevatedSurface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: FilledButton(
            onPressed: filledCount >= 2 && !_isSubmitting ? _submit : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              backgroundColor: AppTheme.colorForContentType('Article'),
            ),
            child: _isSubmitting
                ? SizedBox(
                    height: AppSpacing.lg,
                    width: AppSpacing.lg,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.medium,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(context.tr('Synthesize Narrative')),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(RitualEntry entry) {
    final controller = _controllers[entry.type]!;
    final color = _colorForType(entry.type);
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: controller.text.trim().isNotEmpty
              ? color.withAlpha(AppAlpha.soft)
              : palette.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.contentInset,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Text(entry.emoji, style: const TextStyle(fontSize: AppText.xxl)),
                const SizedBox(width: AppSpacing.compact),
                Text(
                  _localizedLabel(entry.type),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: AppText.base,
                  ),
                ),
              ],
            ),
          ),
          // Input
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: TextField(
              controller: controller,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: AppText.sm,
                height: AppLineHeight.comfortable,
              ),
              decoration: InputDecoration(
                hintText: _localizedHint(entry.type),
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final result = _result!;
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        // Chapter transition badge
        if (result.chapterTransition && result.suggestedChapterTitle != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.colorForContentType('Article').withAlpha(AppAlpha.glow),
                  AppTheme.editColor.withAlpha(AppAlpha.glow),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: AppTheme.colorForContentType('Article').withAlpha(AppAlpha.soft),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_stories,
                  color: AppTheme.colorForContentType('Article'),
                  size: AppSizes.iconHero,
                ),
                const SizedBox(width: AppSpacing.contentInset),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('New Chapter Detected'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: AppText.xs,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        result.suggestedChapterTitle!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: AppText.title,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Narrative summary
        Text(
          context.tr('Narrative Summary'),
          style: TextStyle(
            fontSize: AppText.compact,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: palette.elevatedSurface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Text(
            result.narrativeSummary,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: AppText.medium,
              height: AppLineHeight.spacious,
            ),
          ),
        ),

        // Voice changes
        if (result.voiceDelta.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            context.tr('Voice Evolution'),
            style: TextStyle(
              fontSize: AppText.compact,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildDeltaCard(
            result.voiceDelta,
            Icons.record_voice_over,
            AppTheme.approveColor,
          ),
        ],

        // Positioning changes
        if (result.positioningDelta.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr('Positioning Shift'),
            style: TextStyle(
              fontSize: AppText.compact,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildDeltaCard(
            result.positioningDelta,
            Icons.my_location,
            AppTheme.editColor,
          ),
        ],

        const SizedBox(height: AppSpacing.wide),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _result = null),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.contentInset),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(context.tr('Edit Entries')),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _validateNarrative,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.contentInset),
                  backgroundColor: AppTheme.approveColor,
                ),
                child: Text(context.tr('Validate & Save')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeltaCard(
    Map<String, dynamic> delta,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(AppAlpha.faint),
        borderRadius: BorderRadius.circular(AppRadii.badge),
        border: Border.all(color: color.withAlpha(AppAlpha.tint)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: delta.entries.map((e) {
          final value = e.value is List
              ? (e.value as List).join(', ')
              : '${e.value}';
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: AppSizes.icon, color: color),
                const SizedBox(width: AppSpacing.compact),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_formatKey(e.key)}: ',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: value,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatKey(String key) => key
      .replaceAll('_', ' ')
      .replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m.group(0)!.toUpperCase());

  String _localizedLabel(EntryType type) => switch (type) {
    EntryType.reflection => context.tr('Reflection'),
    EntryType.win => context.tr('Win'),
    EntryType.struggle => context.tr('Struggle'),
    EntryType.idea => context.tr('Idea'),
    EntryType.pivot => context.tr('Pivot'),
  };

  String _localizedHint(EntryType type) => switch (type) {
    EntryType.reflection => context.tr(
      'What have you been thinking about this week regarding your work, your audience, your direction?',
    ),
    EntryType.win => context.tr(
      'What went well? A milestone, a positive reaction, a breakthrough?',
    ),
    EntryType.struggle => context.tr(
      'What was difficult? A blocker, a doubt, a frustration?',
    ),
    EntryType.idea => context.tr(
      'Any new ideas? Content topics, product features, collaborations?',
    ),
    EntryType.pivot => context.tr(
      'Are you reconsidering something? A strategy shift, a new angle?',
    ),
  };

  Color _colorForType(EntryType type) => switch (type) {
    EntryType.reflection => AppTheme.colorForContentType('Article'),
    EntryType.win => AppTheme.approveColor,
    EntryType.struggle => AppTheme.rejectColor,
    EntryType.idea => AppTheme.warningColor,
    EntryType.pivot => AppTheme.editColor,
  };

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final entries = _entries.map((e) {
      final controller = _controllers[e.type]!;
      return e.copyWith(content: controller.text);
    }).toList();

    try {
      final api = ref.read(apiServiceProvider);
      final creatorProfile = ref.read(creatorProfileProvider).value;
      final result = await api.synthesizeNarrative(
        profileId: creatorProfile?.id ?? 'default',
        entries: entries,
        currentVoice: creatorProfile?.voice,
        currentPositioning: creatorProfile?.positioning,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _result = result;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final requiresOpenRouterKey = requiresOpenRouterCredential(error);
      showDiagnosticSnackBar(
        context,
        ref,
        message: requiresOpenRouterKey
            ? context.tr(
                'OpenRouter key required. Go to Settings > OpenRouter, save + validate your key, then retry.',
              )
            : context.tr('Narrative synthesis failed: {error}', {
                'error': '$error',
              }),
        scope: 'ritual.synthesize',
        error: error,
        stackTrace: stackTrace,
      );
      if (requiresOpenRouterKey) {
        context.push('/settings');
      }
    }
  }

  void _validateNarrative() {
    ref.read(lastNarrativeProvider.notifier).state = _result;
    final result = _result;
    if (result != null && !ref.read(authSessionProvider).isDemo) {
      unawaited(
        ref
            .read(apiServiceProvider)
            .saveCreatorProfile(
              voice: result.voiceDelta.isEmpty ? null : result.voiceDelta,
              positioning: result.positioningDelta.isEmpty
                  ? null
                  : result.positioningDelta,
            ),
      );
      ref.invalidate(creatorProfileProvider);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Narrative validated and saved!')),
        backgroundColor: AppTheme.approveColor.withAlpha(AppAlpha.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      ),
    );
    context.pop();
  }
}
