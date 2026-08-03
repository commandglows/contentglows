---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: app
created: "2026-07-18"
created_at: "2026-07-18 10:57:16 UTC"
updated: "2026-07-30"
updated_at: "2026-07-30 14:18:00 UTC"
status: ready
source_skill: 100-sg-spec
source_model: "GPT-5 Codex"
scope: "Android native authentication migration"
owner: "Diane"
confidence: high
user_story: "En tant qu’utilisateur Android de ContentGlowz, je veux me connecter avec Google puis revenir automatiquement dans l’application avec une session utilisable, afin d’accéder à mon workspace sans perdre le parcours dans le navigateur."
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - app Flutter client
  - Android Kotlin host
  - Clerk Android Native SDK
  - ClerkJS web authentication runtime
  - FastAPI Clerk JWT verification
  - Google OAuth / Google Credential Manager
  - Sentry Flutter diagnostics
depends_on:
  - artifact: "shipglows_data/technical/app/architecture.md"
    artifact_version: "0.1.0"
    required_status: reviewed
  - artifact: "shipglows_data/technical/app/platforms/clerk.md"
    artifact_version: "0.1.0"
    required_status: draft
  - artifact: "shipglows_data/technical/external-platforms/clerk.md"
    artifact_version: "0.1.0"
    required_status: draft
  - artifact: "Clerk Android native SDK documentation"
    artifact_version: "checked 2026-07-18"
    required_status: current
supersedes: []
evidence:
  - "app/lib/data/services/clerk_auth_service_stub.dart returns no Android session and rejects the retired Flutter beta path."
  - "app/android/app/src/main/AndroidManifest.xml has no Clerk callback intent filter."
  - "app/android/app/src/main/kotlin/com/contentglowz/app/MainActivity.kt does not pass incoming callback URIs to Clerk."
  - "The existing web implementation uses a ClerkJS bridge and must remain the web-only implementation."
  - "FastAPI already accepts Clerk bearer JWTs through lab/api/auth/clerk.py and lab/api/dependencies/auth.py."
  - "Clerk Android docs checked 2026-07-18: Native API, API-only SDK, Application initialization, Activity deep-link handling, session getToken/signOut, and Google native sign-in."
next_step: "/005-sg-ship Android native Clerk auth bridge"
---

# Title

Android native Clerk auth bridge for Flutter and FastAPI

# Status

Implementation complete locally; verification is partial pending Android Gradle/device OAuth and provider configuration proof.

# User Story

En tant qu’utilisateur Android de ContentGlowz, je veux me connecter avec Google puis revenir automatiquement dans l’application avec une session utilisable, afin d’accéder à mon workspace sans perdre le parcours dans le navigateur.

# Minimal Behavior Contract

Depuis l’écran de connexion Android, l’utilisateur lance une connexion Google native gérée par Clerk; une connexion aboutie active une session Clerk dans l’APK, fournit à Flutter un jeton Bearer frais uniquement en mémoire et déclenche le bootstrap FastAPI existant. Si l’utilisateur annule, si le callback est invalide, ou si Clerk/FastAPI échoue, l’application reste connectée à aucun compte, conserve l’action de réessai et fournit des diagnostics expurgés. Un callback reçu alors que l’application est déjà ouverte ou recréée doit finaliser le même flux une seule fois, sans créer une session web parallèle ni envoyer le jeton dans une URL.

# Success Behavior

- Android initialise une seule instance Clerk native avant l’usage du bridge Flutter et attend son état prêt avant toute opération d’authentification.
- Le bouton Android « Sign In » lance le flux OAuth Google officiel de Clerk, sans WebView ni redirection via les routes ClerkJS web.
- Pour les connexions OAuth nécessitant un navigateur, l’URI de retour Android est `clerk://com.contentglowz.app.callback`, soit le callback par défaut de Clerk Android 1.0.36. Il est allowlisté chez Clerk; l’`SSOReceiverActivity` déclarée par le SDK reçoit et traite le callback, sans exposer ses paramètres à Flutter.
- Après une authentification confirmée, le bridge retourne à Dart l’identifiant utilisateur minimal, l’e-mail seulement si fourni par Clerk, et un JWT court-vivant obtenu via `Clerk.auth.getToken()`; Flutter ne persiste pas ce JWT dans SharedPreferences, fichiers, diagnostics ou URL.
- La restauration au redémarrage récupère l’état Clerk natif, obtient un jeton frais et réutilise le bootstrap FastAPI, les routes et les invalidations Riverpod existants.
- La déconnexion Android appelle `Clerk.auth.signOut()`, efface l’état Dart/cache auth existant et interdit les nouveaux appels authentifiés.
- Le web continue d’utiliser exclusivement `clerk_auth_service_web.dart` et `window.contentglowzClerkBridge`; ses routes `/sign-in`, `/sign-up` et `/sso-callback`, ses rewrites et son build ne changent pas de comportement.

