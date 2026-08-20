import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/api_service.dart';
import '../../../providers/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

const _cadenceModes = ['fixed', 'ramp_up'];
const _clusterModes = ['directory', 'tags', 'auto', 'none'];
const _frameworks = ['astro', 'next', 'hugo', 'jekyll', 'eleventy'];
const _gatingMethods = ['future_date', 'draft_flag', 'both'];
const _rebuildMethods = ['webhook', 'github_actions', 'manual'];

class DripWizardSheet extends ConsumerStatefulWidget {
  const DripWizardSheet({super.key, this.onCreated});
  final VoidCallback? onCreated;

  @override
  ConsumerState<DripWizardSheet> createState() => _DripWizardSheetState();
}

class _DripWizardSheetState extends ConsumerState<DripWizardSheet> {
  int _step = 0;
  bool _submitting = false;
  bool _didSeedDirectoryFromProject = false;

  // Step 1 — Basics
  final _nameCtrl = TextEditingController();
  final _directoryCtrl = TextEditingController(text: 'src/data');

  // Step 2 — Cadence
  String _cadenceMode = 'fixed';
  int _itemsPerDay = 3;
  final _startDateCtrl = TextEditingController();
  final List<int> _publishDays = [0, 1, 2, 3, 4]; // Mon-Fri
  final _publishTimeStartCtrl = TextEditingController(text: '06:00');
  final _publishTimeEndCtrl = TextEditingController(text: '18:00');
  final _timezoneCtrl = TextEditingController(text: 'Europe/Paris');
  int _spacingMinutes = 180;
  final _spacingMinutesCtrl = TextEditingController(text: '180');

  // Step 3 — Clustering
  String _clusterMode = 'directory';
  bool _pillarFirst = true;

