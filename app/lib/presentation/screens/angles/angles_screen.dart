import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/openrouter_guard.dart';
import '../../../data/models/persona.dart';
import '../../../data/models/ritual.dart';
import '../../../data/services/api_service.dart';
import '../../../providers/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

class AnglesScreen extends ConsumerStatefulWidget {
  const AnglesScreen({super.key});

  @override
  ConsumerState<AnglesScreen> createState() => _AnglesScreenState();
}

class _AnglesScreenState extends ConsumerState<AnglesScreen> {
  List<AngleSuggestion>? _angles;
  bool _isLoading = false;
  bool _isGenerating = false;
  int? _selectedIndex;
  Persona? _selectedPersona;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    try {
      final personas = await ref.read(personasProvider.future);
      if (personas.isNotEmpty && mounted) {
        setState(() => _selectedPersona = personas.first);
        _loadAngles();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _angles = const []);
      }
    }
  }

  Future<void> _loadAngles() async {
    if (_selectedPersona == null) return;
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final narrative = ref.read(lastNarrativeProvider);
      final creatorProfile = ref.read(creatorProfileProvider).value;

      final angles = await api.generateAngles(
        personaData: _selectedPersona!.toJson(),
        narrativeSummary: narrative?.narrativeSummary,
        creatorVoice: narrative?.voiceDelta.isNotEmpty == true
            ? narrative!.voiceDelta
            : creatorProfile?.voice,
        creatorPositioning: narrative?.positioningDelta.isNotEmpty == true
            ? narrative!.positioningDelta
            : creatorProfile?.positioning,
        count: 3,
      );

      if (mounted) {
        setState(() {
          _angles = angles;
          _selectedIndex = null;
          _isLoading = false;
        });
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _angles = const [];
        _selectedIndex = null;
        _isLoading = false;
      });
      showDiagnosticSnackBar(
        context,
        ref,
        message: requiresOpenRouterCredential(error)
            ? context.tr(
                'OpenRouter key required. Go to Settings > OpenRouter, save + validate your key, then retry.',
              )
            : context.tr('Angle generation failed: {error}', {
                'error': '$error',
              }),
        scope: 'angles.generate',
        error: error,
        stackTrace: stackTrace,
        contextData: {'persona': _selectedPersona?.name ?? 'none'},
      );
      if (requiresOpenRouterCredential(error)) {
        context.push('/settings');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final personasAsync = ref.watch(personasProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Content Angles')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAngles,
          ),
        ],
      ),
      body: Column(
        children: [
          // Persona picker
          personasAsync.when(
            data: (personas) => _buildPersonaPicker(personas),
            loading: () => const SizedBox(height: 60),
            error: (error, stackTrace) => const SizedBox(height: 60),
          ),
          // Narrative context banner
          _buildNarrativeBanner(),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _angles == null || _angles!.isEmpty
                ? _buildEmpty()
                : _buildAnglesList(),
          ),
        ],
      ),
      bottomNavigationBar: _selectedIndex != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildPersonaPicker(List<Persona> personas) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    if (personas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton.icon(
          onPressed: () => context.push('/personas/new'),
          icon: const Icon(Icons.person_add, size: 18),
          label: Text(context.tr('Create a persona first')),
        ),
      );
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: personas.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final persona = personas[index];
          final isSelected = _selectedPersona?.id == persona.id;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedPersona = persona);
              _loadAngles();
            },
            child: Chip(
              avatar: Text(
                persona.avatar ?? '👤',
                style: const TextStyle(fontSize: 16),
              ),
              label: Text(persona.name),
              backgroundColor: isSelected
                  ? AppTheme.colorForContentType('Article').withAlpha(30)
                  : palette.elevatedSurface,
              side: BorderSide(
                color: isSelected
                    ? AppTheme.colorForContentType('Article')
                    : palette.borderSubtle,
              ),
              labelStyle: TextStyle(
                color: isSelected
                    ? AppTheme.colorForContentType('Article')
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNarrativeBanner() {
    final narrative = ref.watch(lastNarrativeProvider);
    final theme = Theme.of(context);
    if (narrative == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: GestureDetector(
          onTap: () => context.push('/ritual'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.paletteOf(context).surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.paletteOf(context).borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('Complete your weekly ritual for better angles'),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.colorForContentType('Article').withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.colorForContentType('Article').withAlpha(30),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_stories,
              size: 18,
              color: AppTheme.colorForContentType('Article'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                narrative.suggestedChapterTitle ??
                    context.tr('Narrative loaded'),
                style: TextStyle(
                  color: AppTheme.colorForContentType('Article'),
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.check_circle, size: 16, color: AppTheme.approveColor),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('No angles available'),
            style: TextStyle(
              fontSize: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedPersona == null
                ? context.tr('Select a persona above to generate angles')
                : context.tr('Try refreshing or complete your weekly ritual'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_selectedPersona == null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/personas/new'),
              icon: const Icon(Icons.person_add),
              label: Text(context.tr('Create Persona')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnglesList() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 4),
          child: Text(
            context.tr('Pick an angle to generate content'),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
        ...List.generate(_angles!.length, (i) {
          final angle = _angles![i];
          final isSelected = _selectedIndex == i;
          return _buildAngleCard(angle, i, isSelected);
        }),
      ],
    );
  }

  Widget _buildAngleCard(AngleSuggestion angle, int index, bool isSelected) {
    final typeColor = AppTheme.colorForContentType(
      _contentTypeLabel(angle.contentType),
    );
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    final confidenceColor = angle.confidence >= 80
        ? AppTheme.approveColor
        : angle.confidence >= 60
        ? AppTheme.warningColor
        : AppTheme.rejectColor;

    return GestureDetector(
      onTap: () => setState(
        () => _selectedIndex = _selectedIndex == index ? null : index,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.colorForContentType('Article').withAlpha(15)
              : palette.elevatedSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.colorForContentType('Article')
                : palette.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: type + confidence
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _contentTypeLabel(angle.contentType),
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: confidenceColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${angle.confidence}%',
                    style: TextStyle(
                      color: confidenceColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.colorForContentType('Article'),
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              angle.title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),

            // Hook
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: typeColor.withAlpha(100), width: 3),
                ),
              ),
              child: Text(
                angle.hook,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Angle strategy
            Text(
              angle.angle,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),

            // Meta: narrative thread + pain point
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (angle.narrativeThread.isNotEmpty)
                  _chip(Icons.auto_stories, angle.narrativeThread),
                if (angle.painPointAddressed.isNotEmpty)
                  _chip(Icons.psychology, angle.painPointAddressed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: FilledButton.icon(
        onPressed: _isGenerating ? null : _generateContent,
        icon: _isGenerating
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          _isGenerating
              ? context.tr('Creating...')
              : context.tr('Generate Content'),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppTheme.colorForContentType('Article'),
        ),
      ),
    );
  }

  Future<void> _generateContent() async {
    if (_selectedIndex == null) return;
    final angle = _angles![_selectedIndex!];

    setState(() => _isGenerating = true);

    final api = ref.read(apiServiceProvider);
    final creatorProfile = ref.read(creatorProfileProvider).value;

    try {
      final result = await api.dispatchPipeline(
        angle: angle,
        creatorVoice: creatorProfile?.voice,
        personaId: _selectedPersona?.id,
      );

      if (!mounted) return;
      setState(() => _isGenerating = false);

      if (result != null) {
        // Refresh feed so the new item appears
        ref.read(pendingContentProvider.notifier).refresh();

        final format = result['format'] ?? angle.contentType;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Content generation in progress: "{contentType}"', {
                'contentType': _contentTypeLabel(format),
                'title': angle.title,
              }),
            ),
            backgroundColor: AppTheme.approveColor.withAlpha(200),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        context.pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      final requiresOpenRouterKey = requiresOpenRouterCredential(error);
      final routeUnavailable =
          error is ApiException &&
          (error.statusCode == 404 || error.statusCode == 405);
      showDiagnosticSnackBar(
        context,
        ref,
        message: requiresOpenRouterKey
            ? context.tr(
                'OpenRouter key required. Go to Settings > OpenRouter, save + validate your key, then retry.',
              )
            : routeUnavailable
            ? context.tr(
                'Content generation route unavailable on this backend. Update the backend and retry.',
              )
            : context.tr('Content generation failed: {error}', {
                'error': '$error',
              }),
        scope: 'angles.dispatch_pipeline',
        error: error,
        contextData: {'title': angle.title, 'contentType': angle.contentType},
      );
      if (requiresOpenRouterKey) {
        context.push('/settings');
      }
    }
  }

  String _contentTypeLabel(String type) => switch (type) {
    'blog_post' || 'article' => 'Article',
    'social_post' => 'Social',
    'newsletter' => 'Newsletter',
    'video_script' => 'Video',
    'reel' => 'Reel',
    'short' => 'Short',
    _ => type,
  };
}
