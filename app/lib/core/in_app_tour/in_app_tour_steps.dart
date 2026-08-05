import 'in_app_tour_step.dart';

const List<InAppTourStep> kInAppTourSteps = [
  InAppTourStep(
    id: 'welcome',
    title: 'Welcome to ContentGlows',
    description:
        'We will take a quick tour of the app, screen by screen. '
        'The goal is to show you the best order to use each page, what the main controls do, '
        'and how to get the most out of the platform. '
        'You can pause at any time and resume later from Settings.',
  ),
  InAppTourStep(
    id: 'feed',
    routePath: '/feed',
    title: 'Feed — your publish-ready queue',
    description:
        'This is where you check what is ready to publish, what is still preparing, and what is blocked. '
        'You can swipe the card or use the three round buttons at the bottom: '
        'the left button skips the item, the middle one opens the editor, '
        'and the right one publishes only when the card is truly ready. '
        'Video cards also summarize publish preflight blockers before you try to post. '
        'The red badge on the Feed icon shows how many items are waiting for review.',
    hint: 'Ready cards can be published directly; blocked cards explain what is missing first.',
  ),
  InAppTourStep(
    id: 'calendar',
    routePath: '/calendar',
    title: 'Calendar — your scheduled posts',
    description:
        'The calendar shows everything scheduled for publishing. '
        'Tap a week at the top to filter the view. '
        'It is useful for checking the balance of your schedule and spotting empty or overloaded days.',
  ),
  InAppTourStep(
    id: 'history',
    routePath: '/history',
    title: 'History — everything that has been published',
    description:
        'Find all published content here, with its status and target platform. '
        'This is your archive for checking what has already gone out or reusing a past idea.',
  ),
  InAppTourStep(
    id: 'drip',
    routePath: '/drip',
    title: 'Drip — automated sequences',
    description:
        'Drip orchestrates content sequences over multiple days. '
        'Instead of publishing one isolated post, you launch a coherent series, such as a 5-post mini campaign around one topic. '
        'Use it for launches or for themes that deserve several angles.',
  ),
  InAppTourStep(
    id: 'content_tools',
    routePath: '/content-tools',
    title: 'Content Tools — checks and audits',
    description:
        'This toolbox checks your content quality before publishing: '
        'editorial consistency, funnel audits, and validations. '
        'Use it when a draft feels off — the audit often explains why.',
  ),
  InAppTourStep(
    id: 'templates',
    routePath: '/templates',
    title: 'Templates — your reusable formats',
    description:
        'Templates are your repeatable content formats: long-form articles, short posts, or sequences. '
        'The AI uses them to generate content that matches your style. '
        'The more precise your templates are, the closer the output will match your voice.',
  ),
  InAppTourStep(
    id: 'newsletter',
    routePath: '/newsletter',
    title: 'Newsletter — your long-form channel',
    description:
        'The Newsletter screen groups together newsletter creation, preview, and sending. '
        'You can combine several Feed items into one edition. '
        'It is ideal for turning a week of production into a single send.',
  ),
  InAppTourStep(
    id: 'reels',
    routePath: '/reels',
    title: 'Reels — short video formats',
    description:
        'Manage your short-form videos here: reels, shorts, and similar vertical formats. '
        'The AI can suggest scripts and structure, and you decide what to edit or approve before publishing. '
        'The main Feed still stays central, while Reels is the workshop dedicated to vertical content.',
  ),
  InAppTourStep(
    id: 'affiliations',
    routePath: '/affiliations',
    title: 'Affiliations — your monetized links',
    description:
        'Centralize your affiliate links so the AI can insert them intelligently into relevant content. '
        'Add a link here once, and it will be suggested automatically whenever the topic fits.',
  ),
  InAppTourStep(
    id: 'research',
    routePath: '/research',
    title: 'Research — feed your strategy',
    description:
        'Research gathers trending topics, competitor monitoring, and audience questions. '
        'This is the screen to check before each planning ritual so you know what to cover this week.',
  ),
  InAppTourStep(
    id: 'seo',
    routePath: '/seo',
    title: 'SEO — organic visibility',
    description:
        'Use this screen for SEO analysis and keyword opportunities. '
        'Before launching a Drip series or a long-form article, come here to align your angles with the searches that matter.',
  ),
  InAppTourStep(
    id: 'analytics',
    routePath: '/analytics',
    title: 'Analytics — measure impact',
    description:
        'This is your global dashboard for audience, engagement, and growth. '
        'It should be your first weekly stop to see what is working. '
        'Start with the broad trends here, then go deeper in Performance.',
  ),
  InAppTourStep(
    id: 'performance',
    routePath: '/performance',
    title: 'Performance — detailed metrics',
    description:
        'Performance complements Analytics with metrics per content item and per channel. '
        'Use it when you want to understand why a post worked, or why it did not, and repeat what succeeds.',
  ),
  InAppTourStep(
    id: 'runs',
    routePath: '/runs',
    title: 'Runs — AI job history',
    description:
        'Every AI generation leaves a trace here: which model, which prompt, and how long it took. '
        'Check it when a result looks suspicious or when you want to keep an eye on cost.',
  ),
  InAppTourStep(
    id: 'activity',
    routePath: '/activity',
    title: 'Activity — system timeline',
    description:
        'This is the chronological log of everything happening in your workspace: creations, publications, and errors. '
        'It is useful for diagnosis when something does not seem to have worked.',
  ),
  InAppTourStep(
    id: 'personas',
    routePath: '/personas',
    title: 'Personas — your target audiences',
    description:
        'Define the personas the AI should address. Each persona influences tone, vocabulary, and angles. '
        'Use the + button in the bottom-right corner to add a new persona.',
    hint: 'Use the + button in the bottom-right corner to add a persona.',
  ),
  InAppTourStep(
    id: 'work_domains',
    routePath: '/work-domains',
    title: 'Work domains',
    description:
        'Configure the topic areas the AI is allowed to work on. '
        'This prevents off-topic output and keeps production focused on your real areas of expertise.',
  ),
  InAppTourStep(
    id: 'uptime',
    routePath: '/uptime',
    title: 'Uptime — technical status',
    description:
        'Check backend health here. If the app enters degraded mode, this screen tells you why and when the service is back.',
  ),
  InAppTourStep(
    id: 'settings',
    routePath: '/settings',
    title: 'Settings — personalize everything',
    description:
        'This is your control center for language, generation frequency, publishing channels, notifications, and your weekly ritual. '
        'It is also where you will find the guided tour setting if you want to restart or resume this tour later.',
    hint: 'Look for the "Guided app tour" tile to restart the tour.',
  ),
  InAppTourStep(
    id: 'completion',
    title: 'You are ready!',
    description:
        'You have seen the essentials. A few reminders to get started well: '
        '1) configure your personas and weekly ritual in Settings, '
        '2) let the AI generate, then publish ready items or fix blockers from the Feed, '
        '3) track the impact in Analytics. '
        'To relaunch this tour, open Settings and use the guided app tour option.',
  ),
];