  // Step 4 — Deploy
  String _framework = 'astro';
  String _gatingMethod = 'future_date';
  String _rebuildMethod = 'manual';
  final _webhookUrlCtrl = TextEditingController();
  final _githubRepoCtrl = TextEditingController();
  bool _indexProof = true;
  bool _requireOptIn = true;
  final _optInFieldCtrl = TextEditingController(text: 'dripManaged');
  final _robotsFieldCtrl = TextEditingController(text: 'robots');
  bool _gscEnabled = false;
  bool _gscSubmitUrls = true;
  int _gscMaxPerDay = 200;
  final _gscSiteUrlCtrl = TextEditingController();
  bool _isGithubRepoPickerLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(days: 1));
    _startDateCtrl.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _directoryCtrl.dispose();
    _startDateCtrl.dispose();
    _publishTimeStartCtrl.dispose();
    _publishTimeEndCtrl.dispose();
    _timezoneCtrl.dispose();
    _spacingMinutesCtrl.dispose();
    _webhookUrlCtrl.dispose();
    _githubRepoCtrl.dispose();
    _optInFieldCtrl.dispose();
    _robotsFieldCtrl.dispose();
    _gscSiteUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('New Drip Plan — Step {step}/4', {
                      'step': _step + 1,
                    }),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Container(
                    height: AppSpacing.xxs,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxsHalf),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.xxs),
                      color: i <= _step
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: switch (_step) {
                0 => _buildStep1(),
                1 => _buildStep2(),
                2 => _buildStep3(),
                3 => _buildStep4(),
                _ => const SizedBox.shrink(),
              },
            ),
          ),

          // Footer buttons
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: () => setState(() => _step--),
                    child: Text(context.tr('Back')),
                  ),
                const Spacer(),
                if (_step < 3)
                  FilledButton(
                    onPressed: _canAdvance
                        ? () => setState(() => _step++)
                        : null,
                    child: Text(context.tr('Next')),
                  ),
                if (_step == 3)
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: AppSpacing.lg,
                            height: AppSpacing.lg,
                            child: CircularProgressIndicator(strokeWidth: AppStroke.medium),
                          )
                        : Text(context.tr('Create Plan')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _canAdvance => switch (_step) {
    0 => _nameCtrl.text.trim().isNotEmpty,
    1 =>
      _startDateCtrl.text.isNotEmpty &&
          _publishDays.isNotEmpty &&
          _isTimeRangeValid(
            _publishTimeStartCtrl.text.trim(),
            _publishTimeEndCtrl.text.trim(),
          ),
    2 => true,
    _ => true,
  };

  bool _isTimeRangeValid(String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    if (startParts.length != 2 || endParts.length != 2) {
      return false;
    }
    final startHour = int.tryParse(startParts[0]);
    final startMinute = int.tryParse(startParts[1]);
    final endHour = int.tryParse(endParts[0]);
    final endMinute = int.tryParse(endParts[1]);
    if (startHour == null ||
        startMinute == null ||
        endHour == null ||
        endMinute == null ||
        startHour < 0 ||
        startHour > 23 ||
        endHour < 0 ||
        endHour > 23 ||
        startMinute < 0 ||
        startMinute > 59 ||
        endMinute < 0 ||
        endMinute > 59) {
      return false;
    }
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    return startMinutes < endMinutes;
  }

  String _localizedWeekDay(int index) => switch (index) {
    0 => context.tr('Mon'),
    1 => context.tr('Tue'),
    2 => context.tr('Wed'),
    3 => context.tr('Thu'),
    4 => context.tr('Fri'),
    5 => context.tr('Sat'),
    _ => context.tr('Sun'),
  };

  // ─── Step 1: Basics ──────────────────────────────

  Widget _buildStep1() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr('Name & Source'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _nameCtrl,
        decoration: InputDecoration(
          labelText: context.tr('Plan name'),
          hintText: context.tr('e.g. GoCharbon Launch'),
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: AppSpacing.md),
      _buildDirectoryPresets(),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _directoryCtrl,
        decoration: InputDecoration(
          labelText: context.tr('Content directory'),
          hintText: context.tr('e.g. src/data'),
          helperText: context.tr(
            'Parcourir l\'arborescence du dépôt pour choisir un dossier',
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: context.tr('Parcourir les dossiers'),
            onPressed: ref.read(activeProjectProvider) == null
                ? null
                : () => _openDirectoryBrowser(context),
          ),
          border: const OutlineInputBorder(),
        ),
      ),
    ],
  );

  Future<void> _openDirectoryBrowser(BuildContext context) async {
    final activeProject = ref.read(activeProjectProvider);
    if (activeProject == null) {
      return;
    }

    final initialPath = _directoryCtrl.text.trim();
    final selectedPath = await showDialog<String>(
      context: context,
      builder: (context) {
        String browsePath = initialPath;
        String normalizePath(String path) {
          return path
              .replaceAll('\\', '/')
              .replaceAll(RegExp(r'^/+'), '')
              .replaceAll(RegExp(r'/+$'), '');
        }

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.tr('Choisir le dossier de contenu')),
            content: SizedBox(
              width: 420,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.tr('Chemin sélectionné')}: ${browsePath.isEmpty ? '/' : browsePath}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: ref
                          .read(apiServiceProvider)
                          .fetchProjectContentTree(
                            projectId: activeProject.id,
                            path: browsePath.isEmpty ? null : browsePath,
                          ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              '${context.tr('Unable to load content tree')}: ${snapshot.error}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          );
                        }
                        final data = snapshot.data ?? const {};
                        final entries =
                            (data['directories'] as List?)
                                ?.whereType<Map<String, dynamic>>()
                                .toList() ??
                            const [];

                        if (entries.isEmpty) {
                          return Center(
                            child: Text(
                              context.tr(
                                'Aucun dossier détecté à cet emplacement',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        }

                        final parentPath = data['parent_path']?.toString();

                        return ListView(
                          children: [
                            if (parentPath != null)
                              ListTile(
                                leading: const Icon(Icons.arrow_upward),
                                title: Text(
                                  context.tr('Remonter d\'un niveau'),
                                ),
                                onTap: () {
                                  setState(() {
                                    browsePath = parentPath;
                                  });
                                },
                              )
                            else
                              const SizedBox.shrink(),
                            ...entries.map((entry) {
                              final name = entry['name']?.toString() ?? '';
                              final path = entry['path']?.toString() ?? name;
                              final hasMarkdown =
                                  entry['has_markdown_files'] == true;

                              return ListTile(
                                leading: const Icon(Icons.folder),
                                title: Text(name),
                                subtitle: Text(
                                  hasMarkdown
                                      ? context.tr(
                                          'Contient des fichiers markdown',
                                        )
                                      : context.tr(
                                          'Aucun fichier markdown trouvé',
                                        ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                selected:
                                    normalizePath(path) ==
                                    normalizePath(browsePath),
                                onTap: () {
                                  setState(() {
                                    browsePath = normalizePath(path);
                                  });
                                },
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Annuler')),
              ),
              FilledButton(
                onPressed: browsePath.isEmpty
                    ? null
                    : () => Navigator.pop(context, normalizePath(browsePath)),
                child: Text(context.tr('Choisir ce dossier')),
              ),
            ],
          ),
        );
      },
    );

    if (selectedPath != null) {
      setState(() => _directoryCtrl.text = selectedPath);
    }
  }

  Widget _buildDirectoryPresets() {
    final activeProject = ref.watch(activeProjectProvider);
    final presetPaths =
        activeProject?.settings?.contentDirectories
            .map((entry) => entry.path.trim())
            .where((path) => path.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];

    if (presetPaths.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!_didSeedDirectoryFromProject && _directoryCtrl.text.trim().isEmpty) {
      _didSeedDirectoryFromProject = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _directoryCtrl.text = presetPaths.first;
        });
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Suggestions depuis le projet actif'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: presetPaths
              .map(
                (path) => ActionChip(
                  label: Text(path),
                  onPressed: () => setState(() => _directoryCtrl.text = path),
                  labelStyle: TextStyle(
                    color: _directoryCtrl.text.trim() == path
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  backgroundColor: _directoryCtrl.text.trim() == path
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.surfaceContainer,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ─── Step 2: Cadence ─────────────────────────────

  Widget _buildStep2() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr('Cadence'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: AppSpacing.md),
      SegmentedButton<String>(
        segments: _cadenceModes
            .map(
              (m) => ButtonSegment(
                value: m,
                label: Text(
                  m == 'ramp_up' ? context.tr('Ramp up') : context.tr('Fixed'),
                ),
              ),
            )
            .toList(),
        selected: {_cadenceMode},
        onSelectionChanged: (s) => setState(() => _cadenceMode = s.first),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: context.tr('Articles/day'),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: '$_itemsPerDay'),
              onChanged: (v) => _itemsPerDay = int.tryParse(v) ?? 3,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _startDateCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Start date'),
                border: const OutlineInputBorder(),
                hintText: context.tr('YYYY-MM-DD'),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Text(context.tr('Random publish time')),
      const SizedBox(height: AppSpacing.xs),
      Text(
        context.tr(
          'Choose a daily time window. Publishing will be random inside this window.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _publishTimeStartCtrl,
              decoration: InputDecoration(
                labelText: context.tr('From (HH:MM)'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _publishTimeEndCtrl,
              decoration: InputDecoration(
                labelText: context.tr('To (HH:MM)'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _timezoneCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Timezone'),
                border: const OutlineInputBorder(),
                hintText: context.tr('e.g. Europe/Paris'),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: context.tr('Spacing (min)'),
                border: const OutlineInputBorder(),
                helperText: context.tr('Intra-day spacing when >1/day'),
              ),
              keyboardType: TextInputType.number,
              controller: _spacingMinutesCtrl,
              onChanged: (v) => _spacingMinutes = int.tryParse(v) ?? 180,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        context.tr('Publish days'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: AppSpacing.xs,
        children: List.generate(
          7,
          (i) => FilterChip(
            label: Text(_localizedWeekDay(i)),
            selected: _publishDays.contains(i),
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _publishDays.add(i);
                } else {
                  _publishDays.remove(i);
                }
                _publishDays.sort();
              });
            },
          ),
        ),
      ),
    ],
  );

  // ─── Step 3: Clustering ──────────────────────────

  Widget _buildStep3() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr('Stratégie de clustering'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        context.tr(
          'Le clustering est la logique de groupement thématique qui décide de l’ordre d’apparition des articles.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        context.tr(
          'Objectif éditorial : publier les contenus dans une séquence qui fait sens (des concepts larges vers les déclinaisons), pour réduire la dispersion et faciliter la lecture continue.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.md),
      ...(_clusterModes.map(
        (m) => ListTile(
          leading: Icon(
            _clusterMode == m
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: _clusterMode == m
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          title: Text(switch (m) {
            'directory' => context.tr('Par structure de dossier'),
            'tags' => context.tr('Par tag de front matter'),
            'auto' => context.tr('Auto (détection sémantique des cocons)'),
            'none' => context.tr('Sans clustering (ordre alphabétique)'),
            _ => m,
          }),
          subtitle: Text(switch (m) {
            'directory' => context.tr(
              'Le clustering par dossier exploite la structure du dépôt (`/blog`, `/blog/seo`, `/newsletter`).'
              ' Cette méthode est robuste si votre arborescence reflète déjà la hiérarchie éditoriale.',
            ),
            'tags' => context.tr(
              'Le clustering par tags lit les métadonnées `front matter` et regroupe les contenus qui partagent des sujets similaires.'
              ' C’est la méthode adaptée si votre taxonomie est bien tenue et cohérente entre articles.',
            ),
            'auto' => context.tr(
              'Le mode Auto reconstruit les cocons automatiquement à partir des similarités sémantiques du corpus.'
              ' Il identifie les relations logiques entre contenus même si vos tags ou dossiers sont imparfaits.',
            ),
            'none' => context.tr(
              'Le mode “Sans clustering” ne force aucun regroupement éditorial.'
              ' La publication suit uniquement la cadence/régularité définies, sans ordre thématique supplémentaire.',
            ),
            _ => '',
          }, style: const TextStyle(fontSize: AppText.xs)),
          onTap: () => setState(() => _clusterMode = m),
        ),
      )),
      const SizedBox(height: AppSpacing.xs),
      SwitchListTile(
        title: Text(context.tr('Publier le pilier avant les satellites')),
        subtitle: Text(
          context.tr(
            'Le “pilier” est l’article central d’un thème ; les “satellites” sont les contenus qui l’approfondissent.'
            ' Quand cette option est activée, l’ordre devient : “pilier puis satellites”.'
            ' Cela améliore la cohérence éditoriale quand un sujet est construit progressivement.',
          ),
          style: const TextStyle(fontSize: AppText.xs),
        ),
        value: _pillarFirst,
        onChanged: (v) => setState(() => _pillarFirst = v),
      ),
    ],
  );

  // ─── Step 4: Deploy ──────────────────────────────

  Widget _buildStep4() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr('Déploiement'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<String>(
        initialValue: _framework,
        decoration: InputDecoration(
          labelText: context.tr('Framework SSG'),
          border: const OutlineInputBorder(),
        ),
        items: _frameworks
            .map(
              (f) => DropdownMenuItem(
                value: f,
                child: Text(f[0].toUpperCase() + f.substring(1)),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _framework = v!),
      ),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<String>(
        initialValue: _gatingMethod,
        decoration: InputDecoration(
          labelText: context.tr('Méthode de contrôle'),
          border: const OutlineInputBorder(),
        ),
        items: _gatingMethods
            .map(
              (g) => DropdownMenuItem(
                value: g,
                child: Text(switch (g) {
                  'future_date' => context.tr(
                    'Date de publication future (recommandé)',
                  ),
                  'draft_flag' => context.tr('Drapeau draft'),
                  'both' => context.tr('Les deux'),
                  _ => g,
                }),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _gatingMethod = v!),
      ),
      const SizedBox(height: AppSpacing.xs),
      Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm, right: AppSpacing.sm, bottom: AppSpacing.xs),
        child: Text(switch (_gatingMethod) {
          'future_date' => context.tr(
            'Méthode de contrôle par date : le front matter reçoit une date de publication future.'
            ' Tant que cette date n’est pas atteinte, le moteur SSG considère la page comme planifiée.'
            ' Ce mode dépend directement du support de la planification par votre générateur de site.',
          ),
          'draft_flag' => context.tr(
            'Méthode de contrôle par flag : le front matter est écrit avec `draft: true` (ou équivalent) avant publication.'
            ' Au moment de la sortie prévue, le flag est retiré pour rendre l’article visible.'
            ' Utile quand votre pipeline sait déjà gérer le brouillon de manière explicite.',
          ),
          'both' => context.tr(
            'Méthode combinée : Drip applique à la fois la date future et `draft: true`, puis lève les deux en même temps.'
            ' Plus strict, ce mode réduit les risques de publication prématurée.'
            ' À privilégier si votre pipeline est strict sur les deux mécanismes.',
          ),
          _ => '',
        }, style: Theme.of(context).textTheme.bodySmall),
      ),
      const SizedBox(height: AppSpacing.sm),
      SwitchListTile(
        title: Text(
          context.tr(
            'Protection indexation précoce (noindex jusqu’à publication)',
          ),
        ),
        subtitle: Text(
          context.tr(
            'Met automatiquement un marqueur noindex dans le front matter tant que le contenu n’est pas publié. Ce mode limite fortement l’indexation prématurée, mais n’est pas une garantie absolue : c’est efficace si votre stack (build, CDN, headers, robots/meta) applique bien ce signal au crawl.',
          ),
          style: const TextStyle(fontSize: AppText.xs),
        ),
        value: _indexProof,
        onChanged: (v) => setState(() => _indexProof = v),
      ),
      SwitchListTile(
        title: Text(context.tr('Mode sécurisé (opt-in requis)')),
        subtitle: Text(
          context.tr(
            'Recommandé si votre repository mélange du contenu Drip et du contenu éditorial indépendant. Quand ce mode est actif, on ne modifie le front matter que pour les fichiers qui portent explicitement le champ d’opt-in (ex: dripManaged: true), évitant de toucher aux pages non Drip.',
          ),
          style: const TextStyle(fontSize: AppText.xs),
        ),
        value: _requireOptIn,
        onChanged: (v) => setState(() => _requireOptIn = v),
      ),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<String>(
        initialValue: _rebuildMethod,
        decoration: InputDecoration(
          labelText: context.tr('Méthode de rebuild'),
          border: const OutlineInputBorder(),
        ),
        items: _rebuildMethods
            .map(
              (r) => DropdownMenuItem(
                value: r,
                child: Text(switch (r) {
                  'webhook' => context.tr('Webhook (Vercel/Netlify)'),
                  'github_actions' => context.tr('GitHub Actions'),
                  'manual' => context.tr('Manuel'),
                  _ => r,
                }),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _rebuildMethod = v!),
      ),
      const SizedBox(height: AppSpacing.xs),
      Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm, right: AppSpacing.sm, bottom: AppSpacing.xs),
        child: Text(switch (_rebuildMethod) {
          'webhook' => context.tr(
            'Le webhook notifie votre pipeline CI/CD à chaque exécution Drip.'
            ' Il déclenche un rebuild automatique pour propager les changements de front matter.'
            ' Idéal pour une publication continue et sans intervention manuelle.',
          ),
          'github_actions' => context.tr(
            'GitHub Actions lance un workflow `daily-drip.yml` via `workflow_dispatch` (branche main par défaut). Requiert `GITHUB_TOKEN` côté backend/API pour l’authentification.',
          ),
          'manual' => context.tr(
            'Mode manuel = aucun déclenchement automatique.'
            ' Le plan applique les modifications en front matter, puis vous lancez le rebuild selon votre process.'
            ' Cette option convient quand vous centralisez la publication dans une étape personnalisée.',
          ),
          _ => '',
        }, style: Theme.of(context).textTheme.bodySmall),
      ),
      if (_rebuildMethod == 'webhook') ...[
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _webhookUrlCtrl,
          decoration: InputDecoration(
            labelText: context.tr('URL du webhook'),
            border: const OutlineInputBorder(),
            hintText: context.tr(
              'https://api.vercel.com/v1/integrations/deploy/...',
            ),
          ),
        ),
      ],
      if (_rebuildMethod == 'github_actions') ...[
        const SizedBox(height: AppSpacing.md),
        if (ref.watch(githubIntegrationStatusProvider).value?.connected !=
            true) ...[
          Text(
            context.tr(
              'Connectez votre compte GitHub pour sélectionner un dépôt public ou privé.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            icon: const Icon(Icons.link),
            onPressed: () => _connectGithubFromDrip(),
            label: Text(context.tr('Connecter GitHub')),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: _githubRepoCtrl,
          decoration: InputDecoration(
            labelText: context.tr('Référentiel GitHub'),
            suffixIcon: IconButton(
              tooltip: context.tr('Choisir un dépôt GitHub'),
              icon: _isGithubRepoPickerLoading
                  ? const SizedBox(
                      width: AppSpacing.md,
                      height: AppSpacing.md,
                      child: CircularProgressIndicator(strokeWidth: AppStroke.medium),
                    )
                  : const Icon(Icons.travel_explore),
              onPressed: _isGithubRepoPickerLoading
                  ? null
                  : ref
                            .watch(githubIntegrationStatusProvider)
                            .value
                            ?.connected ==
                        true
                  ? _openGithubRepoPickerForDrip
                  : _connectGithubFromDrip,
            ),
            border: const OutlineInputBorder(),
            hintText: context.tr('owner/repo'),
          ),
        ),
        if (ref.watch(githubIntegrationStatusProvider).value?.connected != true)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              context.tr(
                'Une connexion GitHub est requise pour charger la liste des dépôts.',
              ),
              style: const TextStyle(fontSize: AppText.xs),
            ),
          ),
      ],
      const SizedBox(height: AppSpacing.xs),
      ExpansionTile(
        title: Text(context.tr('Options avancées')),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              controller: _optInFieldCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Opt-in frontmatter field'),
                border: const OutlineInputBorder(),
                hintText: context.tr('e.g. dripManaged'),
                helperText: context.tr(
                  'Champ lu quand le mode sécurisé est actif. Seuls les fichiers qui possèdent ce champ peuvent être modifiés par le drip.',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              controller: _robotsFieldCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Robots frontmatter field'),
                border: const OutlineInputBorder(),
                hintText: context.tr('e.g. robots'),
                helperText: context.tr(
                  'Champ front matter utilisé pour appliquer/retirer le noindex tant que le contenu n’est pas réellement publié.',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            title: Text(context.tr('Google Search Console (Indexing API)')),
            subtitle: Text(
              context.tr(
                'Après chaque exécution du drip, Drip peut notifier Google (Indexing API) pour accélérer la découverte des pages déjà publiées. C’est une notification de "mise à jour", pas une garantie d’indexation instantanée.',
              ),
              style: const TextStyle(fontSize: AppText.xs),
            ),
            value: _gscEnabled,
            onChanged: (v) => setState(() => _gscEnabled = v),
          ),
          if (_gscEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                controller: _gscSiteUrlCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('URL de la propriété GSC'),
                  border: const OutlineInputBorder(),
                  hintText: context.tr('https://your-site.com'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Soumettre les URL')),
                value: _gscSubmitUrls,
                onChanged: (v) => setState(() => _gscSubmitUrls = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                decoration: InputDecoration(
                  labelText: context.tr('Soumissions max / jour'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: '$_gscMaxPerDay'),
                onChanged: (v) => _gscMaxPerDay = int.tryParse(v) ?? 200,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                context.tr(
                  'La logique backend soumet les URL via l’API d’indexation Google et vérifie ensuite l’état en mode inspection si disponible. La limite par défaut est de 200 URLs/jour, cohérente avec le comportement courant de l’API, et dépend du quota réel de votre projet Google.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    ],
  );

  // ─── Submit ──────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final api = ref.read(apiServiceProvider);

    try {
      final result = await api.createDripPlan({
        'name': _nameCtrl.text.trim(),
        'cadence': {
          'mode': _cadenceMode,
          'items_per_day': _itemsPerDay,
          'start_date': _startDateCtrl.text.trim(),
          'publish_days': _publishDays,
          'publish_time_start': _publishTimeStartCtrl.text.trim(),
          'publish_time_end': _publishTimeEndCtrl.text.trim(),
          'timezone': _timezoneCtrl.text.trim(),
          'spacing_minutes': _spacingMinutes,
        },
        'cluster_strategy': {
          'mode': _clusterMode,
          'pillar_first': _pillarFirst,
        },
        'ssg_config': {
          'framework': _framework,
          'gating_method': _gatingMethod,
          'rebuild_method': _rebuildMethod,
          if (_rebuildMethod == 'webhook')
            'rebuild_webhook_url': _webhookUrlCtrl.text.trim(),
          if (_rebuildMethod == 'github_actions')
            'rebuild_github_repo': _githubRepoCtrl.text.trim(),
          'content_directory': _directoryCtrl.text.trim(),
          'require_opt_in': _requireOptIn,
          'frontmatter_opt_in_field': _optInFieldCtrl.text.trim(),
          'enforce_robots_noindex_until_publish': _indexProof,
          'frontmatter_robots_field': _robotsFieldCtrl.text.trim(),
        },
        if (_gscEnabled)
          'gsc_config': {
            'enabled': true,
            'site_url': _gscSiteUrlCtrl.text.trim(),
            'submit_urls': _gscSubmitUrls,
            'max_submissions_per_day': _gscMaxPerDay,
          },
      });

      if (mounted) {
        widget.onCreated?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['queued'] == true
                  ? context.tr(
                      'Drip plan queued. It will sync when FastAPI is back.',
                    )
                  : context.tr(
                      'Drip plan created! Import content to get started.',
                    ),
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      if (mounted) {
        showDiagnosticSnackBar(
          context,
          ref,
          message: context.tr('Error: {error}', {'error': '$error'}),
          scope: 'drip.create_plan',
          error: error,
          stackTrace: stackTrace,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openGithubRepoPickerForDrip() async {
    final githubStatus = ref.read(githubIntegrationStatusProvider).value;
    if (githubStatus?.connected != true) {
      await _connectGithubFromDrip();
      return;
    }

    final api = ref.read(apiServiceProvider);
    setState(() => _isGithubRepoPickerLoading = true);

    try {
      final repos = await api.fetchGithubRepos();
      if (!mounted) {
        return;
      }
      if (repos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('No repository found for this account.')),
          ),
        );
        return;
      }

      final selected = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (context) {
          final sorted = [...repos]
            ..sort((a, b) {
              final updatedA = a['updated_at']?.toString() ?? '';
              final updatedB = b['updated_at']?.toString() ?? '';
              return updatedB.compareTo(updatedA);
            });

          return AlertDialog(
            title: Text(context.tr('Choose GitHub repository')),
            content: SizedBox(
              width: 540,
              height: 420,
              child: ListView(
                children: sorted
                    .whereType<Map<String, dynamic>>()
                    .map(
                      (repo) => ListTile(
                        leading: const Icon(Icons.folder_copy_rounded),
                        title: Text(repo['full_name']?.toString() ?? ''),
                        subtitle: Text(
                          (repo['description']?.toString() ?? '').isEmpty
                              ? context.tr('No description')
                              : repo['description'].toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, {
                          'full_name': repo['full_name']?.toString() ?? '',
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Cancel')),
              ),
            ],
          );
        },
      );

      if (selected == null || !mounted) return;
      final selectedRepo = selected['full_name']?.toString() ?? '';
      if (selectedRepo.isNotEmpty) {
        setState(() => _githubRepoCtrl.text = selectedRepo);
      }
    } finally {
      if (mounted) setState(() => _isGithubRepoPickerLoading = false);
    }
  }

  Future<void> _connectGithubFromDrip() async {
    final api = ref.read(apiServiceProvider);
    String? connectUrl;
    try {
      connectUrl = await api.getGithubConnectUrl();
    } on ApiException catch (error, stackTrace) {
      if (!mounted) return;
      showDiagnosticSnackBar(
        context,
        ref,
        message: context.tr(
          'L’authentification GitHub est indisponible : {error}',
          {'error': error.message},
        ),
        scope: 'drip.github.connect',
        error: error,
        stackTrace: stackTrace,
        contextData: {'path': error.path, 'statusCode': error.statusCode},
      );
      return;
    }

    if (connectUrl == null || connectUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'L’authentification GitHub n’est pas disponible. Vérifiez la configuration backend.',
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error.withValues(
            alpha: AppOpacity.prominent,
          ),
        ),
      );
      return;
    }

    final uri = Uri.parse(connectUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('Connexion GitHub')),
          content: Text(
            context.tr(
              'Une fenêtre navigateur s’est ouverte pour autoriser ContentGlows.'
              ' Revenez ici puis appuyez sur Actualiser pour mettre à jour l’état.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('Fermer')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.invalidate(githubIntegrationStatusProvider);
              },
              child: Text(context.tr('Actualiser')),
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Impossible d’ouvrir le navigateur pour l’autorisation GitHub.',
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error.withValues(
            alpha: AppOpacity.prominent,
          ),
        ),
      );
    }
  }
}