# Error Behavior

- Initialisation Clerk absente, clé publique absente, Native API non activée, callback non autorisé, Google annulé, erreur OAuth, jeton vide/expiré et échec de bootstrap produisent un résultat typé et redacted, jamais un succès implicite.
- Le bridge ne journalise ni token, cookie, authorization code, URI de callback complète, e-mail privé, ni réponse brute du fournisseur. Les diagnostics indiquent seulement l’étape, une catégorie d’erreur stable, le build et l’horodatage Paris/UTC existants.
- Un 401 FastAPI provoque le mécanisme existant de ré-authentification; il ne convertit jamais l’échec en session locale valide ni ne dégrade le contrôle serveur de JWT/JWKS.
- Les erreurs Android/Kotlin sont converties en exceptions Dart typées et capturées par les diagnostics/Sentry existants avec données sensibles retirées.

# Problem

La production web utilise correctement ClerkJS, mais Android résout `ClerkAuthService` vers un stub qui ne restaure aucune session, ne sait ni lancer une connexion ni fournir un token. L’APK ouvre donc un flux web sans récepteur de callback ni session native. Le retour visuel vers l’app et le handoff sécurisé de session au backend sont absents.

# Solution

Intégrer l’API officielle Clerk Android dans l’hôte Kotlin, sans adopter le SDK Flutter bêta ni l’UI Compose de Clerk. Un `MethodChannel` Kotlin/Dart limité expose l’état d’initialisation, le démarrage du login Google, la restauration de session, l’obtention d’un token frais et la déconnexion. Kotlin reste propriétaire de Clerk, de Credential Manager et des callbacks; Dart conserve l’orchestration d’accès, le bootstrap FastAPI et l’UI Flutter.

# Scope In

- Dépendance Kotlin `com.clerk:clerk-android-api` épinglée à une version officiellement compatible au moment de l’implémentation, plus ses exigences Android documentées (minSdk >= 24 et Java 17).
- Initialisation native Clerk dans une classe `Application` dédiée avec `CLERK_PUBLISHABLE_KEY` injectée par le build Android dans un `BuildConfig` non sensible; le build auth-enabled échoue si elle est absente et la valeur n’est jamais écrite dans les logs ou docs.
- Bridge Kotlin/Dart Android, service Dart non-web et contrat de résultats/erreurs typés.
- Connexion Google native via le mécanisme Android recommandé par Clerk; configuration Clerk/Google requise pour package `com.contentglowz.app` et empreintes SHA-1 des clés debug/release.
- Callback OAuth/deep link Android: allowlist Clerk, intent-filter strict, traitement idempotent dans `onCreate` et `onNewIntent`, puis reprise du flux Flutter.
- Restauration, refresh de token, déconnexion et intégration avec `AuthSessionNotifier`, `ApiService` et bootstrap FastAPI actuels.
- Tests Dart unitaires, tests Kotlin unitaires/instrumentés nécessaires au bridge/callback, et checklist d’auth manuelle sur appareil Android réel.
- Mise à jour de l’architecture et de la note de plateforme Clerk avec les frontières Android/web, les variables sans valeurs, le rollback et la preuve de configuration.

# Scope Out

- Réintégrer ou maintenir `clerk_flutter` beta.
- Modifier l’implémentation web ClerkJS, les rewrites Vercel ou le handoff site existant, hors régression prouvée.
- Transmettre un JWT Clerk, cookie, code OAuth ou secret dans une URL, SharedPreferences, clipboard, logs, Sentry ou backend de relais.
- Changer la validation JWT/JWKS FastAPI, les droits/ownership serveur ou créer une identité applicative parallèle.
- Ajouter une UI native Compose ou remplacer l’interface Flutter.
- Modifier les fournisseurs sociaux autres que Google, l’auth iOS ou le login email/password, sauf si une dépendance Android officielle rend une correction minimale indispensable et testable.

