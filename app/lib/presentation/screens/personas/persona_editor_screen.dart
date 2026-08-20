import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/openrouter_guard.dart';
import '../../../data/models/persona.dart';
import '../../../data/services/api_service.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';
import '../../../l10n/app_localizations.dart';

class PersonaEditorScreen extends ConsumerStatefulWidget {
  final String? personaId;

  const PersonaEditorScreen({super.key, this.personaId});

  @override
  ConsumerState<PersonaEditorScreen> createState() =>
      _PersonaEditorScreenState();
}

class _PersonaEditorScreenState extends ConsumerState<PersonaEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _industryController;
  late TextEditingController _ageRangeController;
  late TextEditingController _experienceController;
  final List<TextEditingController> _painPointControllers = [];
  final List<TextEditingController> _goalControllers = [];
  final List<TextEditingController> _vocabularyControllers = [];
  final List<TextEditingController> _objectionControllers = [];
  bool _isSaving = false;
  bool _isAutofilling = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _roleController = TextEditingController();
    _industryController = TextEditingController();
    _ageRangeController = TextEditingController();
    _experienceController = TextEditingController();
    // Start with 2 empty pain points and goals
    _painPointControllers.addAll([
      TextEditingController(),
      TextEditingController(),
    ]);
    _goalControllers.addAll([TextEditingController(), TextEditingController()]);
    _vocabularyControllers.addAll([
      TextEditingController(),
      TextEditingController(),
    ]);
    _objectionControllers.addAll([
      TextEditingController(),
      TextEditingController(),
    ]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _industryController.dispose();
    _ageRangeController.dispose();
    _experienceController.dispose();
    for (final c in _painPointControllers) {
      c.dispose();
    }
    for (final c in _goalControllers) {
      c.dispose();
    }
    for (final c in _vocabularyControllers) {
      c.dispose();
    }
    for (final c in _objectionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.personaId != null
              ? context.tr('Edit Persona')
              : context.tr('New Persona'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('Prefill with AI'),
            onPressed: (_isSaving || _isAutofilling) ? null : _prefillWithAi,
            icon: _isAutofilling
                ? const SizedBox(
                    width: AppSizes.icon,
                    height: AppSizes.icon,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.medium,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded),
          ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: AppSizes.icon,
                    height: AppSizes.icon,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.medium,
                    ),
                  )
                : Text(context.tr('Save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Name
          _sectionLabel(context.tr('Identity')),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.tr('Persona name'),
              hintText: context.tr('e.g. Tech-Savvy Solopreneur'),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),

          const SizedBox(height: AppSpacing.section),

          // Demographics
          _sectionLabel(context.tr('Demographics')),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _roleController,
            decoration: InputDecoration(
              labelText: context.tr('Role'),
              hintText: context.tr(
                'e.g. Indie developer, CTO, Content creator',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _industryController,
                  decoration: InputDecoration(
                    labelText: context.tr('Industry'),
                    hintText: context.tr('SaaS, E-commerce...'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _ageRangeController,
                  decoration: InputDecoration(
                    labelText: context.tr('Age range'),
                    hintText: context.tr('25-40'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _experienceController,
            decoration: InputDecoration(
              labelText: context.tr('Experience level'),
              hintText: context.tr('3-8 years'),
            ),
          ),

          const SizedBox(height: AppSpacing.section),

          // Pain Points
          _sectionLabel(context.tr('Pain Points (min. 2)')),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.tr('Deep, real problems — not surface-level symptoms'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._buildListFields(
            controllers: _painPointControllers,
            hintPrefix: context.tr('Pain point'),
            color: AppTheme.rejectColor,
            onAdd: () => setState(
              () => _painPointControllers.add(TextEditingController()),
            ),
          ),

          const SizedBox(height: AppSpacing.section),

          // Goals
          _sectionLabel(context.tr('Goals (min. 2)')),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.tr('Aspirations and desired outcomes'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._buildListFields(
            controllers: _goalControllers,
            hintPrefix: context.tr('Goal'),
            color: AppTheme.approveColor,
            onAdd: () =>
                setState(() => _goalControllers.add(TextEditingController())),
          ),

          const SizedBox(height: AppSpacing.section),

          // Language — Vocabulary
          _sectionLabel(context.tr('Vocabulary')),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.tr('Words and expressions this persona actually uses'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._buildListFields(
            controllers: _vocabularyControllers,
            hintPrefix: context.tr('Word or phrase'),
            color: AppTheme.editColor,
            onAdd: () => setState(
              () => _vocabularyControllers.add(TextEditingController()),
            ),
          ),

          const SizedBox(height: AppSpacing.section),

          // Language — Objections
          _sectionLabel(context.tr('Objections')),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.tr('Common pushbacks or doubts this persona has'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._buildListFields(
            controllers: _objectionControllers,
            hintPrefix: context.tr('Objection'),
            color: AppTheme.warningColor,
            onAdd: () => setState(
              () => _objectionControllers.add(TextEditingController()),
            ),
          ),

          const SizedBox(height: AppSpacing.hero),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }

  List<Widget> _buildListFields({
    required List<TextEditingController> controllers,
    required String hintPrefix,
    required Color color,
    required VoidCallback onAdd,
  }) {
    return [
      ...List.generate(controllers.length, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.compact),
          child: Row(
            children: [
              Container(
                width: AppSizes.iconXxl,
                height: AppSizes.iconXxl,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(AppAlpha.glow),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: color,
                      fontSize: AppText.xs,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                child: TextField(
                  controller: controllers[i],
                  decoration: InputDecoration(hintText: '$hintPrefix ${i + 1}'),
                ),
              ),
              if (controllers.length > 2)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: AppSizes.iconLarge,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    setState(() {
                      controllers[i].dispose();
                      controllers.removeAt(i);
                    });
                  },
                ),
            ],
          ),
        );
      }),
      TextButton.icon(
        onPressed: onAdd,
        icon: Icon(Icons.add, size: AppSizes.iconLarge, color: color),
        label: Text(context.tr('Add'), style: TextStyle(color: color)),
      ),
    ];
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter a persona name'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    final vocabulary = _vocabularyControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final objections = _objectionControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final persona = Persona(
      id: widget.personaId,
      name: _nameController.text.trim(),
      demographics: PersonaDemographics(
        role: _roleController.text.trimOrNull,
        industry: _industryController.text.trimOrNull,
        ageRange: _ageRangeController.text.trimOrNull,
        experienceLevel: _experienceController.text.trimOrNull,
      ),
      painPoints: _painPointControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      goals: _goalControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      language: (vocabulary.isNotEmpty || objections.isNotEmpty)
          ? PersonaLanguage(vocabulary: vocabulary, objections: objections)
          : null,
    );

    try {
      final api = ref.read(apiServiceProvider);
      await api.savePersona(persona);

      ref.invalidate(personasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Persona "{name}" saved', {'name': persona.name}),
            ),
            backgroundColor: AppTheme.approveColor.withAlpha(AppAlpha.text),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
        );
        context.pop();
      }
    } catch (error, stackTrace) {
      if (mounted) {
        showDiagnosticSnackBar(
          context,
          ref,
          message: context.tr('Failed to save persona: {error}', {
            'error': '$error',
          }),
          scope: 'persona.save',
          error: error,
          stackTrace: stackTrace,
          contextData: {
            'personaName': persona.name,
            'personaId': widget.personaId ?? 'new',
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _prefillWithAi() async {
    final activeProject = ref.read(activeProjectProvider);
    final projectId = activeProject?.id;
    final projectRepoUrl = activeProject?.url.trim();

    if (projectId == null || projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('No active project selected.'))),
      );
      return;
    }

    if (projectRepoUrl == null || projectRepoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Current project has no repository URL. Set it first in project settings.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isAutofilling = true);
    try {
      final api = ref.read(apiServiceProvider);
      final draft = await api.generatePersonaDraftFromProject(
        projectId: projectId,
        repoUrl: projectRepoUrl,
      );
      _applyPersonaDraft(draft);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Persona draft generated and pre-filled.')),
          backgroundColor: AppTheme.approveColor.withAlpha(AppAlpha.text),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      final requiresOpenRouterKey = requiresOpenRouterCredential(error);
      final apiError = error is ApiException ? error : null;
      final personaStorageError =
          apiError?.code == 'persona_draft_storage_error';

      showDiagnosticSnackBar(
        context,
        ref,
        message: requiresOpenRouterKey
            ? context.tr(
                'OpenRouter key required. Go to Settings > OpenRouter, save + validate your key, then retry.',
              )
            : personaStorageError
            ? context.tr(
                'Persona generation is temporarily unavailable because the server could not save the AI job. Retry in a few minutes, or copy diagnostics if it keeps failing.',
              )
            : context.tr('Failed to prefill persona with AI: {error}', {
                'error': '$error',
              }),
        scope: 'persona.prefill',
        error: error,
        stackTrace: stackTrace,
        contextData: {
          'projectId': projectId,
          'projectRepoUrl': projectRepoUrl,
          if (apiError?.code != null) 'errorCode': apiError!.code,
          if (apiError?.kind != null) 'errorKind': apiError!.kind,
          if (apiError?.provider != null) 'provider': apiError!.provider,
          if (apiError?.retryable != null) 'retryable': apiError!.retryable,
        },
      );
      if (requiresOpenRouterKey) {
        context.push('/settings');
      }
    } finally {
      if (mounted) {
        setState(() => _isAutofilling = false);
      }
    }
  }

  void _applyPersonaDraft(Map<String, dynamic> draft) {
    final demographics = _asMap(draft['demographics']);
    final language = _asMap(draft['language']);

    final painPoints = _toStringList(
      draft['pain_points'] ?? draft['painPoints'],
    );
    final goals = _toStringList(draft['goals']);
    final vocabulary = _toStringList(language['vocabulary']);
    final objections = _toStringList(language['objections']);

    setState(() {
      _nameController.text = _asString(draft['name']) ?? _nameController.text;
      _roleController.text = _asString(demographics['role']) ?? '';
      _industryController.text = _asString(demographics['industry']) ?? '';
      _ageRangeController.text = _asString(demographics['age_range']) ?? '';
      _experienceController.text =
          _asString(demographics['experience_level']) ?? '';

      _replaceControllers(_painPointControllers, painPoints);
      _replaceControllers(_goalControllers, goals);
      _replaceControllers(_vocabularyControllers, vocabulary);
      _replaceControllers(_objectionControllers, objections);
    });
  }

  void _replaceControllers(
    List<TextEditingController> target,
    List<String> values,
  ) {
    for (final controller in target) {
      controller.dispose();
    }
    target
      ..clear()
      ..addAll(
        values
            .where((entry) => entry.trim().isNotEmpty)
            .map((entry) => TextEditingController(text: entry.trim())),
      );

    while (target.length < 2) {
      target.add(TextEditingController());
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }

  List<String> _toStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  String? _asString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }
}

extension on String {
  String? get trimOrNull {
    final t = trim();
    return t.isEmpty ? null : t;
  }
}
