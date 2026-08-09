import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/app_language.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale(appLanguageEnglish),
    Locale(appLanguageFrench),
  ];

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations not found in context.');
    return localizations!;
  }

  bool get isFrench =>
      locale.languageCode.toLowerCase().startsWith(appLanguageFrench);

  String tr(
    String key, {
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    final template =
        _localizedValues[isFrench
            ? appLanguageFrench
            : appLanguageEnglish]?[key] ??
        _localizedValues[appLanguageEnglish]?[key] ??
        key;

    if (params.isEmpty) {
      return template;
    }

    return template.replaceAllMapped(RegExp(r'\{([a-zA-Z0-9_]+)\}'), (match) {
      final name = match.group(1);
      if (name == null) {
        return match.group(0) ?? '';
      }
      final replacement = params[name];
      return replacement?.toString() ?? match.group(0) ?? '';
    });
  }

  static const Map<String, String> _frenchTranslations = <String, String>{
    '/day': '/jour',
    '/month': '/mois',
    '/week': '/semaine',
    '(no title)': '(sans titre)',
    'AI content ops for founders, creators, and lean teams':
        'Des opérations de contenu IA pour fondateurs, créateurs et petites équipes',
    'AI, Flutter, SaaS': 'IA, Flutter, SaaS',
    'AI generates content, you swipe to publish.':
        'L’IA génère du contenu, vous validez d’un swipe pour publier.',
    'API URL': 'URL de l’API',
    'API diagnostics': 'Diagnostics API',
    'Access denied. This view is visible only to allowlisted accounts.':
        'Accès refusé. Cette vue n’est visible que pour les comptes autorisés.',
    'Account-first entry': 'Entrée centrée sur le compte',
    'Actions from robots and your work will appear here':
        'Les actions des robots et de votre travail apparaîtront ici',
    'Activity': 'Activité',
    'Affiliations': 'Affiliations',
    'All': 'Tous',
    'All ({count})': 'Tout ({count})',
    'All caught up!': 'Tout est à jour !',
    'All content passes basic audit checks':
        'Tout le contenu passe les vérifications d’audit de base',
    'All types': 'Tous les types',
    'Already signed in? Open App': 'Déjà connecté ? Ouvrir l’app',
    'Analytics': 'Analytique',
    'Analytics will appear as content flows through the pipeline':
        'Les analytics apparaîtront à mesure que le contenu avance dans le pipeline.',
    'Analyze': 'Analyser',
    'App language': 'Langue de l’application',
    'App colors': 'Couleurs app',
    'Appearance': 'Apparence',
    'Approval Rate': 'Taux d’approbation',
    'Approve all?': 'Tout approuver ?',
    'Approve {count}': 'Approuver {count}',
    'Approved': 'Approuvé',
    'Approved {approved} items': '{approved} éléments approuvés',
    'Approved {approved}, failed {failed}':
        '{approved} approuvés, {failed} échecs',
    'Articles grouped by topic cluster':
        'Articles regroupés par cluster thématique',
    'Audio': 'Audio',
    'Audio Feedback': 'Feedback audio',
    'Audio feedback': 'Feedback audio',
    'Audio feedback sent.': 'Feedback audio envoyé.',
    'Audio message': 'Message audio',
    'Audio ready: {duration}': 'Audio prêt : {duration}',
    'Audio unavailable': 'Audio indisponible',
    'Audit': 'Audit',
    'Auth': 'Auth',
    'Authentication': 'Authentification',
    'About': 'À propos',
    'Backend Connection': 'Connexion backend',
    'Backend-aware recovery': 'Récupération orientée backend',
    'Blog articles': 'Articles de blog',
    'Cancel': 'Annuler',
    'Archive': 'Archiver',
    'Archive this project from the active workspace list?':
        'Archiver ce projet de la liste active du workspace ?',
    'Archived': 'Archivé',
    'Change project & content type settings':
        'Modifier le projet et les paramètres de type de contenu',
    'Channel Distribution': 'Répartition par canal',
    'Check for new content': 'Vérifier le nouveau contenu',
    'Checking...': 'Vérification...',
    'Check your project, content types, and generation frequency before the first run.':
        'Vérifiez votre projet, les types de contenu et la fréquence de génération avant le premier lancement.',
    'Close app': 'Fermer l’application',
    'Close ContentGlows?': 'Fermer ContentGlows ?',
    'Changes are queued for sync. Publishing is blocked until the full body is saved online.':
        'Les changements sont en attente de synchronisation. La publication est bloquée tant que le contenu complet n’est pas enregistré en ligne.',
    'Are you sure you want to close the application?':
        'Est-ce que vous êtes sûr de vouloir fermer l’application ?',
    'Choose how ContentGlows chooses its interface language.':
        'Choisissez comment ContentGlows sélectionne la langue de son interface.',
    'Choose whether ContentGlows stays bright, stays dark, or follows your device appearance automatically.':
        'Choisissez si ContentGlows reste clair, reste sombre ou suit automatiquement l’apparence de votre appareil.',
    'Choose the types of content the AI should generate for you, and how often.':
        'Choisissez les types de contenu que l’IA doit générer pour vous, ainsi que leur fréquence.',
    'Clear Local Clerk Session': 'Effacer la session Clerk locale',
    'Clerk is not configured': 'Clerk n’est pas configuré',
    'Common objections': 'Objections fréquentes',
    'Connect': 'Connecter',
    'Connect your project': 'Connectez votre projet',
    'Connect your project source': 'Connectez la source de votre projet',
    'GitHub connection is optional. Connect it only if you want to pick a repository automatically.':
        'La connexion GitHub est optionnelle. Connecte-la seulement si tu veux sélectionner un dépôt automatiquement.',
    'Connected': 'Connecté',
    'Connecting {channelName}': 'Connexion à {channelName}',
    'Content': 'Contenu',
    'Content Angles': 'Angles de contenu',
    'Content Approval Pipeline v0.1.0':
        'Pipeline d’approbation de contenu v0.1.0',
    'Content Clusters': 'Clusters de contenu',
    'Content Engine': 'Moteur de contenu',
    'Content Feed': 'Flux de contenu',
    'Content Frequency': 'Fréquence de contenu',
    'Content Tools': 'Outils de contenu',
    'Content by Type': 'Contenu par type',
    'Content generation waits for your review':
        'La génération de contenu attend votre validation',
    'Content frequency settings are temporarily unavailable':
        'Les réglages de fréquence du contenu sont temporairement indisponibles',
    'Content is generated automatically':
        'Le contenu est généré automatiquement',
    'ContentGlows': 'ContentGlows',
    'ContentGlows app': 'App ContentGlows',
    'Continue': 'Continuer',
    'Continue with Google': 'Continuer avec Google',
    'Create': 'Créer',
    'Create Account': 'Créer un compte',
    'Create content': 'Créer du contenu',
    'Create your first content': 'Créer votre premier contenu',
    'Copy diagnostics': 'Copier le diagnostic',
    'Copy error': 'Copier l’erreur',
    'Copy this error': 'Copier cette erreur',
    'Could not check newsletter config':
        'Impossible de vérifier la configuration newsletter',
    'Could not fetch connected accounts':
        'Impossible de récupérer les comptes connectés',
    'Connected accounts could not be loaded right now. Publishing stays available only for already-resolved flows.':
        'Les comptes connectés n’ont pas pu être chargés pour le moment. La publication reste disponible uniquement pour les flux déjà résolus.',
    'Could not get connect URL for {channelName}':
        'Impossible d’obtenir l’URL de connexion pour {channelName}',
    'Could not load feedback': 'Impossible de charger les feedbacks',
    'Could not load local history': 'Impossible de charger l’historique local',
    'Could not load the review queue': 'Impossible de charger la file de revue',
    'Could not open browser for {channelName} authorization':
        'Impossible d’ouvrir le navigateur pour l’autorisation {channelName}',
    'Curate ideas before generation': 'Trier les idées avant génération',
    'Dark': 'Sombre',
    'Delete': 'Supprimer',
    'Delete from this device?': 'Supprimer de cet appareil ?',
    'Delete from device': 'Supprimer de l’appareil',
    'Degraded mode diagnostics copied.':
        'Le diagnostic du mode dégradé a été copié.',
    'Degraded mode is active. Backend-dependent screens stay limited until FastAPI recovers.':
        'Le mode dégradé est actif. Les écrans dépendants du backend restent limités jusqu’au rétablissement de FastAPI.',
    'Demo workspace locked': 'Workspace démo verrouillé',
    'Diagnostics copied to clipboard.':
        'Le diagnostic a été copié dans le presse-papiers.',
    'Disconnect': 'Déconnecter',
    'Disconnect {channelName}?': 'Déconnecter {channelName} ?',
    'Disconnected {channelName}': '{channelName} déconnecté',
    'Domains': 'Domaines',
    'Edit': 'Modifier',
    'Bold': 'Gras',
    'Italic': 'Italique',
    'Heading': 'Titre',
    'Bulleted list': 'Liste à puces',
    'Quote': 'Citation',
    'Insert link': 'Insérer un lien',
    'Clear formatting': 'Effacer le formatage',
    'Delete paragraph': 'Supprimer le paragraphe',
    'Label (optional)': 'Libellé (optionnel)',
    'Insert': 'Insérer',
    'URL is required': 'URL obligatoire',
    'English': 'Anglais',
    'Enter a valid GitHub repository URL to continue.':
        'Entrez une URL de dépôt GitHub valide pour continuer.',
    'Enter a valid GitHub repository URL.':
        'Entrez une URL de dépôt GitHub valide.',
    'Enter a valid HTTP(S) source URL.':
        'Entrez une URL source HTTP(S) valide.',
    'Enter a valid HTTP(S) source URL, or leave it empty to continue.':
        'Entrez une URL source HTTP(S) valide, ou laissez ce champ vide pour continuer.',
    'Error checking status': 'Erreur lors de la vérification du statut',
    'Error copied to clipboard.': 'L’erreur a été copiée.',
    'Failed to disconnect {channelName}':
        'Impossible de déconnecter {channelName}',
    'Failed to load activity': 'Impossible de charger l’activité',
    'Failed to load content tools':
        'Impossible de charger les outils de contenu',
    'Failed to load history': 'Impossible de charger l’historique',
    'Failed to load the calendar': 'Impossible de charger le calendrier',
    'Failed to schedule. Check backend connection.':
        'Échec de la planification. Vérifiez la connexion backend.',
    'Failed to send audio: {error}': 'Échec de l’envoi audio : {error}',
    'Failed to send: {error}': 'Échec de l’envoi : {error}',
    'Failed to update: {error}': 'Échec de mise à jour : {error}',
    'FastAPI is unavailable. ContentGlows is running in degraded mode until the backend responds again.':
        'FastAPI est indisponible. ContentGlows fonctionne en mode dégradé jusqu’à ce que le backend réponde à nouveau.',
    'Feed': 'Flux',
    'Feed your creator voice & narrative':
        'Alimenter votre voix de créateur et votre narration',
    'Feedback': 'Feedback',
    'Feedback Admin': 'Administration des feedbacks',
    'Feedback marked as read.': 'Feedback marqué comme lu.',
    'Feedback sent.': 'Feedback envoyé.',
    'Follow system appearance': 'Suivre l’apparence du système',
    'Follow system language': 'Suivre la langue du système',
    'French': 'Français',
    'Funnel': 'Tunnel',
    'Generate': 'Générer',
    'Generate & pick content angles':
        'Générer et choisir des angles de contenu',
    'Generate Newsletter': 'Générer une newsletter',
    'Generating...': 'Génération...',
    'Generation failed: {error}': 'Échec de génération : {error}',
    'General audience': 'Audience générale',
    'Get notified when new content is ready':
        'Recevoir une alerte quand du nouveau contenu est prêt',
    'GitHub URL': 'URL GitHub',
    'History': 'Historique',
    'How much content should the AI generate?':
        'Combien de contenu l’IA doit-elle générer ?',
    'How the workflow actually works':
        'Comment le workflow fonctionne réellement',
    'Here is the fixed demo workspace that will be served to every demo user.':
        'Voici le workspace démo fixe qui sera servi à chaque utilisateur démo.',
    'Here\'s your content plan. You can change it anytime in Settings.':
        'Voici votre plan de contenu. Vous pouvez le modifier à tout moment dans Réglages.',
    'Here’s your content plan. You can change it anytime in Settings.':
        'Voici votre plan de contenu. Vous pouvez le modifier à tout moment dans Reglages.',
    'Idea Pool': 'Réservoir d’idées',
    'Idea Pool settings are temporarily unavailable':
        'Les réglages du réservoir d’idées sont temporairement indisponibles',
    'Ideas from newsletters, SEO, competitors and social listening will be held for your review before articles are generated.':
        'Les idées issues des newsletters, du SEO, des concurrents et de l’écoute sociale seront conservées pour votre validation avant la génération des articles.',
    'Issues': 'Problèmes',
    'Issues Found': 'Problèmes détectés',
    'Job ID: {jobId}': 'ID du job : {jobId}',
    'Job started': 'Job démarré',
    'Language': 'Langue',
    'Light': 'Clair',
    'Link your GitHub repository so the AI can analyze your codebase and generate relevant content.':
        'Liez votre dépôt GitHub afin que l’IA puisse analyser votre codebase et générer du contenu pertinent.',
    'Loading Idea Pool settings':
        'Chargement des réglages du réservoir d’idées',
    'Loading connected accounts...': 'Chargement des comptes connectés...',
    'Loading notification preferences':
        'Chargement des préférences de notification',
    'Local Clerk session cleared. Try signing in again.':
        'La session Clerk locale a été effacée. Réessayez de vous connecter.',
    'Manage customer personas': 'Gérer les personas clients',
    'Mark as read': 'Marquer comme lu',
    'Message is empty.': 'Le message est vide.',
    'Microphone access denied.': 'Accès micro refusé.',
    'More': 'Plus',
    'My Tech Blog': 'Mon blog tech',
    'No repo linked': 'Aucun dépôt lié',
    'Name and topics are required': 'Le nom et les sujets sont requis',
    'Newsletter': 'Newsletter',
    'Newsletter agent configured': 'Agent newsletter configuré',
    'Newsletter agent not fully configured':
        'Agent newsletter pas complètement configuré',
    'Newsletter name': 'Nom de la newsletter',
    'Newsletters': 'Newsletters',
    'Next steps': 'Prochaines étapes',
    'No activity yet': 'Aucune activité pour le moment',
    'No audio URL provided by backend.':
        'Aucune URL audio fournie par le backend.',
    'No audio ready to send.': 'Aucun audio prêt à envoyer.',
    'No audio recorded.': 'Aucun audio enregistré.',
    'No connected account found': 'Aucun compte connecté trouvé',
    'No content data for funnel analysis':
        'Aucune donnée de contenu pour l’analyse du tunnel',
    'No content data yet': 'Aucune donnée de contenu pour le moment',
    'No content to audit': 'Aucun contenu à auditer',
    'No content waiting for review': 'Aucun contenu en attente de validation',
    'No data yet': 'Aucune donnée pour le moment',
    'No destination data available': 'Aucune donnée de destination disponible',
    'No feedback for this filter.': 'Aucun feedback pour ce filtre.',
    'No feedback sent recently from this device.':
        'Aucun feedback envoyé récemment depuis cet appareil.',
    'No history yet': 'Aucun historique pour le moment',
    'No pending validations': 'Aucune validation en attente',
    'No published content yet': 'Aucun contenu publié pour le moment',
    'Not wired': 'Non câblé',
    'Not wired to LATE publish flow yet':
        'Pas encore branché au flux de publication LATE',
    'Nothing scheduled yet': 'Rien n’est encore planifié',
    'Notification preferences unavailable':
        'Préférences de notification indisponibles',
    'Notification preferences are temporarily unavailable':
        'Les préférences de notification sont temporairement indisponibles',
    'Notifications': 'Notifications',
    'Off': 'off',
    'Offline (using mock data)': 'Hors ligne (données simulées)',
    'Onboarding': 'Onboarding',
    'Open App Entry': 'Ouvrir l’entrée de l’app',
    'Open Demo Workspace': 'Ouvrir le workspace démo',
    'Open Interactive Demo': 'Ouvrir la démo interactive',
    'Open Uptime': 'Ouvrir Uptime',
    'Pause': 'Pause',
    'Pending': 'En attente',
    'Pending Review': 'En attente de revue',
    'Perf': 'Perf',
    'Performance': 'Performance',
    'Personas': 'Personas',
    'Pipeline Funnel': 'Tunnel du pipeline',
    'Play': 'Lire',
    'Please wait': 'Veuillez patienter',
    'Professional': 'Professionnel',
    'Casual': 'Décontracté',
    'Inspirational': 'Inspirant',
    'Project': 'Projet',
    'Projects': 'Projets',
    'Project settings': 'Paramètres du projet',
    'Project management unavailable':
        'La gestion des projets est temporairement indisponible',
    'Manage projects': 'Gérer les projets',
    'Create project': 'Créer un projet',
    'Edit project': 'Modifier le projet',
    'Switch project': 'Changer de projet',
    'Switch the active project or manage your workspace list':
        'Changer le projet actif ou gérer la liste de votre workspace',
    'Set as default': 'Définir par défaut',
    'Archive project': 'Archiver le projet',
    'Unarchive project': 'Désarchiver le projet',
    'Delete project': 'Supprimer le projet',
    'Detected content directories': 'Dossiers de contenu détectés',
    'Configured sources': 'Sources configurées',
    'Archived projects': 'Projets archivés',
    'Active project': 'Projet actif',
    'Active project updated.': 'Projet actif mis à jour.',
    'Project updated.': 'Projet mis à jour.',
    'No project selected': 'Aucun projet sélectionné',
    'No projects yet': 'Aucun projet pour le moment',
    'No source linked': 'Aucune source liée',
    'Loading projects...': 'Chargement des projets...',
    'Refresh': 'Rafraîchir',
    'Default': 'Par défaut',
    'Restart the guided tour from the beginning':
        'Relancer la visite depuis le début',
    'Archive this project?': 'Archiver ce projet ?',
    'Delete this project from the active workspace list?':
        'Supprimer ce projet de la liste active du workspace ?',
    'Sign in with Google before editing a project.':
        'Connectez-vous avec Google avant de modifier un projet.',
    'Project name': 'Nom du projet',
    'Source URL (optional)': 'URL source (optionnelle)',
    'Push notifications': 'Notifications push',
    'Publish': 'Publier',
    'Publish account connections are unavailable until the backend publish integration is configured.':
        'Les connexions de comptes de publication sont indisponibles tant que l’intégration de publication du backend n’est pas configurée.',
    'Publish Destinations': 'Destinations de publication',
    'Publish connections unavailable':
        'Connexions de publication indisponibles',
    'Published': 'Publié',
    'Publishing Channels': 'Canaux de publication',
    'Publishing Timeline': 'Chronologie de publication',
    'Read': 'Lu',
    'Ready to Schedule': 'Prêt à planifier',
    'Ready to go!': 'Prêt à démarrer !',
    'Recent feedback sent': 'Derniers feedbacks envoyés',
    'Recent review actors': 'Derniers réviseurs',
    'Recently Published': 'Publié récemment',
    'Record': 'Enregistrer',
    'Record a short voice message, then send it.':
        'Enregistrez un court message vocal, puis envoyez-le.',
    'Recording in progress: {duration}': 'Enregistrement en cours : {duration}',
    'Rejected': 'Rejeté',
    'Research': 'Recherche',
    'Retry': 'Réessayer',
    'Review Demo Setup': 'Relire la config démo',
    'Unavailable': 'Indisponible',
    'Review incoming user feedback': 'Examiner les feedbacks utilisateurs',
    'Resume the guided tour': 'Reprendre la visite guidée',
    'Repo-aware onboarding instead of blank-prompt setup':
        'Onboarding relié au dépôt plutôt qu’une configuration vide à base de prompts',
    'Narrative ritual plus personas before generation':
        'Rituel narratif et personas avant la génération',
    'Swipe approval flow tied to real publish actions':
        'Flux d’approbation par swipe relié à de vraies actions de publication',
    'Demo workspace available without sales call':
        'Workspace démo disponible sans appel commercial',
    'You explain your product from scratch in every prompt.':
        'Vous réexpliquez votre produit depuis zéro dans chaque prompt.',
    'Ideas, drafts, and publishing live in separate tools.':
        'Les idées, brouillons et publications vivent dans des outils séparés.',
    'The team loses momentum between generation and approval.':
        'L’équipe perd de l’élan entre la génération et l’approbation.',
    'Publishing still depends on manual copy-paste.':
        'La publication dépend encore de copier-coller manuels.',
    'Your workspace starts from a real repo and a real content plan.':
        'Votre workspace démarre à partir d’un vrai dépôt et d’un vrai plan de contenu.',
    'Rituals and personas sharpen the angle before generation.':
        'Les rituels et personas affinent l’angle avant génération.',
    'Drafts are reviewed with one approval workflow.':
        'Les brouillons sont relus dans un seul workflow d’approbation.',
    'Publishing, scheduling, and channel readiness stay visible.':
        'La publication, la planification et l’état des canaux restent visibles.',
    '1. Connect the product context': '1. Connectez le contexte produit',
    '2. Shape the narrative': '2. Structurez la narration',
    '3. Review and publish': '3. Relisez et publiez',
    'The promise is not "AI writes for you". The promise is a tighter system from source material to published output.':
        'La promesse n’est pas « l’IA écrit pour vous ». La promesse est un système plus serré entre la matière source et la publication.',
    'Onboarding that creates a plan': 'Onboarding qui crée un plan',
    'Project, repo, formats, and cadence are captured before generation starts.':
        'Le projet, le dépôt, les formats et la cadence sont capturés avant le démarrage de la génération.',
    'The app uses ritual and persona inputs to propose more relevant content directions.':
        'L’app utilise les rituels et les personas pour proposer des directions de contenu plus pertinentes.',
    'Operators can swipe through content decisions quickly instead of managing a cluttered queue.':
        'Les opérateurs peuvent swiper rapidement les décisions de contenu au lieu de gérer une file encombrée.',
    'Publishing visibility': 'Visibilité de publication',
    'Why not just use ChatGPT?':
        'Pourquoi ne pas simplement utiliser ChatGPT ?',
    'What makes the demo useful?': 'Qu’est-ce qui rend la démo utile ?',
    'The demo is a stable public workspace, so visitors can inspect the workflow end-to-end before creating their own workspace.':
        'La démo est un workspace public stable, ce qui permet aux visiteurs d’inspecter le workflow de bout en bout avant de créer le leur.',
    'Is this only for social posts?':
        'Est-ce uniquement pour les posts sociaux ?',
    'No. The product already models blog posts, newsletters, social posts, video scripts, and short-form video content.':
        'Non. Le produit modélise déjà les articles de blog, newsletters, posts sociaux, scripts vidéo et contenus vidéo courts.',
    'Start with the stable demo workspace to inspect the flow, then create your own workspace when you are ready to connect a real product.':
        'Commencez avec le workspace démo stable pour inspecter le flux, puis créez votre propre workspace quand vous serez prêt à connecter un vrai produit.',
    'Continue Onboarding': 'Continuer l’onboarding',
    'Setup required': 'Configuration requise',
    'Session active': 'Session active',
    'Session restore': 'Restauration de session',
    'Session error': 'Erreur de session',
    'Sign in to access your workspace':
        'Connectez-vous pour accéder à votre workspace',
    'Sign-in and account creation are handled by Clerk.':
        'La connexion et la création de compte sont gérées par Clerk.',
    'Reviewed': 'Relu',
    'Reviewed by {reviewer}{typeSuffix}': 'Relu par {reviewer}{typeSuffix}',
    'Reviewer: {reviewer}': 'Reviewer : {reviewer}',
    'Runs': 'Exécutions',
    'SEO': 'SEO',
    'SKIP': 'PASSER',
    'Schedule': 'Planning',
    'Scheduled "{title}" for {date}': '« {title} » planifié pour le {date}',
    'See the workflow before you commit': 'Voir le workflow avant de s’engager',
    'Send': 'Envoyer',
    'Send Feedback': 'Envoyer un feedback',
    'Send product feedback directly from the app. Text and audio feedback are sent to the backend and stay anonymous when no account is connected.':
        'Envoyez un retour produit directement depuis l’app. Les feedbacks texte et audio sont transmis au backend et restent anonymes si aucun compte n’est connecté.',
    'Sending...': 'Envoi...',
    'Sent anonymously': 'Envoyé anonymement',
    'Sent with {account}': 'Envoyé avec {account}',
    'Settings': 'Réglages',
    'Setup': 'Configuration',
    'Share Feedback': 'Partager un feedback',
    'Share text or audio product feedback':
        'Partager un retour produit texte ou audio',
    'Shorts': 'Formats courts',
    'Sign In': 'Se connecter',
    'Sign in to configure Idea Pool':
        'Connectez-vous pour configurer le réservoir d’idées',
    'Sign in to configure content frequency':
        'Connectez-vous pour configurer la fréquence de contenu',
    'Sign in to sync notification preferences':
        'Connectez-vous pour synchroniser les préférences de notification',
    'Sign in with Google': 'Se connecter avec Google',
    'Sign in with Google before creating a workspace.':
        'Connectez-vous avec Google avant de créer un workspace.',
    'Sign out': 'Se déconnecter',
    'Skip': 'Passer',
    'Skipped: {title}': 'Passé : {title}',
    'Social posts': 'Posts réseaux sociaux',
    'Something went wrong': 'Un problème est survenu',
    'Start': 'Démarrer',
    'Step {current}/{total} — {title}': 'Étape {current}/{total} — {title}',
    'Status: {status}': 'Statut : {status}',
    'Stop': 'Arrêter',
    'System': 'Système',
    'Target audience': 'Audience cible',
    'Technical': 'Technique',
    'Templates': 'Modèles',
    'Text': 'Texte',
    'Text Feedback': 'Feedback texte',
    'Text message': 'Message texte',
    'This onboarding uses a fixed public repo and pre-generated content. Users can explore the flow, but the demo data is intentionally read-only.':
        'Cet onboarding utilise un dépôt public fixe et un contenu pré-généré. Les utilisateurs peuvent explorer le flux, mais les données de démo sont volontairement en lecture seule.',
    'Theme': 'Thème',
    'Timeline': 'Chronologie',
    'Tone': 'Ton',
    'Tools': 'Outils',
    'Topics (comma-separated)': 'Sujets (séparés par des virgules)',
    'Total': 'Total',
    'Total Reviewed': 'Total revu',
    'Turn one repo into a weekly content machine.':
        'Transformez un seul dépôt en machine à contenu hebdomadaire.',
    'Uptime': 'Disponibilité',
    'Uploading...': 'Upload...',
    'Use the web sign-in flow': 'Utiliser le flux de connexion web',
    'Welcome back to your content workspace.':
        'Bienvenue dans votre workspace de contenu.',
    'User feedback received by the backend. Real access control still lives server-side.':
        'Retours utilisateurs reçus par le backend. Le contrôle d’accès réel reste côté serveur.',
    'Validations': 'Validations',
    'Video scripts': 'Scripts vidéo',
    'View Idea Pool': 'Voir le réservoir d’idées',
    'Weekly Ritual': 'Rituel hebdomadaire',
    'Discover the screens step by step': 'Découvrir les écrans pas à pas',
    'What content do you want?': 'Quel contenu voulez-vous ?',
    'What is blocking you, missing, or could be improved?':
        'Qu’est-ce qui vous bloque, manque, ou pourrait être amélioré ?',
    'With ContentGlows': 'Avec ContentGlows',
    'Without ContentGlows': 'Sans ContentGlows',
    'Workspace': 'Workspace',
    'Workspace continuation': 'Reprise du workspace',
    '1. Restore or sign in': '1. Restaurer ou se connecter',
    '2. Resolve workspace state': '2. Résoudre l’état du workspace',
    '3. Continue work': '3. Continuer le travail',
    'API and bootstrap failures expose retry, status, reconnect, and diagnostics actions without hiding them lower on the page.':
        'Les erreurs API et bootstrap exposent les actions de relance, statut, reconnexion et diagnostic sans les enfouir plus bas dans la page.',
    'ContentGlows checks Clerk first, then opens the right account path without burying auth below marketing content.':
        'ContentGlows vérifie Clerk en premier, puis ouvre le bon parcours de compte sans enterrer l’authentification sous du contenu marketing.',
    'Dashboard access': 'Accès au dashboard',
    'Google sign-in': 'Connexion Google',
    'Onboarding recovery': 'Reprise de l’onboarding',
    'Recognized users can go straight to the dashboard or continue onboarding from the first viewport.':
        'Les utilisateurs reconnus peuvent aller directement au dashboard ou reprendre l’onboarding dès le premier viewport.',
    'The app decides whether you should enter the dashboard, finish onboarding, retry the API, or refresh your session.':
        'L’app détermine s’il faut ouvrir le dashboard, terminer l’onboarding, relancer l’API ou rafraîchir votre session.',
    'The visible state card tells users whether they are signed out, restoring, active, blocked, or ready.':
        'La carte d’état visible indique si l’utilisateur est déconnecté, en restauration, actif, bloqué ou prêt.',
    'This is an app entry page for existing users. It keeps account, workspace, and recovery actions at the top.':
        'C’est une page d’accueil applicative pour les utilisateurs existants. Elle garde les actions de compte, workspace et récupération en haut.',
    'Use this page to restore your session, open your workspace, finish onboarding, or recover cleanly when the backend is unavailable.':
        'Utilisez cette page pour restaurer votre session, ouvrir votre workspace, finir l’onboarding ou récupérer proprement quand le backend est indisponible.',
    'What happens on this page': 'Ce que fait cette page',
    'backend readiness visible': 'état backend visible',
    'dashboard or onboarding route': 'dashboard ou onboarding',
    'session status first': 'état de session en premier',
    'approved': 'approuvé',
    'completed': 'terminé',
    'editing': 'édition',
    'failed': 'échec',
    'pending': 'en attente',
    'retrying': 'nouvelle tentative',
    'paused_auth': 'auth requise',
    'waiting_dependency': 'dépendance en attente',
    'published': 'publié',
    'rejected': 'rejeté',
    'running': 'en cours',
    'started': 'démarré',
    'your account': 'votre compte',
    'anonymous': 'anonyme',
    'no date': 'sans date',
    'queued': 'en file',
    'unknown': 'inconnu',
    '{channelName} is not supported for direct connection yet':
        '{channelName} n’est pas encore pris en charge pour une connexion directe',
    '{count} articles awaiting validation':
        '{count} articles en attente de validation',
    '{count} contents/week': '{count} contenus/semaine',
    '{total} total · {published} published':
        '{total} au total · {published} publiés',
    'Access State': 'Etat d acces',
    'Action failed: {error}': 'Echec de l action : {error}',
    'Analyze your site against competitors':
        'Analysez votre site face a vos concurrents',
    'Analyzing...': 'Analyse en cours...',
    'Analysis Results': 'Resultats de l analyse',
    'Analysis failed: {error}': 'Echec de l analyse : {error}',
    'API Details': 'Details de l API',
    'API Online': 'API en ligne',
    'API Offline': 'API hors ligne',
    'Articles': 'Articles',
    'Articles/day': 'Articles/jour',
    'Content queued: "{contentType}"': 'Contenu mis en file : "{contentType}"',
    'Drip plan queued. It will sync when FastAPI is back.':
        'Le plan drip a ete mis en file. Il sera synchronise quand FastAPI reviendra.',
    'Pending sync': 'Sync en attente',
    'Sync failed': 'Echec de sync',
    'Retrying sync': 'Nouvelle tentative de sync',
    'Sync paused': 'Sync en pause',
    'Waiting for dependency': 'En attente d\'une dépendance',
    'Pending: {count}': 'En attente : {count}',
    'Paused for auth: {count}': 'En pause pour auth : {count}',
    'Failed: {count}': 'En echec : {count}',
    'Waiting for dependencies: {count}': 'En attente de dependances : {count}',
    '{count} queued actions are waiting for dependency sync.':
        '{count} actions en file attendent la synchronisation d une dependance.',
    'Absolute path to the Markdown files':
        'Chemin absolu vers les fichiers Markdown',
    'Audit Trail': 'Trace d audit',
    'Audit trail copied': 'Trace d audit copiee',
    'Audit trail unavailable: {error}': 'Trace d audit indisponible : {error}',
    'Auto (AI detects semantic cocoons)':
        'Auto (l IA detecte les cocons semantiques)',
    'Backend status check failed': 'La verification du statut backend a echoue',
    'Body edits': 'Modifications du contenu',
    'Back': 'Retour',
    'Both': 'Les deux',
    'By directory structure': 'Par structure de dossiers',
    'By frontmatter tags': 'Par tags de frontmatter',
    'Cadence': 'Cadence',
    'Cancel plan': 'Annuler le plan',
    'Cancel Plan': 'Annuler le plan',
    'Cluster Items': 'Grouper les contenus',
    'Clustered into {count} groups': '{count} groupes crees',
    'Clusters': 'Clusters',
    'Clustering': 'Clustering',
    'Clustering Strategy': 'Strategie de clustering',
    'Comment': 'Commenter',
    'Competitor Analysis': 'Analyse concurrentielle',
    'Competitor URLs (one per line)': 'URLs concurrentes (une par ligne)',
    'Configuration': 'Configuration',
    'Content body...': 'Corps du contenu...',
    'Content directory': 'Dossier de contenu',
    'Content Drip': 'Publication progressive',
    'Content not found': 'Contenu introuvable',
    'ContentGlows system status diagnostics':
        'Diagnostic de l etat systeme de ContentGlows',
    'Could not load full content: {error}':
        'Impossible de charger le contenu complet : {error}',
    'Could not open the editor': 'Impossible d ouvrir l editeur',
    'Could not save changes: {error}':
        'Impossible d enregistrer les modifications : {error}',
    'Copy audit trail': 'Copier la trace d audit',
    'Create a plan to progressively publish your content.\nGoogle will see a natural publishing rhythm.':
        'Creez un plan pour publier progressivement votre contenu.\nGoogle verra un rythme de publication naturel.',
    'Create drip plan': 'Creer un plan progressif',
    'Create Plan': 'Creer le plan',
    'Delete plan': 'Supprimer le plan',
    'Discard': 'Ignorer',
    'Discard changes?': 'Ignorer les modifications ?',
    'Domains are created when robots run on a project':
        'Les domaines sont crees quand des robots tournent sur un projet',
    'Done': 'Fait',
    'Drip plan created! Import content to get started.':
        'Plan progressif cree. Importez du contenu pour commencer.',
    'Draft flag': 'Drapeau brouillon',
    'Each folder becomes a cluster. index.md = pillar.':
        'Chaque dossier devient un cluster. index.md = pilier.',
    'Enabled': 'Active',
    'Error': 'Erreur',
    'Error: {error}': 'Erreur : {error}',
    'Execute Drip Now': 'Executer la publication maintenant',
    'Failed to load drip plan': 'Impossible de charger le plan progressif',
    'Failed to load drip plans': 'Impossible de charger les plans progressifs',
    'Failed to load runs': 'Impossible de charger les executions',
    'Failed to load work domains':
        'Impossible de charger les domaines de travail',
    'First tag = cluster. Most tags = pillar.':
        'Premier tag = cluster. Le plus de tags = pilier.',
    'Fixed': 'Fixe',
    'Framework': 'Framework',
    'Future pubDate (recommended)': 'pubDate future (recommande)',
    'GSC': 'GSC',
    'Gating': 'Controle',
    'Gating method': 'Methode de controle',
    'Generate Schedule': 'Generer le planning',
    'Ghost': 'Ghost',
    'GitHub Actions': 'GitHub Actions',
    'GitHub repo': 'Depot GitHub',
    'HH:MM': 'HH:MM',
    'Import Content': 'Importer le contenu',
    'Imported {count} articles': '{count} articles importes',
    'Instagram': 'Instagram',
    'Keep editing': 'Continuer a modifier',
    'Keywords (comma-separated, optional)':
        'Mots-cles (separes par des virgules, optionnel)',
    'Last': 'Dernier',
    'Last backend message: {message}': 'Dernier message backend : {message}',
    'Last drip': 'Derniere publication',
    'Like': 'J aime',
    'Loading...': 'Chargement...',
    'Loading audit trail...': 'Chargement de la trace d audit...',
    'Manual': 'Manuel',
    'Name & Source': 'Nom et source',
    'Mon': 'Lun',
    'Tue': 'Mar',
    'Wed': 'Mer',
    'Thu': 'Jeu',
    'Fri': 'Ven',
    'Sat': 'Sam',
    'Sun': 'Dim',
    'New Drip Plan — Step {step}/4': 'Nouveau plan progressif — Etape {step}/4',
    'Next': 'Suivant',
    'Next drip': 'Prochaine publication',
    'Next drip: {date}': 'Prochaine publication : {date}',
    'No audit events yet.': 'Aucun evenement d audit pour le moment.',
    'No competitor data returned.': 'Aucune donnee concurrentielle retournee.',
    'No clustering (alphabetical)': 'Aucun clustering (alphabetique)',
    'No drip plans yet': 'Aucun plan progressif pour le moment',
    'No robot runs yet': 'Aucune execution robot pour le moment',
    'No work domains configured': 'Aucun domaine de travail configure',
    'Offline': 'Hors ligne',
    'Online': 'En ligne',
    'Ping again': 'Relancer le ping',
    'Ping History': 'Historique des pings',
    'Plan activated — dripping starts!':
        'Plan active : la publication progressive commence !',
    'Plan cancelled': 'Plan annule',
    'Plan deleted': 'Plan supprime',
    'Plan name': 'Nom du plan',
    'Plan paused': 'Plan en pause',
    'Plan resumed': 'Plan repris',
    'Platform preview': 'Apercu plateforme',
    'Platform Previews': 'Apercus des plateformes',
    'Progress': 'Progression',
    'Publish days': 'Jours de publication',
    'Publish pillar before spokes': 'Publier le pilier avant les satellites',
    'Publish time': 'Heure de publication',
    'Timezone': 'Fuseau horaire',
    'e.g. Europe/Paris': 'ex: Europe/Paris',
    'Spacing (min)': 'Espacement (min)',
    'Intra-day spacing when >1/day': 'Espacement intra-jour si >1/jour',
    'Index-proof (robots noindex until publish)':
        'Index-proof (robots noindex jusqu a publication)',
    'Prevents premature indexing if your site respects frontmatter robots':
        'Evite l indexation prematuree si votre site respecte le frontmatter robots',
    'Safe mode (opt-in required)': 'Mode securise (opt-in requis)',
    'Recommended for mixed sites: only mutate frontmatter when dripManaged: true':
        'Recommande en cas de mix: modifie le frontmatter seulement si dripManaged: true',
    'Advanced': 'Avance',
    'Opt-in frontmatter field': 'Champ frontmatter opt-in',
    'Robots frontmatter field': 'Champ frontmatter robots',
    'Google Search Console (Indexing API)':
        'Google Search Console (Indexing API)',
    'Google Search Console': 'Google Search Console',
    'Search Console': 'Search Console',
    'Search Console property': 'Propriété Search Console',
    'Accessible properties': 'Propriétés accessibles',
    'Refresh properties': 'Actualiser les propriétés',
    'Loading accessible properties...':
        'Chargement des propriétés accessibles...',
    'No accessible Search Console properties returned for this Google account.':
        'Aucune propriété Search Console accessible retournée pour ce compte Google.',
    'Unable to load accessible properties: {error}':
        'Impossible de charger les propriétés accessibles : {error}',
    'Connect Google': 'Connecter Google',
    'Save property': 'Enregistrer la propriété',
    'Connected and valid': 'Connecté et valide',
    'Connected, degraded': 'Connecté, dégradé',
    'Reconnect required': 'Reconnexion requise',
    'Connected, validation pending': 'Connecté, validation en attente',
    'No Google account yet': 'Aucun compte Google pour le moment',
    'No Search Console property selected':
        'Aucune propriété Search Console sélectionnée',
    'Property is matched automatically from the selected project domain':
        'La propriété est rattachée automatiquement depuis le domaine du projet sélectionné',
    'Compatible properties': 'Propriétés compatibles',
    'No compatible Search Console property found for this project domain.':
        'Aucune propriété Search Console compatible trouvée pour le domaine de ce projet.',
    'Search Console property matched.': 'Propriété Search Console rattachée.',
    'SEO Stats': 'Stats SEO',
    'Google Search': 'Recherche Google',
    'Source: Google Search Console': 'Source : Google Search Console',
    'Source: private analytics tracker': 'Source : tracker analytics privé',
    'Organic clicks from Google': 'Clics organiques depuis Google',
    'Impressions': 'Impressions',
    'CTR': 'CTR',
    'Average position': 'Position moyenne',
    'Inspected URLs': 'URLs inspectées',
    'Inspection issues': 'Problèmes Inspection',
    'URL Inspection issues': 'Problèmes URL Inspection',
    'Review': 'Vérifier',
    'Top organic landing pages from Google':
        'Principales pages organiques depuis Google',
    'Top queries': 'Principales requêtes',
    'Site traffic': 'Trafic du site',
    'Site visits/pageviews': 'Visites/pages vues du site',
    'Unique tracked pages': 'Pages suivies distinctes',
    'Most visited pages on site': 'Pages les plus visitées du site',
    'Search Console opportunities': 'Opportunités Search Console',
    'Google evidence': 'Preuve Google',
    'Add to Idea Pool': "Ajouter à l'Idea Pool",
    'Overview': "Vue d'ensemble",
    'Today': "Aujourd'hui",
    'Today is partial': "Aujourd'hui est partiel",
    'Last 7 days': '7 derniers jours',
    'Last 30 days': '30 derniers jours',
    'Last 90 days': '90 derniers jours',
    'Last 6 months': '6 derniers mois',
    'Stale': 'Obsolète',
    'Sync': 'Synchroniser',
    'Content pipeline': 'Pipeline de contenu',
    'Submit URLs after each drip': 'Soumettre les URLs apres chaque drip',
    'GSC site URL': 'URL du site GSC',
    'Submit URLs': 'Soumettre les URLs',
    'Max submissions/day': 'Max soumissions/jour',
    'Run preflight': 'Lancer le preflight',
    'Preflight issues': 'Problemes detectes (preflight)',
    'Preflight: {severity} ({count} issues)':
        'Preflight : {severity} ({count} problemes)',
    'Close': 'Fermer',
    'Published {count} articles': '{count} articles publies',
    'Published {published}/{total} ({percent}%)':
        '{published}/{total} publies ({percent}%)',
    'Ramp up': 'Montee en charge',
    'Rebuild': 'Rebuild',
    'Rebuild method': 'Methode de rebuild',
    'Repost': 'Republier',
    'Resume': 'Reprendre',
    'Retry backend': 'Relancer le backend',
    'Robot Runs': 'Executions des robots',
    'SSG Framework': 'Framework SSG',
    'Save & Publish': 'Enregistrer et publier',
    'Scheduled {count} items': '{count} elements planifies',
    'Site URL and at least one competitor are required':
        'L URL du site et au moins un concurrent sont requis',
    'Start date': 'Date de debut',
    'Status transitions': 'Transitions de statut',
    'Strengths: {list}': 'Forces : {list}',
    'Title': 'Titre',
    'Topical Mesh Architect detects pillars & spokes.':
        'Topical Mesh Architect detecte les piliers et satellites.',
    'Twitter / X': 'Twitter / X',
    'Unknown': 'Inconnu',
    'Unknown action': 'Action inconnue',
    'Weaknesses: {list}': 'Faiblesses : {list}',
    'Webhook (Vercel/Netlify)': 'Webhook (Vercel/Netlify)',
    'Webhook URL': 'URL du webhook',
    'Work Domains': 'Domaines de travail',
    'WordPress': 'WordPress',
    'YYYY-MM-DD': 'AAAA-MM-JJ',
    'You have unsaved edits.': 'Vous avez des modifications non enregistrees.',
    'Analyze your site structure and topical coverage':
        'Analysez la structure de votre site et sa couverture thématique',
    'Author': 'Auteur',
    'Boost': 'Booster',
    'Caption': 'Legende',
    'Calendar — your scheduled posts': 'Calendrier — vos posts planifiés',
    'Check backend health here. If the app enters degraded mode, this screen tells you why and when the service is back.':
        'Vérifiez ici l’état du backend. Si l’app passe en mode dégradé, cet écran vous indique pourquoi et quand le service revient.',
    'Centralize your affiliate links so the AI can insert them intelligently into relevant content. Add a link here once, and it will be suggested automatically whenever the topic fits.':
        'Centralisez vos liens d’affiliation pour que l’IA les insère intelligemment dans les contenus pertinents. Ajoutez un lien une seule fois ici, il sera proposé automatiquement quand le sujet s’y prête.',
    'Configure the topic areas the AI is allowed to work on. This prevents off-topic output and keeps production focused on your real areas of expertise.':
        'Configurez les domaines thématiques sur lesquels l’IA est autorisée à travailler. Cela évite les hors-sujets et garde la production centrée sur vos vraies expertises.',
    'Content Tools — checks and audits':
        'Content Tools — vérifications et audits',
    'Drip orchestrates content sequences over multiple days. Instead of publishing one isolated post, you launch a coherent series, such as a 5-post mini campaign around one topic. Use it for launches or for themes that deserve several angles.':
        'Drip orchestre des séquences de contenu sur plusieurs jours. Au lieu de publier un post isolé, vous lancez une série cohérente, comme une mini-campagne de 5 posts autour d’un même sujet. Utilisez-la pour les lancements ou les thèmes qui méritent plusieurs angles.',
    'Define the personas the AI should address. Each persona influences tone, vocabulary, and angles. Use the + button in the bottom-right corner to add a new persona.':
        'Définissez les personas que l’IA doit adresser. Chaque persona influence le ton, le vocabulaire et les angles. Utilisez le bouton + en bas à droite pour ajouter une nouvelle persona.',
    'Download & Extract': 'Telecharger et extraire',
    'Download Complete': 'Telechargement termine',
    'Download Instagram reels, extract audio, upload to CDN':
        'Telechargez des reels Instagram, extrayez l audio et uploadez-le sur le CDN',
    'Download Reel': 'Telecharger le reel',
    'Download failed: {error}': 'Echec du telechargement : {error}',
    'Drip — automated sequences': 'Drip — séquences automatisées',
    'Dismiss': 'Ignorer',
    'Every AI generation leaves a trace here: which model, which prompt, and how long it took. Check it when a result looks suspicious or when you want to keep an eye on cost.':
        'Chaque génération IA laisse une trace ici : quel modèle, quel prompt et combien de temps cela a pris. Consultez cet écran quand un résultat semble douteux ou pour surveiller les coûts.',
    'Enriched': 'Enrichi',
    'Enter an Instagram Reel URL': 'Entrez une URL de reel Instagram',
    'Feed — your review queue': 'Feed — votre file de validation',
    'Find all published content here, with its status and target platform. This is your archive for checking what has already gone out or reusing a past idea.':
        'Retrouvez ici tous les contenus déjà publiés, avec leur statut et la plateforme cible. C’est votre archive pour vérifier ce qui est déjà parti ou réutiliser une ancienne idée.',
    'Guided app tour': 'Visite guidée de l’app',
    'Guided tour · {current}/{total}': 'Visite guidée · {current}/{total}',
    'History — everything that has been published':
        'Historique — tout ce qui a été publié',
    'Instagram Reel URL': 'URL du reel Instagram',
    'Look for the "Guided app tour" tile to restart the tour.':
        'Cherchez la tuile « Visite guidée de l’app » pour relancer la visite.',
    'Look for the 3 round buttons at the bottom — they are your main actions.':
        'Repérez les 3 boutons ronds en bas — ce sont vos actions principales.',
    'Manage your short-form videos here: reels, shorts, and similar vertical formats. The AI can suggest scripts and structure, and you decide what to edit or approve before publishing. The main Feed still stays central, while Reels is the workshop dedicated to vertical content.':
        'Gérez ici vos vidéos courtes : reels, shorts et autres formats verticaux. L’IA peut proposer des scripts et un découpage, puis vous décidez quoi éditer ou approuver avant publication. Le Feed reste central, tandis que Reels est l’atelier dédié au format vertical.',
    'Lower': 'Baisser',
    'Newsletter — your long-form channel':
        'Newsletter — votre canal long format',
    'No ideas yet': 'Aucune idee pour le moment',
    'No local actions are waiting to sync.':
        'Aucune action locale n’attend de synchronisation.',
    'Next best actions': 'Prochaines meilleures actions',
    'No draft is currently waiting in the review queue. Set your creation rules, generate a first draft, or prepare the upcoming queue.':
        'Aucun brouillon n’attend actuellement dans la file de revue. Définissez vos règles de création, générez un premier brouillon ou préparez la file des prochains contenus.',
    'No templates available': 'Aucun modele disponible',
    'No upcoming content is scheduled yet.':
        'Aucun contenu à venir n’est encore planifié.',
    'Nothing is waiting for approval yet.':
        'Rien n’attend encore votre validation.',
    'Nothing to review yet': 'Rien à valider pour le moment',
    'Open {screen}': 'Ouvrir {screen}',
    'Open drip queue': 'Ouvrir la file drip',
    'Open setup': 'Ouvrir la configuration',
    'Open templates': 'Ouvrir les templates',
    'Open the drip queue to schedule the next content items that should arrive.':
        'Ouvrez la file drip pour planifier les prochains contenus qui doivent arriver.',
    'Pending review': 'En attente de validation',
    'Pause tour': 'Mettre en pause la visite',
    'Performance — detailed metrics': 'Performance — métriques détaillées',
    'Performance complements Analytics with metrics per content item and per channel. Use it when you want to understand why a post worked, or why it did not, and repeat what succeeds.':
        'Performance complète Analytics avec des métriques par contenu et par canal. Utilisez-le quand vous voulez comprendre pourquoi un post a marché, ou non, afin de reproduire ce qui fonctionne.',
    'Personas — your target audiences': 'Personas — vos audiences cibles',
    'Previous': 'Precedent',
    'Raw': 'Brut',
    'Reel ID': 'ID du reel',
    'Reel Repurposing': 'Reutilisation de reel',
    'Reels — short video formats': 'Reels — formats vidéo courts',
    'Repository URL': 'URL du depot',
    'Repository URL is required': 'L URL du depot est requise',
    'Research gathers trending topics, competitor monitoring, and audience questions. This is the screen to check before each planning ritual so you know what to cover this week.':
        'Research collecte les sujets tendance, la veille concurrentielle et les questions de votre audience. C’est l’écran à consulter avant chaque rituel de planification pour savoir quoi traiter cette semaine.',
    'Research — feed your strategy': 'Research — nourrir votre stratégie',
    'Review creation settings': 'Vérifier les réglages de création',
    'Review the structures available for articles, newsletters, videos, and shorts.':
        'Consultez les structures disponibles pour les articles, newsletters, vidéos et formats courts.',
    'Ritual': 'Rituel',
    'Runs — AI job history': 'Runs — historique des jobs IA',
    'SEO Mesh': 'Mesh SEO',
    'SEO — organic visibility': 'SEO — visibilité organique',
    'Settings — personalize everything': 'Paramètres — tout personnaliser',
    'Skip tour': 'Passer la visite',
    'Some local actions are waiting for sync.':
        'Certaines actions locales attendent une synchronisation.',
    'Templates — your reusable formats':
        'Templates — vos modèles réutilisables',
    'Templates are your repeatable content formats: long-form articles, short posts, or sequences. The AI uses them to generate content that matches your style. The more precise your templates are, the closer the output will match your voice.':
        'Les templates sont vos formats récurrents : articles long format, posts courts ou séquences. L’IA s’en sert pour générer un contenu cohérent avec votre style. Plus vos templates sont précis, plus le résultat colle à votre voix.',
    'The drip queue is where your future content schedule will live.':
        'La file drip accueillera votre planning de contenus à venir.',
    'The Newsletter screen groups together newsletter creation, preview, and sending. You can combine several Feed items into one edition. It is ideal for turning a week of production into a single send.':
        'L’écran Newsletter regroupe la création, l’aperçu et l’envoi de vos newsletters. Vous pouvez assembler plusieurs contenus du Feed dans une même édition. C’est idéal pour transformer une semaine de production en un envoi unique.',
    'The calendar shows everything scheduled for publishing. Tap a week at the top to filter the view. It is useful for checking the balance of your schedule and spotting empty or overloaded days.':
        'Le calendrier affiche tout ce qui est programmé pour publication. Touchez une semaine en haut pour filtrer la vue. C’est utile pour vérifier l’équilibre de votre planning et repérer les jours vides ou surchargés.',
    'This is the chronological log of everything happening in your workspace: creations, publications, and errors. It is useful for diagnosis when something does not seem to have worked.':
        'C’est le journal chronologique de tout ce qui se passe dans votre workspace : créations, publications et erreurs. Il est utile pour diagnostiquer ce qui ne semble pas avoir fonctionné.',
    'This is where you review every piece of AI-generated content. You can swipe the card or use the three round buttons at the bottom: the left button skips the item, the middle one opens the editor, and the right one approves or publishes it. The red badge on the Feed icon shows how many items are waiting for review.':
        'C’est ici que vous validez chaque contenu généré par l’IA. Vous pouvez swiper la carte ou utiliser les trois boutons ronds en bas : celui de gauche passe le contenu, celui du milieu ouvre l’éditeur, et celui de droite approuve ou publie. Le badge rouge sur l’icône Feed indique combien de contenus attendent votre revue.',
    'This is your control center for language, generation frequency, publishing channels, notifications, and your weekly ritual. It is also where you will find the guided tour setting if you want to restart or resume this tour later.':
        'C’est votre centre de contrôle pour la langue, la fréquence de génération, les canaux de publication, les notifications et votre rituel hebdomadaire. C’est aussi ici que vous trouverez le réglage de visite guidée si vous voulez la relancer ou la reprendre plus tard.',
    'This is your global dashboard for audience, engagement, and growth. It should be your first weekly stop to see what is working. Start with the broad trends here, then go deeper in Performance.':
        'C’est votre tableau de bord global pour l’audience, l’engagement et la croissance. Cela doit être votre premier arrêt hebdomadaire pour voir ce qui fonctionne. Regardez d’abord les grandes tendances ici, puis creusez dans Performance.',
    'This toolbox checks your content quality before publishing: editorial consistency, funnel audits, and validations. Use it when a draft feels off — the audit often explains why.':
        'Cette boîte à outils vérifie la qualité de vos contenus avant publication : cohérence éditoriale, audit du funnel et validations. Utilisez-la quand un draft semble étrange — l’audit explique souvent pourquoi.',
    'Topical Mesh Analysis': 'Analyse du mesh thematique',
    'Upcoming content queue': 'File des prochains contenus',
    'Use the + button in the bottom-right corner to add a persona.':
        'Utilisez le bouton + en bas à droite pour ajouter une persona.',
    'Use this screen for SEO analysis and keyword opportunities. Before launching a Drip series or a long-form article, come here to align your angles with the searches that matter.':
        'Utilisez cet écran pour l’analyse SEO et les opportunités de mots-clés. Avant de lancer une série Drip ou un article long format, passez ici pour aligner vos angles avec les recherches qui comptent.',
    'Video': 'Video',
    'We will take a quick tour of the app, screen by screen. The goal is to show you the best order to use each page, what the main controls do, and how to get the most out of the platform. You can pause at any time and resume later from Settings.':
        'On va faire un tour rapide de l’app, écran par écran. L’objectif est de vous montrer dans quel ordre utiliser les pages, à quoi servent les contrôles principaux et comment tirer le meilleur de la plateforme. Vous pouvez mettre en pause à tout moment et reprendre plus tard depuis Réglages.',
    'Welcome to ContentGlows': 'Bienvenue dans ContentGlows',
    'Work domains': 'Domaines de travail',
    'Workspace status': 'État du workspace',
    'Published content': 'Contenu publié',
    'Queued actions': 'Actions en file',
    'Drip plans': 'Plans drip',
    '{count} plan(s)': '{count} plan(s)',
    'Your content machine is ready to be configured.':
        'Votre machine de contenu est prête à être configurée.',
    'Your future content queue is ready to inspect.':
        'Votre file de contenus à venir est prête à être consultée.',
    'Your published history will appear here after the first release.':
        'Votre historique publié apparaîtra ici après la première mise en ligne.',
    'Generate angles and turn one of them into a draft ready for review.':
        'Générez des angles puis transformez-en un en brouillon prêt à être validé.',
    'You are ready!': 'Vous êtes prêt !',
    'You already have published content in history.':
        'Vous avez déjà du contenu publié dans l’historique.',
    'You have seen the essentials. A few reminders to get started well: 1) configure your personas and weekly ritual in Settings, 2) let the AI generate, then review items in the Feed, 3) track the impact in Analytics. To relaunch this tour, open Settings and use the guided app tour option.':
        'Vous avez vu l’essentiel. Quelques rappels pour bien démarrer : 1) configurez vos personas et votre rituel hebdomadaire dans Réglages, 2) laissez l’IA générer, puis validez les contenus dans le Feed, 3) suivez l’impact dans Analytics. Pour relancer cette visite, ouvrez Réglages et utilisez l’option de visite guidée.',
    'YouTube': 'YouTube',
    'Your Headline': 'Votre accroche',
    'Your Name': 'Votre nom',
    'Your site URL': 'URL de votre site',
    'Activity — system timeline': 'Activité — timeline système',
    'Affiliations — your monetized links': 'Affiliations — vos liens monétisés',
    'All sources': 'Toutes les sources',
    'Analytics — measure impact': 'Analytics — mesurer l’impact',
    'Delete idea?': 'Supprimer l idee ?',
    'Ideas from newsletters, SEO, competitors\nand social listening will appear here.':
        'Les idees issues des newsletters, du SEO, des concurrents\net de l ecoute sociale apparaitront ici.',
    'Remove "{title}"? This cannot be undone.':
        'Supprimer « {title} » ? Cette action est irreversible.',
    'Tips': 'Conseils',
    'Unnamed': 'Sans nom',
    'Used': 'Utilise',
    'Uptime — technical status': 'Uptime — état technique',
    '1. Set up your brand voice (weekly ritual)\n2. Create a customer persona\n3. Content starts flowing!':
        '1. Definissez votre voix de marque (rituel hebdomadaire)\n2. Creez un persona client\n3. Le contenu commence a circuler !',
    '25-40': '25-40',
    '3-8 years': '3-8 ans',
    '5% or 10/sale': '5 % ou 10/vente',
    'A browser window has opened for you to authorize {channelName}.\n\nOnce done, tap "Refresh" to see your connected account.':
        'Une fenetre de navigateur s est ouverte pour autoriser {channelName}.\n\nUne fois termine, touchez « Rafraichir » pour voir votre compte connecte.',
    'AI uses these to match content topics':
        'L IA s en sert pour faire correspondre les sujets de contenu',
    'Activate Plan': 'Activer le plan',
    'Active': 'Actif',
    'Add': 'Ajouter',
    'Add first link': 'Ajouter le premier lien',
    'Age range': 'Tranche d age',
    'Amazon Associates': 'Amazon Associates',
    'Analyze Mesh': 'Analyser le mesh',
    'Any new ideas? Content topics, product features, collaborations?':
        'De nouvelles idees ? Sujets de contenu, fonctionnalites produit, collaborations ?',
    'Are you reconsidering something? A strategy shift, a new angle?':
        'Reconsiderez-vous quelque chose ? Un changement de strategie, un nouvel angle ?',
    'Articles published in file order.':
        'Articles publies dans l ordre des fichiers.',
    'Aspirations and desired outcomes': 'Aspirations et resultats souhaites',
    'Brief description of the program...': 'Breve description du programme...',
    'Clerk is connected, but workspace bootstrap failed. ContentGlows stays in degraded mode until FastAPI returns a usable bootstrap.':
        'Clerk est connecte, mais l initialisation du workspace a echoue. ContentGlows reste en mode degrade jusqu a ce que FastAPI retourne un bootstrap exploitable.',
    'Commission': 'Commission',
    'Common pushbacks or doubts this persona has':
        'Objections ou doutes frequents de ce persona',
    'Complete your weekly ritual for better angles':
        'Completez votre rituel hebdomadaire pour de meilleurs angles',
    'Contact URL': 'URL de contact',
    'Content created: "{contentType}"': 'Contenu cree : « {contentType} »',
    'Content generation in progress: "{contentType}"':
        'Generation de contenu en cours : « {contentType} »',
    'ContentGlows analyzes your product, generates angles and drafts, then lets you approve, edit, schedule, and publish from one workflow instead of juggling prompts, docs, and social tools.':
        'ContentGlows analyse votre produit, genere des angles et des brouillons, puis vous permet d approuver, editer, planifier et publier depuis un seul workflow au lieu de jongler avec prompts, docs et outils sociaux.',
    'ContentGlows is running in degraded mode while backend access is limited.':
        'ContentGlows fonctionne en mode degrade tant que l acces au backend est limite.',
    'ContentGlows web authentication now uses the official Clerk JavaScript SDK directly on the app domain. The old site handoff and the Flutter beta SDK are no longer the primary path.':
        'L authentification web de ContentGlows utilise maintenant le SDK JavaScript officiel de Clerk directement sur le domaine de l app. L ancien handoff via le site et le SDK Flutter beta ne sont plus le chemin principal.',
    'Create Persona': 'Creer un persona',
    'Create a customer persona to help\nthe AI generate targeted content':
        'Creez un persona client pour aider\nl IA a generer un contenu cible',
    'Create a persona first': 'Creez d abord un persona',
    'Creating...': 'Creation...',
    'Deep, real problems — not surface-level symptoms':
        'Problemes profonds et reels — pas des symptomes de surface',
    'Delete affiliate link?': 'Supprimer le lien d affiliation ?',
    'Deleted "{name}"': '« {name} » supprime',
    'Demographics': 'Demographie',
    'Deployment': 'Deploiement',
    'Description': 'Description',
    'Downloading...': 'Telechargement...',
    'Duration': 'Duree',
    'Edit Affiliate Link': 'Modifier le lien d affiliation',
    'Edit Entries': 'Modifier les entrees',
    'Edit Persona': 'Modifier le persona',
    'Email: {email}': 'Email : {email}',
    'Experience level': 'Niveau d experience',
    'Expired': 'Expire',
    'Expires': 'Expire le',
    'Failed to create content. Check backend connection.':
        'Impossible de creer le contenu. Verifiez la connexion backend.',
    'Failed to delete: {error}': 'Suppression impossible : {error}',
    'Failed to load affiliations': 'Impossible de charger les affiliations',
    'Failed to load ideas': 'Impossible de charger les idees',
    'Failed to load personas': 'Impossible de charger les personas',
    'Failed to load templates': 'Impossible de charger les modeles',
    'Failed to save persona: {error}':
        'Impossible d enregistrer le persona : {error}',
    'Failed to save: {error}': 'Impossible d enregistrer : {error}',
    'Fill at least {count}': 'Remplissez au moins {count}',
    'Generate Content': 'Generer du contenu',
    'Goal': 'Objectif',
    'Goals (min. 2)': 'Objectifs (min. 2)',
    'Idea': 'Idee',
    'Identity': 'Identite',
    'Indie developers building SaaS products':
        'Developpeurs indies qui construisent des produits SaaS',
    'Industry': 'Secteur',
    'Issue': 'Probleme',
    'KD {score}': 'KD {score}',
    'Keywords (comma-separated)': 'Mots-cles (separes par des virgules)',
    'LinkedIn': 'LinkedIn',
    'Login URL': 'URL de connexion',
    'Name *': 'Nom *',
    'Narrative Summary': 'Resume narratif',
    'Narrative loaded': 'Narratif charge',
    'Narrative synthesis failed: {error}':
        'La synthese narrative a echoue : {error}',
    'Narrative validated and saved!': 'Narratif valide et enregistre !',
    'New Affiliate Link': 'Nouveau lien d affiliation',
    'New Chapter Detected': 'Nouveau chapitre detecte',
    'New Persona': 'Nouveau persona',
    'No affiliate links match this filter':
        'Aucun lien d affiliation ne correspond a ce filtre',
    'No affiliate links yet': 'Aucun lien d affiliation pour le moment',
    'No angles available': 'Aucun angle disponible',
    'No date': 'Pas de date',
    'No personas yet': 'Aucun persona pour le moment',
    'No role defined': 'Aucun role defini',
    'Notes for AI': 'Notes pour l IA',
    'Objection': 'Objection',
    'Objections': 'Objections',
    'Once Clerk ships a stable Flutter SDK, the archived beta branch can be revisited. Until then, production auth stays on the official ClerkJS web path.':
        'Quand Clerk proposera un SDK Flutter stable, la branche beta archivee pourra etre reexaminee. D ici la, l auth de production reste sur le chemin web officiel ClerkJS.',
    'Pages': 'Pages',
    'Pain Points (min. 2)': 'Pain points (min. 2)',
    'Pain point': 'Pain point',
    'Paused': 'En pause',
    'Persona "{name}" saved': 'Persona « {name} » enregistre',
    'Persona name': 'Nom du persona',
    'Pick an angle to generate content':
        'Choisissez un angle pour generer du contenu',
    'Pivot': 'Pivot',
    'Please enter a persona name': 'Veuillez entrer un nom de persona',
    'Positioning Shift': 'Changement de positionnement',
    'Preview': 'Apercu',
    'Recommendation': 'Recommandation',
    'Recommendations': 'Recommandations',
    'Reels': 'Reels',
    'Reflection': 'Reflexion',
    'Remove "{name}"? This cannot be undone.':
        'Supprimer « {name} » ? Cette action est irreversible.',
    'Required': 'Requis',
    'Role': 'Role',
    'SaaS, E-commerce...': 'SaaS, e-commerce...',
    'Save': 'Enregistrer',
    'Score': 'Score',
    'Score {score}': 'Score {score}',
    'Select a persona above to generate angles':
        'Selectionnez un persona ci-dessus pour generer des angles',
    'Session: {state}': 'Session : {state}',
    'Set `CLERK_PUBLISHABLE_KEY` with `--dart-define` to enable the production ClerkJS sign-in flow on the app domain.':
        'Definissez `CLERK_PUBLISHABLE_KEY` avec `--dart-define` pour activer le flux de connexion ClerkJS de production sur le domaine de l app.',
    'Stage: {stage}': 'Etape : {stage}',
    'Status': 'Statut',
    'Struggle': 'Difficulte',
    'Synthesize Narrative': 'Synthese narrative',
    'The Clerk Flutter beta SDK has been removed from the production path. For now, sign in through the dedicated web Google flow instead of the old embedded Flutter flow.':
        'Le SDK Flutter beta de Clerk a ete retire du chemin de production. Pour l instant, connectez-vous via le flux web Google dedie au lieu de l ancien flux Flutter embarque.',
    'This will approve and publish {count} content item(s).':
        'Cela va approuver et publier {count} contenu(s).',
    'This will remove the connection to {displayName}.':
        'Cela supprimera la connexion a {displayName}.',
    'TikTok': 'TikTok',
    'Try refreshing or complete your weekly ritual':
        'Essayez de rafraichir ou completez votre rituel hebdomadaire',
    'URL *': 'URL *',
    'Untitled': 'Sans titre',
    'Update': 'Mettre a jour',
    'Validate & Save': 'Valider et enregistrer',
    'Vocabulary': 'Vocabulaire',
    'Voice Evolution': 'Evolution de la voix',
    'Weekly Tech Digest #43': 'Digest tech hebdo #43',
    'What have you been thinking about this week regarding your work, your audience, your direction?':
        'A quoi avez-vous pense cette semaine concernant votre travail, votre audience, votre direction ?',
    'What was difficult? A blocker, a doubt, a frustration?':
        'Qu est-ce qui a ete difficile ? Un blocage, un doute, une frustration ?',
    'What went well? A milestone, a positive reaction, a breakthrough?':
        'Qu est-ce qui s est bien passe ? Une etape cle, une reaction positive, une percee ?',
    'When and how to use this link...': 'Quand et comment utiliser ce lien...',
    'Win': 'Succes',
    'Word or phrase': 'Mot ou expression',
    'Words and expressions this persona actually uses':
        'Mots et expressions que ce persona utilise vraiment',
    'e.g. GoCharbon Launch': 'ex. Lancement GoCharbon',
    'e.g. Indie developer, CTO, Content creator':
        'ex. Developpeur indie, CTO, createur de contenu',
    'e.g. Tech-Savvy Solopreneur': 'ex. Solopreneur techno averti',
    'e.g. src/data': 'ex. src/data',
    'hosting, wordpress, website': 'hosting, wordpress, site web',
    'https://affiliate.example.com/ref=123':
        'https://affiliate.example.com/ref=123',
    'https://api.vercel.com/v1/integrations/deploy/...':
        'https://api.vercel.com/v1/integrations/deploy/...',
    'https://competitor1.com\nhttps://competitor2.com':
        'https://competitor1.com\nhttps://competitor2.com',
    'https://github.com/user/site': 'https://github.com/user/site',
    'https://yoursite.com': 'https://yoursite.com',
    'saas, flutter, ai': 'saas, flutter, ia',
    '{status}: {count}': '{status} : {count}',
    '{volume} vol': '{volume} vol',
    'https://github.com/user/repo': 'https://github.com/user/repo',
    'https://www.instagram.com/reel/...': 'https://www.instagram.com/reel/...',
    '{count} sections': '{count} sections',
    'active': 'actif',
    'articles': 'articles',
    'auto': 'auto',
    'cancelled': 'annule',
    'day': 'jour',
    'directory': 'dossier',
    'draft': 'brouillon',
    'edits': 'modifications',
    'future_date': 'date future',
    'github_actions': 'github actions',
    'loading': 'chargement',
    'manual': 'manuel',
    'none': 'aucun',
    'owner/repo': 'owner/repo',
    'paused': 'en pause',
    'success': 'succes',
    'tags': 'tags',
    'transitions': 'transitions',
    'Parcourir l\'arborescence du dépôt pour choisir un dossier':
        'Parcourir l\'arborescence du dépôt pour choisir un dossier',
    'Parcourir les dossiers': 'Parcourir les dossiers',
    'Chemin sélectionné': 'Chemin sélectionné',
    'Choisir le dossier de contenu': 'Choisir le dossier de contenu',
    'Choisir ce dossier': 'Choisir ce dossier',
    'Remonter d\'un niveau': 'Remonter d\'un niveau',
    'Unable to load content tree':
        'Impossible de charger l’arborescence du dépôt',
    'Aucun dossier détecté à cet emplacement':
        'Aucun dossier détecté à cet emplacement',
    'Aucun fichier markdown trouvé': 'Aucun fichier markdown trouvé',
    'Contient des fichiers markdown': 'Contient des fichiers markdown',
    'webhook': 'webhook',
    'yourhandle': 'votrecompte',
    'A browser opened for authorization. Once you finish, return here and tap Refresh.':
        'Une fenêtre de navigateur s’est ouverte pour l’autorisation. Une fois terminé, revenez ici puis appuyez sur Actualiser.',
    'A browser opened for authorization. Once Google returns, come back here and refresh the status.':
        'Une fenêtre de navigateur s’est ouverte pour l’autorisation. Quand Google a terminé, reviens ici puis actualise l’état.',
    'AI runtime mode updated to {mode}.':
        'Le mode d’exécution IA a été mis à jour vers {mode}.',
    'AI runtime, API keys, GitHub and publishing destinations live here.':
        'Le runtime IA, les clés API, GitHub et les destinations de publication se gèrent ici.',
    'Action needed': 'Action requise',
    'Actualiser': 'Actualiser',
    'Add an optional source URL (GitHub or public website). You can continue with just a project name.':
        'Ajoutez une URL source optionnelle (GitHub ou site public). Vous pouvez continuer avec seulement un nom de projet.',
    'Add at least one keyword before running research.':
        'Ajoutez au moins un mot-clé avant de lancer la recherche.',
    'Affected views: {views}': 'Vues impactées : {views}',
    'All set': 'Tout est prêt',
    'Angle generation failed: {error}':
        'La génération d’angles a échoué : {error}',
    'Annuler': 'Annuler',
    'Apply': 'Appliquer',
    'Après chaque exécution du drip, Drip peut notifier Google (Indexing API) pour accélérer la découverte des pages déjà publiées. C’est une notification de "mise à jour", pas une garantie d’indexation instantanée.':
        'Après chaque exécution du drip, Drip peut notifier Google (Indexing API) pour accélérer la découverte des pages déjà publiées. C’est une notification de "mise à jour", pas une garantie d’indexation instantanée.',
    'Aucun dépôt trouvé pour ce compte.': 'Aucun dépôt trouvé pour ce compte.',
    'Aucune description': 'Aucune description',
    'Auto (détection sémantique des cocons)':
        'Auto (détection sémantique des cocons)',
    'BYOK': 'BYOK',
    'BYOK configured': 'BYOK configuré',
    'BYOK missing': 'BYOK manquant',
    'Cached data is currently being used.':
        'Des données en cache sont actuellement utilisées.',
    'Cannot open URL: invalid format.':
        'Impossible d’ouvrir l’URL : format invalide.',
    'Champ front matter utilisé pour appliquer/retirer le noindex tant que le contenu n’est pas réellement publié.':
        'Champ front matter utilisé pour appliquer/retirer le noindex tant que le contenu n’est pas réellement publié.',
    'Champ lu quand le mode sécurisé est actif. Seuls les fichiers qui possèdent ce champ peuvent être modifiés par le drip.':
        'Champ lu quand le mode sécurisé est actif. Seuls les fichiers qui possèdent ce champ peuvent être modifiés par le drip.',
    'Checking GitHub integration...': 'Vérification de l’intégration GitHub...',
    'Checking access...': 'Vérification de l’accès...',
    'Choisir un dépôt GitHub': 'Choisir un dépôt GitHub',
    'Choisissez un dépôt GitHub': 'Choisissez un dépôt GitHub',
    'Choose GitHub repository': 'Choisir un dépôt GitHub',
    'Choose a daily time window. Publishing will be random inside this window.':
        'Choisissez une plage horaire quotidienne. La publication sera aléatoire dans cette plage.',
    'Choose from connected GitHub repos':
        'Choisir parmi les dépôts GitHub connectés',
    'Choose from connected GitHub repos (optional)':
        'Choisir parmi les dépôts GitHub connectés (optionnel)',
    'Connect GitHub': 'Connecter GitHub',
    'Connect your stack': 'Connectez votre stack',
    'Connected as {email}': 'Connecté en tant que {email}',
    'Connected as {username}': 'Connecté en tant que {username}',
    'Connected with an active Clerk session':
        'Connecté avec une session Clerk active',
    'Connecter GitHub': 'Connecter GitHub',
    'Connectez votre compte GitHub pour sélectionner un dépôt public ou privé.':
        'Connectez votre compte GitHub pour sélectionner un dépôt public ou privé.',
    'Connectez votre compte GitHub pour sélectionner un dépôt.':
        'Connectez votre compte GitHub pour sélectionner un dépôt.',
    'Connexion GitHub': 'Connexion GitHub',
    'Content generation failed: {error}':
        'Échec de génération de contenu : {error}',
    'Content generation route unavailable on this backend. Update the backend and retry.':
        'La route de génération de contenu est indisponible sur ce backend. Mettez le backend à jour puis réessayez.',
    'Copy': 'Copier',
    'Copy access diagnostics': 'Copier le diagnostic d’accès',
    'Could not open browser for GitHub authorization':
        'Impossible d’ouvrir le navigateur pour l’autorisation GitHub',
    'Could not open link in browser.':
        'Impossible d’ouvrir le lien dans le navigateur.',
    'Could not switch project: {error}':
        'Impossible de changer de projet : {error}',
    'Current project has no repository URL. Set it first in project settings.':
        'Le projet actuel n’a pas d’URL de dépôt. Définissez-la d’abord dans les paramètres du projet.',
    'Date de publication future (recommandé)':
        'Date de publication future (recommandé)',
    'Degraded mode is active. The app stays available, cached data may be stale, and queued actions will replay when FastAPI recovers.':
        'Le mode dégradé est actif. L’app reste disponible, les données en cache peuvent être obsolètes, et les actions en file seront rejouées quand FastAPI sera rétabli.',
    'Delete OpenRouter key?': 'Supprimer la clé OpenRouter ?',
    'Demo mode': 'Mode démo',
    'Disconnect GitHub': 'Déconnecter GitHub',
    'Disconnect GitHub?': 'Déconnecter GitHub ?',
    'Drapeau draft': 'Drapeau draft',
    'Déploiement': 'Déploiement',
    'Enter an OpenRouter API key first.':
        'Saisissez d’abord une clé API OpenRouter.',
    'Failed to delete OpenRouter key: {error}':
        'Impossible de supprimer la clé OpenRouter : {error}',
    'Failed to disconnect GitHub.': 'Impossible de déconnecter GitHub.',
    'Failed to prefill persona with AI: {error}':
        'Impossible de préremplir le persona avec l’IA : {error}',
    'Persona generation is temporarily unavailable because the server could not save the AI job. Retry in a few minutes, or copy diagnostics if it keeps failing.':
        'La génération du persona est temporairement indisponible : le serveur n’a pas pu sauvegarder le job IA. Réessaie dans quelques minutes ou copie le diagnostic si ça continue.',
    'Failed to save OpenRouter key: {error}':
        'Impossible d’enregistrer la clé OpenRouter : {error}',
    'Failed to update AI runtime mode.':
        'Impossible de mettre à jour le mode d’exécution IA.',
    'Failed to validate OpenRouter key: {error}':
        'Impossible de valider la clé OpenRouter : {error}',
    'Fermer': 'Fermer',
    'Framework SSG': 'Framework SSG',
    'From (HH:MM)': 'De (HH:MM)',
    'Get a key': 'Obtenir une clé',
    'GitHub Actions lance un workflow `daily-drip.yml` via `workflow_dispatch` (branche main par défaut). Requiert `GITHUB_TOKEN` côté backend/API pour l’authentification.':
        'GitHub Actions lance un workflow `daily-drip.yml` via `workflow_dispatch` (branche main par défaut). Requiert `GITHUB_TOKEN` côté backend/API pour l’authentification.',
    'GitHub OAuth is unavailable. Check backend configuration.':
        'OAuth GitHub est indisponible. Vérifiez la configuration backend.',
    'GitHub OAuth is unavailable: {error}':
        'OAuth GitHub est indisponible : {error}',
    'GitHub connection': 'Connexion GitHub',
    'GitHub disconnected.': 'GitHub déconnecté.',
    'Granted scopes: {scope}': 'Scopes accordés : {scope}',
    'Hide key': 'Masquer la clé',
    'Impossible d’ouvrir le navigateur pour l’autorisation GitHub.':
        'Impossible d’ouvrir le navigateur pour l’autorisation GitHub.',
    'Index-proof': 'Preuve d’indexation',
    'Integrations': 'Intégrations',
    'La logique backend soumet les URL via l’API d’indexation Google et vérifie ensuite l’état en mode inspection si disponible. La limite par défaut est de 200 URLs/jour, cohérente avec le comportement courant de l’API, et dépend du quota réel de votre projet Google.':
        'La logique backend soumet les URL via l’API d’indexation Google et vérifie ensuite l’état en mode inspection si disponible. La limite par défaut est de 200 URLs/jour, cohérente avec le comportement courant de l’API, et dépend du quota réel de votre projet Google.',
    'Le clustering est la logique de groupement thématique qui décide de l’ordre d’apparition des articles.':
        'Le clustering est la logique de groupement thématique qui décide de l’ordre d’apparition des articles.',
    'Le clustering par dossier exploite la structure du dépôt (`/blog`, `/blog/seo`, `/newsletter`).':
        'Le clustering par dossier exploite la structure du dépôt (`/blog`, `/blog/seo`, `/newsletter`).',
    'Le clustering par tags lit les métadonnées `front matter` et regroupe les contenus qui partagent des sujets similaires.':
        'Le clustering par tags lit les métadonnées `front matter` et regroupe les contenus qui partagent des sujets similaires.',
    'Le mode Auto reconstruit les cocons automatiquement à partir des similarités sémantiques du corpus.':
        'Le mode Auto reconstruit les cocons automatiquement à partir des similarités sémantiques du corpus.',
    'Le mode “Sans clustering” ne force aucun regroupement éditorial.':
        'Le mode “Sans clustering” ne force aucun regroupement éditorial.',
    'Le webhook notifie votre pipeline CI/CD à chaque exécution Drip.':
        'Le webhook notifie votre pipeline CI/CD à chaque exécution Drip.',
    'Le “pilier” est l’article central d’un thème ; les “satellites” sont les contenus qui l’approfondissent.':
        'Le “pilier” est l’article central d’un thème ; les “satellites” sont les contenus qui l’approfondissent.',
    'Les deux': 'Les deux',
    'Loading AI runtime settings...':
        'Chargement des paramètres du runtime IA...',
    'Loading OpenRouter credential status...':
        'Chargement de l’état des identifiants OpenRouter...',
    'L’authentification GitHub est indisponible : {error}':
        'L’authentification GitHub est indisponible : {error}',
    'L’authentification GitHub n’est pas disponible. Vérifiez la configuration backend.':
        'L’authentification GitHub n’est pas disponible. Vérifiez la configuration backend.',
    'Manuel': 'Manuel',
    'Met automatiquement un marqueur noindex dans le front matter tant que le contenu n’est pas publié. Ce mode limite fortement l’indexation prématurée, mais n’est pas une garantie absolue : c’est efficace si votre stack (build, CDN, headers, robots/meta) applique bien ce signal au crawl.':
        'Met automatiquement un marqueur noindex dans le front matter tant que le contenu n’est pas publié. Ce mode limite fortement l’indexation prématurée, mais n’est pas une garantie absolue : c’est efficace si votre stack (build, CDN, headers, robots/meta) applique bien ce signal au crawl.',
    'Missing server dependencies: {items}':
        'Dépendances serveur manquantes : {items}',
    'Mode manuel = aucun déclenchement automatique.':
        'Mode manuel = aucun déclenchement automatique.',
    'Mode sécurisé (opt-in requis)': 'Mode sécurisé (opt-in requis)',
    'Méthode combinée : Drip applique à la fois la date future et `draft: true`, puis lève les deux en même temps.':
        'Méthode combinée : Drip applique à la fois la date future et `draft: true`, puis lève les deux en même temps.',
    'Méthode de contrôle': 'Méthode de contrôle',
    'Méthode de contrôle par date : le front matter reçoit une date de publication future.':
        'Méthode de contrôle par date : le front matter reçoit une date de publication future.',
    'Méthode de contrôle par flag : le front matter est écrit avec `draft: true` (ou équivalent) avant publication.':
        'Méthode de contrôle par flag : le front matter est écrit avec `draft: true` (ou équivalent) avant publication.',
    'Méthode de rebuild': 'Méthode de rebuild',
    'Newsletter server tools are not fully configured':
        'Les outils serveur newsletter ne sont pas entièrement configurés',
    'No OpenRouter key configured': 'Aucune clé OpenRouter configurée',
    'No active project selected.': 'Aucun projet actif sélectionné.',
    'No description': 'Aucune description',
    'No repository found for this account.':
        'Aucun dépôt trouvé pour ce compte.',
    'Not connected': 'Non connecté',
    'Objectif éditorial : publier les contenus dans une séquence qui fait sens (des concepts larges vers les déclinaisons), pour réduire la dispersion et faciliter la lecture continue.':
        'Objectif éditorial : publier les contenus dans une séquence qui fait sens (des concepts larges vers les déclinaisons), pour réduire la dispersion et faciliter la lecture continue.',
    'Offline Sync': 'Sync hors ligne',
    'Open AI runtime endpoint': 'Ouvrir l’endpoint runtime IA',
    'Open GitHub status endpoint': 'Ouvrir l’endpoint de statut GitHub',
    'Open OpenRouter endpoint': 'Ouvrir l’endpoint OpenRouter',
    'OpenRouter API key': 'Clé API OpenRouter',
    'OpenRouter key deleted.': 'Clé OpenRouter supprimée.',
    'OpenRouter key is invalid': 'La clé OpenRouter est invalide',
    'OpenRouter key is missing': 'La clé OpenRouter est manquante',
    'OpenRouter key is valid': 'La clé OpenRouter est valide',
    'OpenRouter key required in Settings > OpenRouter':
        'Clé OpenRouter requise dans Réglages > OpenRouter',
    'OpenRouter key required. Go to Settings > OpenRouter, save + validate your key, then retry.':
        'Clé OpenRouter requise. Allez dans Réglages > OpenRouter, enregistrez et validez votre clé, puis réessayez.',
    'OpenRouter key saved, not validated yet':
        'Clé OpenRouter enregistrée, pas encore validée',
    'OpenRouter key saved: {key}': 'Clé OpenRouter enregistrée : {key}',
    'Options avancées': 'Options avancées',
    'Par structure de dossier': 'Par structure de dossier',
    'Par tag de front matter': 'Par tag de front matter',
    'Paste a new key to replace the current one.':
        'Collez une nouvelle clé pour remplacer l’actuelle.',
    'Persona draft generated and pre-filled.':
        'Brouillon de persona généré et prérempli.',
    'Platform': 'Plateforme',
    'Platform configured (locked)': 'Plateforme configurée (verrouillée)',
    'Platform missing': 'Plateforme manquante',
    'Platform ready': 'Plateforme prête',
    'Prefill with AI': 'Préremplir avec l’IA',
    'Protection indexation précoce (noindex jusqu’à publication)':
        'Protection indexation précoce (noindex jusqu’à publication)',
    'Publier le pilier avant les satellites':
        'Publier le pilier avant les satellites',
    'Queue status unavailable': 'État de la file indisponible',
    'Queued Actions': 'Actions en file',
    'Queued actions are paused until you sign in again.':
        'Les actions en file sont en pause jusqu’à votre reconnexion.',
    'Queued actions are replaying in the background.':
        'Les actions en file sont rejouées en arrière-plan.',
    'Random publish time': 'Heure de publication aléatoire',
    'Recommandé si votre repository mélange du contenu Drip et du contenu éditorial indépendant. Quand ce mode est actif, on ne modifie le front matter que pour les fichiers qui portent explicitement le champ d’opt-in (ex: dripManaged: true), évitant de toucher aux pages non Drip.':
        'Recommandé si votre repository mélange du contenu Drip et du contenu éditorial indépendant. Quand ce mode est actif, on ne modifie le front matter que pour les fichiers qui portent explicitement le champ d’opt-in (ex: dripManaged: true), évitant de toucher aux pages non Drip.',
    'Refresh queue': 'Actualiser la file',
    'Refresh stale data': 'Actualiser les données obsolètes',
    'Retry now': 'Réessayer maintenant',
    'Retry queued actions': 'Réessayer les actions en file',
    'Référentiel GitHub': 'Référentiel GitHub',
    'Safe mode': 'Mode sécurisé',
    'Sans clustering (ordre alphabétique)':
        'Sans clustering (ordre alphabétique)',
    'Save and validate your OpenRouter key in Settings before generating newsletters.':
        'Enregistrez et validez votre clé OpenRouter dans Réglages avant de générer des newsletters.',
    'Save key': 'Enregistrer la clé',
    'Show key': 'Afficher la clé',
    'Sign in': 'Se connecter',
    'Sign in to manage AI runtime mode and provider states.':
        'Connectez-vous pour gérer le mode d’exécution IA et l’état des fournisseurs.',
    'Sign in to manage your OpenRouter key':
        'Connectez-vous pour gérer votre clé OpenRouter',
    'Sign in to sync projects, GitHub connections, and settings.':
        'Connectez-vous pour synchroniser les projets, les connexions GitHub et les réglages.',
    'Signed out': 'Déconnecté',
    'Some newsletter dependencies are still missing.':
        'Certaines dépendances newsletter sont encore manquantes.',
    'Some screens are using cached data and may be stale.':
        'Certains écrans utilisent des données en cache et peuvent être obsolètes.',
    'Stay': 'Rester',
    'Soumettre les URL': 'Soumettre les URL',
    'Soumissions max / jour': 'Soumissions max / jour',
    'Stored key: {key}': 'Clé enregistrée : {key}',
    'Stratégie de clustering': 'Stratégie de clustering',
    'Suggestions depuis le projet actif': 'Suggestions depuis le projet actif',
    'Tap Connect to authorize': 'Appuyez sur Connecter pour autoriser',
    'This removes your GitHub connection and hides private repository data from the picker.':
        'Cette action supprime votre connexion GitHub et masque les données des dépôts privés dans le sélecteur.',
    'This removes your stored OpenRouter credential and disables AI features across the app until you add a new one.':
        'Cette action supprime vos identifiants OpenRouter enregistrés et désactive les fonctionnalités IA dans l’app jusqu’à l’ajout d’une nouvelle clé.',
    'To (HH:MM)': 'À (HH:MM)',
    'Try reconnecting': 'Essayez de vous reconnecter',
    'URL de la propriété GSC': 'URL de la propriété GSC',
    'URL du webhook': 'URL du webhook',
    'Unable to load AI runtime settings.':
        'Impossible de charger les paramètres du runtime IA.',
    'Unable to load GitHub integration state.':
        'Impossible de charger l’état de l’intégration GitHub.',
    'Unable to load OpenRouter credential state.':
        'Impossible de charger l’état des identifiants OpenRouter.',
    'Une connexion GitHub est requise pour charger la liste des dépôts.':
        'Une connexion GitHub est requise pour charger la liste des dépôts.',
    'Une fenêtre navigateur s’est ouverte pour autoriser ContentGlows.':
        'Une fenêtre navigateur s’est ouverte pour autoriser ContentGlows.',
    'Updated: {date}': 'Mis à jour : {date}',
    'Validate': 'Valider',
    'Validated: {date}': 'Validé : {date}',
    'Validation completed.': 'Validation terminée.',
    'All caught up': 'Tout est traité',
    'After setup, drafts can arrive as review cards.':
        'Après la configuration, les brouillons peuvent arriver sous forme de cartes à valider.',
    'Angle first': 'Angle d’abord',
    'Article and newsletter structures.':
        'Structures d’articles et de newsletters.',
    'Article review template': 'Template de validation article',
    'Audit context': 'Contexte d’audit',
    'Beats': 'Temps forts',
    'Best first move when the workspace is empty or newly connected.':
        'Meilleur premier geste quand le workspace est vide ou nouvellement connecté.',
    'Check the structures available for articles, newsletters, videos, and shorts.':
        'Vérifie les structures disponibles pour les articles, newsletters, vidéos et shorts.',
    'Check cadence before drafts land.':
        'Vérifie la cadence avant l’arrivée des brouillons.',
    'Check opening, beats, and recording clarity.':
        'Vérifie l’ouverture, les temps forts et la clarté d’enregistrement.',
    'Check promise, structure, and SEO intent before publish.':
        'Vérifie la promesse, la structure et l’intention SEO avant publication.',
    'Check the hook, platform nuance, and reply trigger.':
        'Vérifie l’accroche, la nuance plateforme et le déclencheur de réponse.',
    'Confirm the project, content types, channels, and rhythm before the first run.':
        'Confirme le projet, les types de contenus, les canaux et le rythme avant le premier lancement.',
    'Connected context': 'Contexte connecté',
    'Content formats': 'Formats de contenu',
    'Content rules': 'Règles de contenu',
    'Create a piece that can enter the review queue.':
        'Crée une pièce qui peut entrer dans la file de validation.',
    'CTA / links': 'CTA / liens',
    'Draft output': 'Sortie brouillon',
    'Drip rhythm': 'Rythme drip',
    'First draft': 'Premier brouillon',
    'Find pieces that can feed the next batch.':
        'Repère les contenus qui peuvent nourrir le prochain lot.',
    'Generate angles and turn the strongest one into a draft ready for review.':
        'Génère des angles et transforme le plus solide en brouillon prêt à valider.',
    'Human gate': 'Validation humaine',
    'Hook': 'Accroche',
    'Inspect the local actions waiting for backend sync.':
        'Inspecte les actions locales en attente de synchronisation backend.',
    'Inspect what already left the queue.':
        'Inspecte ce qui est déjà sorti de la file.',
    'LATER': 'PLUS TARD',
    'Later': 'Plus tard',
    'Lock the formats, cadence, and review gates.':
        'Verrouille les formats, la cadence et les étapes de validation.',
    'Long form': 'Format long',
    'Make sure ContentGlows knows what product to use.':
        'Assure-toi que ContentGlows sait quel produit utiliser.',
    'Newsletter review template': 'Template de validation newsletter',
    'Next swipe': 'Prochain swipe',
    'No dashboard action is waiting in this session.':
        'Aucune action du dashboard n’attend dans cette session.',
    'Nothing publishes before you approve it.':
        'Rien n’est publié avant ton approbation.',
    'One clear action at a time. Empty workspace metrics stay hidden until there is something useful to inspect.':
        'Une action claire à la fois. Les métriques vides du workspace restent masquées tant qu’il n’y a rien d’utile à inspecter.',
    'Open diagnostics': 'Ouvrir les diagnostics',
    'Open history': 'Ouvrir l’historique',
    'Open the content already approved or published from this workspace.':
        'Ouvre les contenus déjà approuvés ou publiés depuis ce workspace.',
    'Opening': 'Ouverture',
    'Only shown after at least one content item exists in history.':
        'Affiché seulement après l’existence d’au moins un contenu dans l’historique.',
    'Only shown when local work is waiting to sync.':
        'Affiché seulement quand du travail local attend une synchronisation.',
    'Only shown when upcoming content is actually scheduled.':
        'Affiché seulement quand du contenu à venir est réellement planifié.',
    'Pacing': 'Rythme',
    'Pick the shape before generating volume.':
        'Choisis la forme avant de générer du volume.',
    'Published trail': 'Trace publiée',
    'Queue control': 'Contrôle de file',
    'Recovery path': 'Chemin de reprise',
    'Reply trigger': 'Déclencheur de réponse',
    'Repurpose signal': 'Signal de réutilisation',
    'Reusable patterns': 'Patterns réutilisables',
    'Review actions that still need the backend.':
        'Passe en revue les actions qui ont encore besoin du backend.',
    'Review published history': 'Consulter l’historique publié',
    'Review the planned queue before the next content items arrive.':
        'Vérifie la file planifiée avant l’arrivée des prochains contenus.',
    'Risk check': 'Contrôle de risque',
    'Retry when the workspace is healthy again.':
        'Réessaie quand le workspace est à nouveau sain.',
    'Scheduled content': 'Contenu planifié',
    'See what is already planned.': 'Vois ce qui est déjà planifié.',
    'SEO intent': 'Intention SEO',
    'Short-form review template': 'Template de validation short',
    'Social post review template': 'Template de validation social post',
    'Spot blocked or repeated actions early.':
        'Repère tôt les actions bloquées ou répétées.',
    'START': 'COMMENCER',
    'Start from a clear hook before writing.':
        'Pars d’une accroche claire avant d’écrire.',
    'Structure': 'Structure',
    'Templates keep the output consistent when the queue grows.':
        'Les templates gardent une sortie cohérente quand la file grandit.',
    'Swipe to Publish': 'Swipe to Publish',
    'Sync queue': 'File de synchronisation',
    'Upcoming slots': 'Créneaux à venir',
    'Use this when you want momentum more than configuration.':
        'Utilise ceci quand tu veux avancer plus vite que configurer.',
    'Validate subject, sections, and reader action.':
        'Valide l’objet, les sections et l’action lecteur.',
    'Video-ready': 'Prêt vidéo',
    'Video script review template': 'Template de validation script vidéo',
    'Voice': 'Voix',
    'Watch the hook, pacing, and platform fit.':
        'Vérifie l’accroche, le rythme et l’adéquation plateforme.',
    'Workspace setup': 'Configuration du workspace',
    'Project Intelligence': 'Intelligence Projet',
    'Intelligence': 'Intelligence',
    'Source Inventory': 'Inventaire des sources',
    'Upload Source': 'Importer une source',
    'Filename': 'Nom de fichier',
    'Text source': 'Source texte',
    'Upload': 'Importer',
    'No intelligence sources yet.':
        "Aucune source d'intelligence pour le moment.",
    'No recommendations yet.': 'Aucune recommandation pour le moment.',
    'No facts extracted yet.': 'Aucun fait extrait pour le moment.',
    'Select a project to use Project Intelligence.':
        'Sélectionnez un projet pour utiliser Intelligence Projet.',
    'Project intelligence source uploaded.':
        'Source Project Intelligence importée.',
    'Upload failed.': "Échec de l'import.",
    'Asset library unavailable': 'Bibliothèque de ressources indisponible',
    'Attach global': 'Attacher globalement',
    'Category': 'Catégorie',
    'Capture': 'Capture',
    'Capture could not complete. You can try again.':
        'La capture n’a pas pu aboutir. Tu peux réessayer.',
    'Capture linked to content.': 'Capture liée au contenu.',
    'Capture saved locally.': 'Capture enregistrée localement.',
    'Content created from capture.': 'Contenu créé à partir de la capture.',
    'Creating content from capture.':
        'Création du contenu à partir de la capture.',
    'Device screen capture is available only in the Android app for now.':
        'La capture d’écran de l’appareil est disponible uniquement dans l’app Android pour le moment.',
    'Finalizing screen recording.': 'Finalisation de l’enregistrement d’écran.',
    'Global candidate': 'Candidat global',
    'Kind': 'Type',
    'Link to content': 'Lier au contenu',
    'Linked to content': 'Lié au contenu',
    'Linked to {title}': 'Lié à {title}',
    'Linking capture to content.': 'Liaison de la capture au contenu.',
    'Local captures': 'Captures locales',
    'Mic': 'Micro',
    'Mic on': 'Micro activé',
    'No assets': 'Aucune ressource',
    'No local captures yet.': 'Aucune capture locale pour le moment.',
    'No pending content is available for this project.':
        'Aucun contenu en attente n’est disponible pour ce projet.',
    'Primary': 'Principal',
    'Project assets': 'Ressources du projet',
    'Screenshot': 'Capture d’écran',
    'Screenshot saved locally.': 'Capture d’écran enregistrée localement.',
    'Screen capture was canceled before a file was saved.':
        'La capture d’écran a été annulée avant qu’un fichier soit enregistré.',
    'Screen recording is active.': 'L’enregistrement d’écran est actif.',
    'Select': 'Sélectionner',
    'Select a project': 'Sélectionner un projet',
    'Select an active project first.': 'Sélectionne d’abord un projet actif.',
    'Select an asset': 'Sélectionner une ressource',
    'Source': 'Source',
    'Sources': 'Sources',
    'Subcategory': 'Sous-catégorie',
    'No subcategory': 'Aucune sous-catégorie',
    'Uncategorized': 'Sans catégorie',
    'Export name: {name}': 'Nom d’export : {name}',
    'Tombstoned': 'Masqué',
    'Usage: {count}': 'Utilisation : {count}',
    'Waiting for Android screen capture consent.':
        'En attente du consentement Android pour la capture d’écran.',
    'Checking Google Search Console connection...':
        'Vérification de la connexion Google Search Console...',
    'Checking Search Console integration...':
        'Vérification de l’intégration Search Console...',
    'Connect Google Search Console in Integrations to sync SEO data.':
        'Connecte Google Search Console dans Intégrations pour synchroniser les données SEO.',
    'Connect Google Search Console, then sync a period to populate this view.':
        'Connecte Google Search Console, puis synchronise une période pour alimenter cette vue.',
    'Connect your GitHub account to pick a repository.':
        'Connecte ton compte GitHub pour sélectionner un dépôt.',
    'Could not open browser for Google Search Console authorization':
        'Impossible d’ouvrir le navigateur pour l’autorisation Google Search Console',
    'Failed to load SEO Stats': 'Impossible de charger les statistiques SEO',
    'Failed to load Search Console opportunities':
        'Impossible de charger les opportunités Search Console',
    'Failed to save Search Console property.':
        'Impossible d’enregistrer la propriété Search Console.',
    'Failed to validate Search Console.':
        'Impossible de valider Search Console.',
    'Google Search Console OAuth is unavailable.':
        'L’authentification Google Search Console est indisponible.',
    'Google Search Console is connected and valid.':
        'Google Search Console est connectée et valide.',
    'Google Search Console is connected but degraded.':
        'Google Search Console est connectée mais dégradée.',
    'Google Search Console is connected. Validate it before syncing.':
        'Google Search Console est connectée. Valide-la avant de synchroniser.',
    'No Google landing pages synced yet.':
        'Aucune page d’entrée Google synchronisée pour le moment.',
    'No Google queries synced yet.':
        'Aucune requête Google synchronisée pour le moment.',
    'No SEO Stats yet': 'Aucune statistique SEO pour le moment',
    'No Search Console opportunities for this period.':
        'Aucune opportunité Search Console pour cette période.',
    'Open Search Console status endpoint':
        'Ouvrir le point de statut Search Console',
    'Private tracker': 'Tracker privé',
    'Private tracker pageviews are separate from Google Search clicks.':
        'Les pages vues du tracker privé sont distinctes des clics Google Search.',
    'Recent data can be delayed or incomplete.':
        'Les données récentes peuvent être retardées ou incomplètes.',
    'Reconnect Google Search Console to sync SEO data.':
        'Reconnecte Google Search Console pour synchroniser les données SEO.',
    'Search Console disconnected.': 'Search Console déconnectée.',
    'Search Console sync completed.':
        'Synchronisation Search Console terminée.',
    'Search Console sync failed.':
        'Échec de la synchronisation Search Console.',
    'Search Console validated.': 'Search Console validée.',
    'SEO Stats are project-scoped because Search Console properties and private traffic are project data.':
        'Les statistiques SEO sont limitées au projet, car les propriétés Search Console et le trafic privé sont des données projet.',
    'Select a project before connecting Search Console.':
        'Sélectionne un projet avant de connecter Search Console.',
    'Sign in to manage Search Console.':
        'Connecte-toi pour gérer Search Console.',
    'Unable to load Search Console integration state.':
        'Impossible de charger l’état de l’intégration Search Console.',
    '{clicks} clicks · {impressions} impressions':
        '{clicks} clics · {impressions} impressions',
    '{count} views': '{count} vues',
    'Connect a mailbox folder once. ContentGlows checks it every 6 hours, turns useful emails into ideas, then moves processed emails to the archive folder.':
        'Connecte un dossier de boîte mail une seule fois. ContentGlows le vérifie toutes les 6 heures, transforme les emails utiles en idées, puis déplace les emails traités vers le dossier d’archive.',
    'Delete email source?': 'Supprimer la source email ?',
    'Email address': 'Adresse email',
    'Email source deleted.': 'Source email supprimée.',
    'Email source is valid': 'La source email est valide',
    'Email source needs attention': 'La source email requiert une attention',
    'Email source saved, not validated yet':
        'Source email enregistrée, pas encore validée',
    'Email source saved. Automatic checks run every 6 hours.':
        'Source email enregistrée. Des vérifications automatiques sont lancées toutes les 6 heures.',
    'Enter an email address first.': 'Saisis d’abord une adresse email.',
    'Events: {count}': 'Événements : {count}',
    'Failed to delete email source: {error}':
        'Impossible de supprimer la source email : {error}',
    'Failed to disconnect Search Console.':
        'Impossible de déconnecter Search Console.',
    'Failed to save email source: {error}':
        'Impossible d’enregistrer la source email : {error}',
    'Failed to validate email source: {error}':
        'Impossible de valider la source email : {error}',
    'Folder to scan': 'Dossier à scanner',
    'For Gmail: Google Account > Security > App passwords.':
        'Pour Gmail : Compte Google > Sécurité > Mots de passe des applications.',
    'Hide password': 'Masquer le mot de passe',
    'IMAP host': 'Hôte IMAP',
    'Loading email source...': 'Chargement de la source email...',
    'No email source connected': 'Aucune source email connectée',
    'Unable to load email source state.':
        'Impossible de charger l’état de la source email.',
    'Open email source endpoint': 'Ouvrir le point de source email',
    'Processed folder': 'Dossier traité',
    'Show password': 'Afficher le mot de passe',
    'This removes the stored IMAP app password and stops email-based idea ingestion.':
        'Cela supprime le mot de passe IMAP enregistré et arrête l’ingestion d’idées par email.',
    'Accepted tags: {tags}': 'Tags acceptés : {tags}',
    'Added {count} Search Console ideas. Skipped {skipped}.':
        '{count} idées Search Console ajoutées. {skipped} ignorées.',
    'Adjust the flow before review work piles up.':
        'Ajuste le flux avant que le travail de validation ne s’accumule.',
    'Android capture only': 'Capture Android uniquement',
    'App password': 'Mot de passe d’application',
    'Asset linked: {id}': 'Ressource liée : {id}',
    'Backend link is unavailable. The local link stays on this device.':
        'Le lien backend est indisponible. Le lien local reste sur cet appareil.',
    'CTA': 'CTA',
    'Choose an active project before creating content.':
        'Choisis un projet actif avant de créer du contenu.',
    'Choose an active project before linking assets.':
        'Choisis un projet actif avant de lier des ressources.',
    'Clear': 'Effacer',
    'Disconnect Search Console?': 'Déconnecter Search Console ?',
    'Failed to add opportunities to Idea Pool.':
        'Impossible d’ajouter les opportunités à l’Idea Pool.',
    'Fit: {reason}': 'Adéquation : {reason}',
    'Generate test content': 'Générer du contenu de test',
    'Ideas from newsletters, SEO, Search Console,\ncompetitors and social listening will appear here.':
        'Les idées issues des newsletters, du SEO, de Search Console,\ndes concurrents et de l’écoute sociale apparaîtront ici.',
    'Keep a clear memory of approved output.':
        'Garde une mémoire claire des contenus approuvés.',
    'Leave blank to keep current password':
        'Laisse vide pour conserver le mot de passe actuel',
    'No private analytics pageviews for this period.':
        'Aucune page vue d’analytics privée pour cette période.',
    'Pipeline analytics will appear as content flows through review and publishing.':
        'Les analytics du pipeline apparaîtront à mesure que le contenu avance dans la validation et la publication.',
    'Recording': 'Enregistrement',
    'Scripts, shorts, reels, and hook formats.':
        'Scripts, shorts, reels et formats d’accroche.',
    'Sections': 'Sections',
    'Select a project before connecting a publish account.':
        'Sélectionne un projet avant de connecter un compte de publication.',
    'Select a project before enabling automatic email ingestion.':
        'Sélectionne un projet avant d’activer l’ingestion automatique des emails.',
    'Select a project before enabling email ingestion.':
        'Sélectionne un projet avant d’activer l’ingestion des emails.',
    'Share': 'Partager',
    'Subject': 'Objet',
    'Suggested tags: {tags}': 'Tags suggérés : {tags}',
    'This removes the project OAuth connection. Cached SEO snapshots can still be shown as stale until replaced.':
        'Cela supprime la connexion OAuth du projet. Les instantanés SEO en cache peuvent encore apparaître comme obsolètes jusqu’à leur remplacement.',
    'URL': 'URL',
    'Understanding: {status}': 'Compréhension : {status}',
    'Warnings: {warnings}': 'Avertissements : {warnings}',
    'channel fit': 'adéquation canal',
    '{count} test content items generated': '{count} contenus de test générés',
    'Connector sync completed.': 'Synchronisation connecteurs terminée.',
    'Connector sync failed.': 'Échec de la synchronisation connecteurs.',
    'Source removed.': 'Source supprimée.',
    'Failed to remove source.': 'Impossible de supprimer la source.',
    'Recommendation added to Idea Pool.':
        "Recommandation ajoutée à l'Idea Pool.",
    'Failed to add recommendation to Idea Pool.':
        "Impossible d'ajouter la recommandation à l'Idea Pool.",
    'Failed to load sources': 'Impossible de charger les sources',
    'Failed to load recommendations':
        'Impossible de charger les recommandations',
    'Failed to load facts': 'Impossible de charger les faits',
    'Facts': 'Faits',
    'Provider readiness': 'Préparation provider',
    'Remove source': 'Supprimer la source',
    'Documents': 'Documents',
    'Confidence': 'Confiance',
    'Evidence': 'Preuve',
    'You are using the demo workspace without a real account.':
        'Vous utilisez le workspace démo sans compte réel.',
    'Your OpenRouter key is ready. Server-managed tools are also available for newsletter generation.':
        'Votre clé OpenRouter est prête. Les outils gérés côté serveur sont aussi disponibles pour la génération de newsletters.',
    'e.g. dripManaged': 'ex. dripManaged',
    'e.g. robots': 'ex. robots',
    'https://example.com or https://github.com/user/repo':
        'https://example.com or https://github.com/user/repo',
    'https://your-site.com': 'https://votre-site.com',
    '{count} actions are waiting to sync.':
        '{count} actions sont en attente de synchronisation.',
    '{count} item(s)': '{count} élément(s)',
    '{count} waiting': '{count} en attente',
    '{count} queued actions need manual review.':
        '{count} actions en file nécessitent une revue manuelle.',
    '{index} of {count}': '{index} sur {count}',
    'Prepare video sources': 'Préparer les sources vidéo',
    'Select a project before preparing video sources.':
        'Sélectionnez un projet avant de préparer les sources vidéo.',
    'Could not open the source folder':
        'Impossible d’ouvrir le dossier de sources',
    'Build your source folder': 'Constituez votre dossier de sources',
    'Gather the material first. Save it for later or request generation when everything is ready.':
        'Rassemblez d’abord vos éléments. Conservez-les pour plus tard ou demandez la génération quand tout est prêt.',
    '“Sources ready” stores this revision without generating. “Generate video” sends this revision once to the video workflow.':
        '« Sources prêtes » conserve cette version sans générer. « Générer la vidéo » transmet cette version une seule fois au flux vidéo.',
    'Collecting': 'Collecte en cours',
    'Ready': 'Prêt',
    'Add sources': 'Ajouter des sources',
    'Video, image, audio, pasted text or a public link.':
        'Vidéo, image, audio, texte collé ou lien public.',
    'Media files': 'Fichiers média',
    'Select media': 'Sélectionner des médias',
    'Select one or several videos, images or audio files at once. You can also add pasted text or a public link.':
        'Sélectionnez une ou plusieurs vidéos, images ou fichiers audio à la fois. Vous pouvez aussi ajouter du texte collé ou un lien public.',
    'Pasted text': 'Texte collé',
    'Paste video script': 'Coller le script de la vidéo',
    'The clipboard does not contain any text.':
        'Le presse-papier ne contient aucun texte.',
    'Public link': 'Lien public',
    'Uploading media sources': 'Téléversement des sources média',
    'Uploading {count} file(s)': 'Téléversement de {count} fichier(s)',
    'Source library': 'Bibliothèque de sources',
    'Files': 'Fichiers',
    'Links': 'Liens',
    'No sources match this filter.': 'Aucune source ne correspond à ce filtre.',
    'Add your first source to prepare the video.':
        'Ajoutez votre première source pour préparer la vidéo.',
    'Source actions': 'Actions de la source',
    'Replace': 'Remplacer',
    'Validation pending': 'Validation en attente',
    'Processing': 'Traitement en cours',
    'Preview unavailable': 'Aperçu indisponible',
    'Needs attention': 'À corriger',
    'Replacement pending': 'Remplacement en cours',
    'Recovery required': 'Récupération nécessaire',
    'Replaced': 'Remplacée',
    'Removed': 'Retirée',
    'Safe metadata pending': 'Métadonnées sûres en attente',
    '{count} characters': '{count} caractères',
    'Remove this source?': 'Retirer cette source ?',
    'The source leaves this folder. A reusable project asset is not deleted from other content.':
        'La source quitte ce dossier. Un asset de projet réutilisable n’est pas supprimé des autres contenus.',
    'Sources ready': 'Sources prêtes',
    'Select photos and videos': 'Sélectionner des photos et vidéos',
    'Stored safely on ContentGlows':
        'Stocké en toute sécurité sur ContentGlows',
    'This copy is stored safely in ContentGlows. Android will ask you for final confirmation before it is deleted from this device.':
        'Cette copie est stockée en toute sécurité dans ContentGlows. Android vous demandera une confirmation finale avant de la supprimer de cet appareil.',
    'You can delete this phone copy. Android will ask for final confirmation.':
        'Vous pouvez supprimer cette copie du téléphone. Android demandera une confirmation finale.',
    'Generate video': 'Générer la vidéo',
    '1 source must be fixed before continuing.':
        '1 source doit être corrigée avant de continuer.',
    '{count} sources must be fixed before continuing.':
        '{count} sources doivent être corrigées avant de continuer.',
    'Add pasted text': 'Ajouter du texte collé',
    'Source text': 'Texte source',
    'Add text': 'Ajouter le texte',
    'Add public link': 'Ajouter un lien public',
    'Public HTTP(S) link': 'Lien HTTP(S) public',
    'Add link': 'Ajouter le lien',
    'Files added to the source folder.':
        'Fichiers ajoutés au dossier de sources.',
    'Text added to the source folder.': 'Texte ajouté au dossier de sources.',
    'Link added to the source folder.': 'Lien ajouté au dossier de sources.',
    'Source retry started.': 'Nouvelle tentative lancée.',
    'Source replaced.': 'Source remplacée.',
    'Sources saved as ready. No video was generated.':
        'Sources conservées comme prêtes. Aucune vidéo n’a été générée.',
    'Video generation request accepted.':
        'La demande de génération vidéo a été acceptée.',
    'Text must contain between 1 and 100,000 characters.':
        'Le texte doit contenir entre 1 et 100 000 caractères.',
    'Enter a valid public HTTP(S) link.':
        'Saisissez un lien HTTP(S) public valide.',
    'The source folder needs an internet connection. Retry when the workspace is online.':
        'Le dossier de sources nécessite une connexion. Réessayez lorsque l’espace de travail est en ligne.',
    'The source folder changed. Refresh it before trying again.':
        'Le dossier de sources a changé. Actualisez-le avant de réessayer.',
    'This link cannot be used safely.':
        'Ce lien ne peut pas être utilisé en toute sécurité.',
    'This file exceeds the supported size.':
        'Ce fichier dépasse la taille prise en charge.',
    'This file type is not supported.':
        'Ce type de fichier n’est pas pris en charge.',
    'Correct the blocked sources before continuing.':
        'Corrigez les sources bloquées avant de continuer.',
    'The sources remain ready, but generation could not be queued. Retry safely.':
        'Les sources restent prêtes, mais la génération n’a pas pu être mise en file. Vous pouvez réessayer sans risque de doublon.',
    'The source action could not be completed. Retry safely.':
        'L’action sur la source n’a pas abouti. Vous pouvez réessayer sans risque.',
    '{count} file(s) could not be added. Retry from the source library.':
        '{count} fichier(s) n’ont pas pu être ajoutés. Réessayez depuis la bibliothèque de sources.',
    'Prepare your next video from its sources':
        'Préparez votre prochaine vidéo à partir de ses sources',
    'Open a content item, gather videos, images, audio, text and links, then choose whether to save the sources or generate the video.':
        'Ouvrez un contenu, rassemblez vidéos, images, audio, texte et liens, puis choisissez de conserver les sources ou de générer la vidéo.',
    'Choose content': 'Choisir un contenu',
  };

  static const Map<String, Map<String, String>> _localizedValues =
      <String, Map<String, String>>{appLanguageFrench: _frenchTranslations};
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final languageCode = locale.languageCode.toLowerCase();
    return languageCode.startsWith(appLanguageEnglish) ||
        languageCode.startsWith(appLanguageFrench);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsBuildContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String get localeTag => Localizations.localeOf(this).toLanguageTag();

  String tr(
    String key, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) {
    return l10n.tr(key, params: params);
  }
}