# Constraints

- Utiliser seulement le SDK Android officiel Clerk; l’API-only artifact est retenu car Flutter conserve l’UI.
- Ne pas figer une version « latest » : résoudre au début de l’implémentation la dernière release stable compatible puis la pinner dans Gradle et consigner la version dans la note de plateforme.
- `CLERK_PUBLISHABLE_KEY` reste une clé publique de build; Gradle la lit uniquement depuis l’environnement/CI ou une propriété locale ignorée de Git et l’expose comme `BuildConfig` à l’`Application`. Aucune clé secrète Clerk/Google, empreinte complète non nécessaire ou configuration dashboard ne peut entrer dans Git.
- Le callback utilise un schéma/package Android contrôlé et exactement allowlisté. Le bridge accepte seulement les données produites par le SDK Clerk, jamais une URI arbitraire envoyée par Dart.
- FastAPI demeure l’autorité de données et vérifie chaque bearer token; le client n’interprète jamais le JWT pour autoriser des actions métier.
- Conserver `sendDefaultPii=false` et les règles actuelles de redaction Sentry/diagnostics.
- Ne pas toucher aux fichiers sales non liés. Le release signing Android est hors scope de ce chantier, mais les empreintes Google devront couvrir la clé réellement utilisée pour l’APK testé/distribué.

# Test Contract

Surface: Flutter Android + Kotlin native SDK + Google authentication + Clerk session + FastAPI bearer integration; web ClerkJS est une surface de non-régression.

Proof profile: `auth-native-mobile-device`.

Checklist path: `shipglows_data/workflow/test-checklists/android-native-clerk-auth-bridge.md`.

Required scenario IDs and results: `AUTH-ANDROID-001` Google native success → session + bootstrap; `AUTH-ANDROID-002` cancellation → signed-out + retry; `AUTH-ANDROID-003` callback external valid while Activity created/open → one completion; `AUTH-ANDROID-004` callback invalid/replayed → no state change; `AUTH-ANDROID-005` restart → restored session; `AUTH-ANDROID-006` logout/401 → signed-out + no bearer; `AUTH-WEB-001` ClerkJS non-regression. Each must record pass/fail and redacted build identity.

Preuve ordonnée requise:

1. Analyse/format et tests Dart ciblés du service, notifier et API token provider.
2. Tests Kotlin locaux et/ou instrumentés couvrant l’initialisation, la traduction d’erreurs, le routage de `onNewIntent` et l’idempotence du callback avec un fake injectable; aucune vraie session ni token dans les fixtures.
3. Vérification Gradle Android de la résolution de dépendance, minSdk et manifest merger.
4. Test d’intégration sur appareil Android réel: Google native sign-in → session APK → `GET /api/bootstrap` bearer valide → navigation workspace; relance de l’app → session restaurée; logout → 401/no token.
5. Preuve de callback navigateur seulement pour le fournisseur/scénario qui la requiert: navigation externe → `clerk://com.contentglowz.app.callback` → app active; cancellation et callback répété.
6. Non-régression web: validation Clerk runtime existante et contrôle des routes auth en build/preview.
7. Checklist durable: `shipglows_data/workflow/test-checklists/android-native-clerk-auth-bridge.md`, remplie avec build id, commits, dates Paris/UTC, appareils/versions masqués si nécessaire, résultats et diagnostics redacted.

Exception-with-proof: le test OAuth réel ne peut pas être automatisé de bout en bout sans identité Google/Clerk et signature de distribution; il est obligatoirement prouvé sur appareil avec comptes de test dédiés, jamais par un token copié.

# Dependencies

- Clerk Android Quickstart, installation et configuration, consultés le 2026-07-18: Native API doit être activée; API-only SDK est supporté; initialisation dans `Application`; minSdk 24 et Java 17. `fresh-docs checked`.
- Clerk Android authentication flows, consulté le 2026-07-18: `Clerk.auth.getToken()`, `signOut()`, et `Clerk.auth.handle(intent.data)` pour callbacks OAuth/SSO/email. `fresh-docs checked`.
- Clerk Android Google sign-in/social connections, consulté le 2026-07-18: Google natif via Credential Manager; configuration package/SHA-1 et custom credentials Google; Google ne fonctionne pas en in-app browser. `fresh-docs checked`.
- FastAPI `lab/api/auth/clerk.py` et `lab/api/dependencies/auth.py`: vérification de bearer Clerk par issuer/JWKS existante, à préserver.
- Android Gradle actuel: AGP 8.11.1, Kotlin 2.2.20, Java 17; `minSdk` est délégué à Flutter et doit être mesuré avant dépendance puis relevé à 24 si nécessaire.
- Sources officielles: https://clerk.com/docs/android/getting-started/quickstart ; https://clerk.com/docs/android/reference/native-mobile/installation ; https://clerk.com/docs/android/reference/native-mobile/configuration ; https://clerk.com/docs/android/reference/native-mobile/auth ; https://clerk.com/docs/android/guides/configure/auth-strategies/sign-in-with-google

# Invariants

- Une identité Clerk (`sub`) reste l’unique identité utilisateur de ContentGlowz; aucun `userId` local ne la remplace.
- Chaque requête FastAPI authentifiée récupère un token frais par le service de plateforme; aucun token Clerk n’est durablement stocké côté Flutter.
- Une session Clerk Android est source de vérité pour Android; une session ClerkJS est source de vérité pour web. Elles ne sont ni copiées ni converties l’une dans l’autre.
- Chaque callback est passé une fois au SDK Clerk et ne peut pas doubler le bootstrap, la navigation ou la session.
- L’absence de session, l’annulation et tout échec natif laissent l’application signed-out avec action de retry; elles ne basculent jamais en demo ni en bypass.
- Les diagnostics restent safe-by-design et commencent avec identité build + timestamps Paris/UTC fournis par la configuration existante.
- Le backend reste le seul endroit qui accepte/rejette un JWT pour les données protégées.

# Links & Consequences

- `app/lib/data/services/clerk_auth_service.dart` sélectionne déjà web vs non-web; Android aura une implémentation conditionnelle dédiée plutôt que d’enrichir le stub utilisé par d’autres plateformes.
- `AuthSessionNotifier` et `apiServiceProvider` disposent déjà des points d’intégration restore/getFreshToken/signOut; changer leur contrat exige de préserver demo mode, accès dégradé, invalidation d’offline queues et gestion 401.
- `MainActivity` porte déjà des channels capture/media; le bridge auth doit composer avec eux sans détourner leurs résultats d’activité ou permissions.
- `AndroidManifest.xml` reçoit un intent-filter de callback étroit; son `launchMode=singleTop` exige `onNewIntent` pour une app déjà ouverte.
- La configuration Google/Clerk dashboard est une opération externe requise avant preuve réelle. Elle doit être effectuée sans capturer secrets ni auth codes dans les tickets, logs ou spec.
- Le support Android supprime l’actuel message web-only de l’APK; les copies/l10n et diagnostics doivent refléter exactement les capacités de chaque plateforme.

# Documentation Coherence

- Mettre à jour `shipglows_data/technical/app/platforms/clerk.md` : matrice Web ClerkJS / Android Clerk native, package callback, clés seulement par nom, source de token, redaction, rollback, validation device et configuration dashboard requise.
- Mettre à jour `shipglows_data/technical/app/architecture.md` et, si nécessaire, `context-function-tree.md` pour le nouveau propriétaire Kotlin de session/callback et le bridge Flutter.
- Mettre à jour les instructions Android/app si les commandes de build, les `--dart-define` Android ou la checklist de release changent.
- Ajouter la checklist de test Android mentionnée au Test Contract; ne pas documenter de valeurs de secrets, tokens, emails réels, codes ou URLs de callback contenant des paramètres.
- Conserver la documentation web ClerkJS existante et y expliciter sa non-régression, sans la remplacer par la voie Android.

# Edge Cases

- L’utilisateur annule le sélecteur Google, ferme le navigateur, refuse un compte ou revient sans URI de callback.
- Le callback arrive pendant que l’Activity est ouverte, après recréation de processus, ou deux fois; le bridge doit ne résoudre qu’une fois le résultat en attente.
- Android reçoit une URI non conforme, d’un autre schéma/host/path, ou sans état Clerk utilisable; elle est ignorée/redacted et ne change pas la session.
- Clerk est encore en initialisation lorsqu’un bouton Flutter est pressé; l’action attend ou retourne une erreur `notReady` typée, sans crash.
- Le jeton est absent/expiré entre restore et `/api/bootstrap`; le provider rafraîchit via Clerk et le 401 suit la voie de re-auth existante.
- Déconnexion pendant callback ou bootstrap; aucune réponse tardive ne peut rétablir l’état authentifié.
- APK debug et release n’ont pas la même signature; la configuration Google doit permettre le scénario de build effectivement validé.
- Web, desktop/stub et Android conservent leurs comportements indépendants via imports conditionnels et tests de compilation.

# Implementation Tasks

- [ ] Task 1: Valider et pinner le contrat SDK/configuration Android Clerk.
  - Fichier : `app/android/app/build.gradle.kts`, `app/android/app/src/main/AndroidManifest.xml`, configuration Clerk/Google hors Git.
  - Action : Vérifier minSdk effectif; le fixer à >=24 si Flutter le fournit plus bas; injecter `CLERK_PUBLISHABLE_KEY` depuis l’environnement/CI Gradle dans `BuildConfig` et faire échouer tout build auth-enabled si elle est absente; ajouter l’API-only SDK Clerk à une version stable précise; activer Native API Clerk; configurer Google Android+Web clients et l’allowlist callback pour `clerk://com.contentglowz.app.callback` sans enregistrer de secret.
  - User story link : permet une session Android officielle et un retour contrôlé.
  - Depends on : none.
  - Validate with : Gradle dependency insight/build, manifest merger, revue dashboard redacted et preuve de package/signature testée.
  - Notes : Ne pas utiliser `clerk-android-ui` ni `clerk_flutter`.

- [ ] Task 2: Créer le propriétaire Kotlin de Clerk et le bridge Flutter.
  - Fichier : `app/android/app/src/main/kotlin/com/contentglowz/app/ContentGlowzApplication.kt`, `app/android/app/src/main/kotlin/com/contentglowz/app/auth/ClerkAuthChannel.kt`, `app/android/app/src/main/kotlin/com/contentglowz/app/MainActivity.kt`.
  - Action : Initialiser Clerk une fois dans `Application`; créer un channel injecté/testable exposant `initialize`, `signInWithGoogle`, `restoreSession`, `getFreshToken`, `signOut`; laisser `SSOReceiverActivity` du SDK traiter son callback allowlisté et annuler les opérations en cours à la destruction.
  - User story link : orchestre Google, callback et session native sans quitter définitivement l’APK.
  - Depends on : Task 1.
  - Validate with : tests Kotlin fakes + lint/compile Android; inspection que les channels capture/media existants restent routés.
  - Notes : Les payloads MethodChannel ne contiennent jamais token dans les logs; le token ne traverse Dart qu’en valeur mémoire de retour.

- [ ] Task 3: Ajouter le service Dart Android et le contrat d’erreur de plateforme.
  - Fichier : `app/lib/data/services/clerk_auth_service_android.dart` (nouveau), `app/lib/data/services/clerk_auth_service.dart`, `app/lib/data/services/clerk_auth_service_stub.dart`.
  - Action : Sélectionner une implémentation Android dédiée; mapper les résultats Kotlin vers `ClerkAuthResult`; ajouter `signInWithGoogle` et exceptions typées; garder le stub pour plateformes non web/non Android et le service web inchangé.
  - User story link : rend la session native consommable par Flutter sans changer l’expérience web.
  - Depends on : Task 2.
  - Validate with : tests Dart de codec, résultat vide, annulation, erreur native et absence de stockage/payload de token.
  - Notes : Ne pas ajouter de persistance custom de session; Clerk Android en est propriétaire.

- [ ] Task 4: Relier l’état Flutter, l’UI et FastAPI au bridge Android.
  - Fichier : `app/lib/providers/providers.dart`, `app/lib/presentation/screens/entry/entry_screen.dart`, l10n associée et tests ciblés.
  - Action : Ajouter l’action Google Android, restaurer/refresh/signOut via le nouveau service, préserver les transitions Riverpod et la récupération 401; remplacer la copy Android web-only par les états natifs réels et diagnostics redacted.
  - User story link : termine le parcours par l’ouverture du workspace authentifié.
  - Depends on : Task 3.
  - Validate with : Flutter unit/widget tests, simulation de session obtenue/annulée/expirée, et assertion que `ApiService` porte un bearer frais seulement en mémoire.
  - Notes : Le chemin web et son texte restent ClerkJS; ne pas faire ouvrir `/sign-in` depuis Android pour Google natif.

- [ ] Task 5: Ajouter les preuves de non-régression, observabilité et documentation.
  - Fichier : `app/test/**` ciblés, `app/android/app/src/test/**` et/ou `src/androidTest/**`, `shipglows_data/workflow/test-checklists/android-native-clerk-auth-bridge.md`, `shipglows_data/technical/app/platforms/clerk.md`, `shipglows_data/technical/app/architecture.md`, `shipglows_data/technical/app/context-function-tree.md` si impacté.
  - Action : Écrire les tests/checklist, conserver les diagnostics build Paris/UTC, documenter la configuration sans secrets et le rollback; exécuter la preuve device/Google et la validation web.
  - User story link : assure que l’auth retourne durablement à l’app sans dégrader web ou sécurité.
  - Depends on : Tasks 1-4.
  - Validate with : Test Strategy complet et checklist remplie avec résultats redacted.
  - Notes : Capturer seulement catégories d’erreur, build, étapes et résultats; aucun artefact d’auth sensible.

# Acceptance Criteria

- [ ] Une installation Android avec Clerk Native API activée affiche l’action Google native et ne lance pas le login ClerkJS web.
- [ ] Une connexion Google réussie active une session Clerk Android et conduit l’utilisateur vers onboarding ou workspace selon `/api/bootstrap`.
- [ ] Si un OAuth navigateur est utilisé, le retour `clerk://com.contentglowz.app.callback` revient dans l’APK et est traité par `SSOReceiverActivity` du SDK.
- [ ] Les callbacks annulés, invalides ou répétés ne créent aucune session ni navigation dupliquée et fournissent un diagnostic expurgé/action de réessai.
- [ ] Un redémarrage de l’APK restaure une session native existante, récupère un token frais et appelle FastAPI; aucune valeur raw token/session n’est persistée dans SharedPreferences.
- [ ] `Authorization: Bearer` est fourni par `getFreshToken` à FastAPI; FastAPI reste capable de refuser un token invalide par sa validation Clerk/JWKS existante.
- [ ] Sign out révoque la session Clerk courante, nettoie l’état Flutter/cache associé et bloque les appels authentifiés suivants.
- [ ] Le build/test web conserve ClerkJS, ses routes et le flux `/sso-callback` existants; Android ne modifie pas ce runtime.
- [ ] Les tests automatisés et la checklist Android réelle passent; logs, diagnostics et Sentry ne contiennent pas secrets, JWT, cookies, authorization codes, URI complète ou données personnelles inutiles.
- [ ] La configuration Google couvre la signature de l’APK réellement testée et la note de plateforme enregistre les contrôles et versions sans valeurs sensibles.

# Test Strategy

- Dart : `flutter analyze`; `flutter test test/core/app_access_resume_test.dart`; nouveaux tests `test/data/clerk_auth_service_android_test.dart` et `test/providers/auth_session_android_test.dart`; tests de l’écran entry ciblés.
- Android : `./gradlew :app:testDebugUnitTest`; task Android de build debug/release appropriée avec Dart defines masquées; `./gradlew :app:processDebugMainManifest` ou équivalent de manifest merge; tests instrumentés du callback si disponibles dans le projet.
- Web non-régression : `./scripts/validate-clerk-runtime.sh` avec clé fournie uniquement par l’environnement, puis preuve preview des routes auth sans copie de session.
- Device : appareil Android avec build signé/configuré, compte Google de test, backend de test/prod autorisé; documenter dans la checklist succès, cancel, redémarrage, callback externe requis, logout, token expiré/401 et build identity.
- Observabilité : inspecter « Copy access diagnostics » et vérifier build/Paris/UTC présents, mais absence de token/cookie/code/URI privée; vérifier les erreurs contrôlées dans Sentry/local logs seulement sous forme redacted.

# Risks

- **P1 / configuration externe** : Native API, redirect allowlist, clients Google et empreintes APK mal configurés peuvent laisser le bridge correct mais l’OAuth impossible. Mitigation : gate dashboard/configuration redacted avant test device et matrice debug/release.
- **P1 / secret leakage** : MethodChannel, diagnostics ou erreurs peuvent exposer un JWT/callback. Mitigation : contrat de données minimal, sanitize Kotlin/Dart, tests de redaction, interdiction de persistance.
- **P1 / session race** : `onNewIntent`, restore et bootstrap concurrents peuvent doubler navigation ou rétablir une session après logout. Mitigation : opération auth unique, idempotence, invalidation/annulation et tests de concurrence.
- **P1 / régression multi-plateforme** : changement du fichier conditionnel peut casser web/desktop. Mitigation : implémentations séparées, tests de compilation et validation ClerkJS conservée.
- **P2 / compatibilité SDK** : version Clerk, minSdk/AndroidX/Gradle peuvent entrer en conflit. Mitigation : pinner après vérification de compatibilité et bloquer l’implémentation si la contrainte ne tient pas.
- **P2 / signature release** : l’APK release actuel est configuré avec debug signing. Mitigation : ne pas étendre ce chantier au signing, mais ne pas déclarer la preuve release Google tant que la vraie signature distribution n’est pas configurée.

# Execution Notes

- Décision opérateur confirmée : adopter le SDK Android officiel Clerk encapsulé en Kotlin, pas le SDK Flutter bêta et pas un handoff web maison.
- Fresh-docs verdict : `fresh-docs checked` le 2026-07-30 contre les sources Clerk Android officielles et le code source du SDK épinglé. Les docs confirment l’API-only, l’initialisation Application, la gestion deep link Activity, `getToken`, `signOut` et la voie Google native. Le contrat effectif de `com.clerk:clerk-android-api:1.0.36` est `clerk://<applicationId>.callback`, reçu par `SSOReceiverActivity`; les exemples d’URL génériques ne doivent pas remplacer ce contrat vérifié. Recontrôler les versions avant modification Gradle, car le SDK évolue.
- Prévol Android nécessaire : inspecter le minSdk effectif généré par Flutter avant ajout; Clerk exige >=24 alors que le projet le délègue aujourd’hui à `flutter.minSdkVersion`.
- Ordre de lecture/implémentation : `build.gradle.kts` et manifest → `MainActivity` et channels existants → services Clerk Dart → `AuthSessionNotifier`/`ApiService` → écran entry/l10n → tests/checklist/docs. Stopper l’implémentation si Native API, la configuration Google/redirect ou une dépendance SDK officiellement compatible ne peut pas être prouvée; ne jamais substituer le chemin web ou un token URL comme contournement.
- Backend : aucune mutation FastAPI prévue; une incompatibilité de claims/issuer/JWKS révélée par une session native est un finding distinct à routage auth/backend, pas un contournement client.
- Observabilité : réutiliser `AppDiagnostics` et la surface « Copy access diagnostics »; les métadonnées build/Paris/UTC existent dans `AppConfig` et doivent rester les premières lignes des diagnostics copiés.
- Rollback : conserver le chemin web strictement inchangé. Si la version native/configuration échoue avant release, retirer le bouton/bridge Android derrière le changement, conserver le stub signed-out et la documentation de rollback; ne jamais faire basculer silencieusement Android vers une URL contenant un token. Après une release native, rollback consiste à désactiver le parcours Android dans une build suivante et/ou Native API selon les procédures Clerk, puis invalider/reconnecter les sessions affectées selon les capacités administratives Clerk — sans supprimer ni altérer les sessions web.

# Open Questions

None. Les paramètres opérateur matériels sont déterminés : Android natif Kotlin, Google, Clerk comme autorité d’identité, FastAPI comme autorité de données, et préservation du web ClerkJS. Les valeurs de dashboard, secrets et signatures sont des données d’exécution à configurer de façon sécurisée, pas des décisions de produit à laisser indéfinies.

# Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-07-18 | 100-sg-spec | GPT-5 Codex | Created Android native Clerk auth bridge implementation contract after repository and official-doc investigation. | implemented | 101-sg-ready |
| 2026-07-18 | 101-sg-ready | GPT-5 Codex | Reviewed structure, security boundaries, official Clerk Android freshness evidence, proof contract, adversarial cases, and metadata; corrected mechanical readiness details. | ready | 102-sg-start |
| 2026-07-18 | 102-sg-start | GPT-5 Codex | Implemented the Kotlin Clerk API-only bridge, Android configuration, Dart integration, unit coverage, diagnostics-safe documentation and manual device checklist. | implemented | 103-sg-verify |
| 2026-07-18 | 103-sg-verify | GPT-5 Codex | Standard verification: Flutter analyzer, focused Android bridge tests, app-access regression, and diff hygiene pass; Android Gradle/device OAuth, Clerk redirect dashboard, and web runtime proof remain unavailable here. | partial | 104-sg-end |
| 2026-07-18 | 104-sg-end | GPT-5 Codex | Closure bookkeeping prepared with evidence-based changelog and checklist; product closure deferred until required native/provider/device and web proof exists. | deferred | 005-sg-ship |
| 2026-07-18 | 109-sg-auth-debug + 106-sg-fix | GPT-5 Codex | Diagnosed the release-only Clerk initialization timeout from redacted device diagnostics and added the missing main-manifest INTERNET permission. | fix-attempted; release/device retest remains required | Build a release APK and retest Google return-to-app. |
| 2026-07-29 | 109-sg-auth-debug + 106-sg-fix | GPT-5 Codex | Replaced the retired One Tap helper with Clerk's native Google OAuth API; retained visible in-progress feedback. | implemented; device OAuth still failed before browser launch | Inspect the SDK callback contract and dashboard allowlist. |
| 2026-07-30 | 109-sg-auth-debug + 106-sg-fix + 004-sg-deploy | GPT-5 Codex | Corrected the callback contract to Clerk Android's own `clerk://com.contentglowz.app.callback` receiver, removed the incompatible Activity handler, updated docs, and produced a signed release APK. | fix-attempted; CI run 30550466642 passed with APK Signature Scheme v2 verification; physical OAuth proof remains required. | Set the exact Clerk redirect allowlist and test Google sign-in on Android. |
| 2026-07-30 | 900-shipglowz-core | GPT-5 Codex | Refreshed the shared Flutter/Clerk auth-debug reference with the pinned Android SDK 1.0.36 callback contract, dashboard prerequisites, redaction boundaries, and visible async-feedback requirements. | documented; no product code change; device/provider OAuth proof remains pending. | Reuse this reference for future Flutter + Clerk Android investigations. |
| 2026-07-30 | 103-sg-verify | GPT-5 Codex | Excellence pass: rechecked the shared reference, project callback consistency, Flutter analysis, focused Android bridge tests, diagnostics/redaction contract, and manual checklist state. | partial; standard local/docs gates pass, but all required device/provider/web checklist rows remain NOT_RUN, so no excellence or ship-readiness claim is made. | Route Android scenarios to 107-sg-test with the signed APK and configured Clerk instance; route web preview proof to 108-sg-browser/405-sg-prod. |

# Current Chantier Flow

| Step | Status | Evidence |
|------|--------|----------|
| 100-sg-spec | completed | This spec records the approved Kotlin-native Clerk direction, security boundaries, rollback and proof contract. |
| 101-sg-ready | ready | Structure, explicit security/data boundaries, official docs evidence, rollback, and device/web proof contract pass review. |
| 102-sg-start | implemented | Dart bridge tests and static analysis pass; Android Gradle/device proof is environment- and configuration-dependent. |
| 103-sg-verify | partial | Local Dart/static/regression checks pass; required native callback/provider/device and web runtime proof remains pending. |
| 104-sg-end | deferred | Bookkeeping is aligned, but the chantier remains open pending native/provider/device and web proof. |
| 005-sg-ship | partial | Commits are pushed and CI run 30550466642 produced a signed APK; provider/device proof remains pending. |
| 900-shipglowz-core | completed | Shared Clerk/Android reference refreshed and aligned with the shipped bridge and SDK 1.0.36 contract. |
| 103-sg-verify | partial | Excellence pass completed for docs/local proof; required Android provider/device and web preview evidence is still missing. |
