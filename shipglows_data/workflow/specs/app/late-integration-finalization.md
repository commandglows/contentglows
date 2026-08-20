---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.2.1"
project: app
created: "2026-04-25"
created_at: "2026-04-25 00:00:00 UTC"
updated: "2026-08-20"
updated_at: "2026-08-20 07:48:00 UTC"
status: reviewed
source_skill: sf-spec
source_model: "GPT-5"
scope: feature
owner: "Diane"
confidence: high
risk_level: high
security_impact: yes
docs_impact: yes
user_story: "En tant qu'utilisateur ContentGlows, je veux connecter et choisir les comptes sociaux autorises pour chaque projet, afin de publier un contenu approuve via Zernio sans exposer ni utiliser les comptes d'un autre projet."
linked_systems:
  - lab/api/routers/publish.py
  - lab/api/services/user_data_store.py
  - lab/api/dependencies/ownership.py
  - lab/api/main.py
  - lab/status/service.py
  - app/lib/data/services/api_service.dart
  - app/lib/data/models/app_settings.dart
  - app/lib/providers/providers.dart
  - app/lib/presentation/screens/settings/integrations_screen.dart
  - app/lib/presentation/screens/feed/feed_screen.dart
  - Zernio API
depends_on:
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/product/app/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/architecture.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "app/CLAUDE.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "Zernio Quickstart"
    artifact_version: "official docs 2026-04-28"
    required_status: "active"
  - artifact: "Zernio Connecting Accounts guide"
    artifact_version: "official docs 2026-04-28"
    required_status: "active"
  - artifact: "Zernio Error Handling guide"
    artifact_version: "official docs 2026-04-28"
    required_status: "active"
supersedes: []
evidence:
  - "Decision produit du 2026-04-28: garder une seule cle API Zernio serveur, mais ne jamais l'utiliser comme modele d'autorisation produit."
  - "Audit code du 2026-04-28: POST /api/publish verifie deja content_record_id possede, mais accounts/connect/disconnect/status restent provider-wide."
  - "Audit code du 2026-04-28: Flutter a deja PublishAccount, scheduleContent() utilise deja PATCH, et l'ecran cible est integrations_screen.dart."
  - "Documentation officielle Zernio consultee le 2026-04-28: Quickstart, Connecting Accounts, Error Handling."
next_step: "/sf-start Finaliser l'integration LATE/Zernio"
---

## Title

Finaliser l'integration LATE/Zernio par comptes sociaux scopes au projet

## Status

ready

## User Story

En tant qu'utilisateur ContentGlows, je veux connecter et choisir les comptes sociaux autorises pour chaque projet, afin de publier un contenu approuve via Zernio sans exposer ni utiliser les comptes d'un autre projet.

## Minimal Behavior Contract

Quand un utilisateur authentifie configure les integrations d'un projet ou approuve un contenu publiable, ContentGlows accepte seulement les comptes sociaux Zernio explicitement lies a cet utilisateur et a ce projet, affiche les comptes disponibles dans l'UI du projet actif, publie ou programme le contenu avec les vrais `accountId` autorises, puis rend observable le resultat par statut, URL, erreur ou action de reprise. Si aucun compte autorise n'existe, si un `accountId` est forge, si Zernio echoue, ou si plusieurs comptes rendent la cible ambigue, le systeme n'appelle pas Zernio a l'aveugle, n'expose pas les comptes provider-wide, conserve un etat recuperable, et explique l'action possible; l'edge case principal est le succes partiel multi-plateforme, qui doit rester distinct d'un succes complet.

## Success Behavior

Preconditions:
- L'utilisateur est authentifie par Clerk.
- Le projet cible appartient a `current_user.user_id`.
- Le contenu cible appartient au projet cible et est en etat publiable (`approved` ou `scheduled` selon le mode).
- Chaque cible de publication reference un `ProjectPublishAccount` actif pour `current_user.user_id`, `project_id`, `provider = zernio`, `platform`, et `providerAccountId`.
- `ZERNIO_API_KEY` est configuree cote serveur uniquement.

Action:
- Dans Settings, l'utilisateur demande les comptes du projet actif ou lance une connexion/reconnexion de plateforme.
- Dans le flow d'approbation, l'utilisateur approuve un contenu avec des channels publies par Zernio.

Resultat utilisateur/operateur:
- Settings affiche uniquement les comptes autorises du projet actif avec plateforme, libelle, statut, et compte par defaut quand applicable.
- Le flow approve/publish publie ou programme uniquement vers les comptes autorises selectionnes ou par defaut.
- Le feedback distingue `published`, `scheduled`, `partial`, `failed`, `forbidden`, `missing_account`, `ambiguous_account`, `timeout`, et `provider_error`.
- Le flow connect cree une session serveur liee a `user_id + project_id + platform + zernioProfileId`, envoie a Zernio un `redirect_url` avec `state` opaque, puis lie les comptes seulement apres validation et consommation du `state`.

Effet systeme attendu:
- `POST /api/publish` conserve `require_owned_content_record()` et verifie chaque cible via le mapping local avant tout appel Zernio.
- Chaque projet ContentGlows possede ou reference un `zernioProfileId` persiste cote serveur; ce `profileId` n'est jamais global par defaut ni fourni par Flutter.
- Les sessions OAuth sont serveur-side, a usage unique, expirees en 15 minutes maximum, et rejettent replay, mauvais user, mauvais projet, mauvaise plateforme ou state inconnu.
- Les metadonnees persistantes du `ContentRecord` incluent au minimum `provider`, `providerPostId`, statut global, statuts par plateforme, erreurs stables Zernio (`type`, `code`, `param` si present), URLs publiees, `scheduledFor`, `syncedAt`, et information de retry si disponible.
- Les appels accounts/connect/disconnect/status sont scopes par user/projet et ne renvoient jamais de liste brute provider-wide.

Preuve de succes:
- Tests backend prouvent que les comptes d'un autre projet sont invisibles et inutilisables, et que Zernio n'est pas appele en cas de mapping invalide.
- Tests Flutter prouvent que l'UI Settings et `approve()` utilisent le projet actif et affichent un feedback recuperable.
- Verification manuelle publie vers un compte autorise et voit le statut/URL persiste.

## Error Behavior

Entrees invalides ou etats d'echec:
- utilisateur non authentifie;
- projet inexistant ou non possede;
- contenu inexistant, non possede, deja en publication, ou dans un etat non publiable;
- `platform` hors allowlist;
- `accountId` absent, forge, inactif, supprime, ambigu, ou lie a un autre projet;
- `ZERNIO_API_KEY` absente ou invalide;
- Zernio retourne `authentication_error`, `permission_error`, `rate_limit_error`, `platform_error`, `api_error`, `partial`, `failed`, timeout, ou reponse inattendue.

Retour utilisateur/operateur:
- `401` si non authentifie, `403` si le projet/contenu/compte n'est pas autorise, `400` ou `422` si la requete est invalide, `409` si une publication concurrente ou duplicate est detectee, `502`/`503` si le provider est indisponible.
- Le callback de connexion retourne une erreur recuperable et ne cree aucun mapping si le `state` est absent, expire, deja consomme, ou ne correspond pas au user/projet/platform attendu.
- Flutter affiche une erreur exploitable et laisse le contenu recuperable; il ne masque pas un echec derriere un statut "published".

Effet systeme attendu:
- Aucun compte non autorise n'est expose ou utilise.
- Aucun compte Zernio retourne apres OAuth n'est lie sans session serveur valide et sans verification qu'il appartient au `zernioProfileId` du projet.
- Aucun secret Zernio n'est renvoye, stocke dans Flutter, loggue, ou inclus dans un message utilisateur.
- Les erreurs Zernio sont mappees par `type` et `code`, jamais par texte libre.
- Un timeout apres soumission cree un etat `publish_status = reconciliation_pending` ou equivalent avec reconciliation par `GET /api/publish/status/{post_id}` si un `post_id` est connu.
- Les webhooks ne sont pas implementes dans ce chantier; s'ils sont ajoutes plus tard, ils devront etre authentifies, deduples, et scopes au mapping local avant mise a jour.

Ce qui ne doit jamais arriver:
- appeler `POST /v1/posts` Zernio avant validation locale user/projet/compte;
- exposer au client des comptes Zernio provider-wide;
- supprimer un item de review comme publie quand le resultat est partiel, echoue, ou inconnu;
- permettre a un projet A de lister, selectionner, publier, deconnecter ou status-checker un compte du projet B.

## Problem

L'integration LATE/Zernio existe partiellement: le backend expose des endpoints de publication, Flutter possede des services et providers de publication, et l'action d'approbation tente de publier. Le risque actuel est que la cle Zernio serveur donne acces a une vue provider-wide des comptes, alors que le produit doit isoler les comptes sociaux par utilisateur et par projet. Sans mapping local strict, l'UI peut mentir, un compte social peut etre utilise hors projet, les erreurs provider peuvent etre avalees, et un succes partiel peut etre confondu avec une publication complete.

## Solution

Creer un contrat serveur `ProjectPublishAccount` qui lie les comptes Zernio a `user_id + project_id`, puis convertir tous les endpoints publish en contrats scopes au projet avant de cabler l'UI Flutter. La cle Zernio reste une configuration serveur partagee, mais l'autorisation produit est decidee par ContentGlows: seuls les comptes actifs lies au projet courant peuvent etre listes, connectes, deconnectes, status-checkes, publies ou retries.

Le flow de connexion utilise un profil Zernio par projet ContentGlows. Le backend cree ou recupere ce `zernioProfileId`, cree une session `PublishConnectSession` serveur-side avec `state` opaque a usage unique, appelle Zernio `GET /v1/connect/{platform}` avec ce `profileId` et un `redirect_url` ContentGlows, puis le callback ContentGlows valide le `state` avant de reconciler `GET /v1/accounts` et de creer les `ProjectPublishAccount` correspondant au profil/projet. Flutter ne fournit jamais de `profileId` et ne peut pas decider le projet d'un callback.

## Scope In

- Mapping local `ProjectPublishAccount` pour Zernio avec user, projet, plateforme, compte provider, statut et compte par defaut.
- Mapping local `ProjectPublishProfile` ou champ equivalent pour `userId + projectId + provider -> zernioProfileId`.
- Session locale `PublishConnectSession` pour proteger le redirect OAuth: `state`, user, projet, plateforme, profile, expiration, consommation.
- Endpoints backend project-scoped pour lister les comptes, demarrer une connexion Zernio, synchroniser/lier un compte, unlink local, publier/programmer, lire le statut, et eventuellement retry.
- Refus backend d'un `accountId` non autorise avant tout appel Zernio.
- Persistance des metadonnees de publication et des resultats par plateforme.
- Flutter: API service, providers Riverpod, Settings integrations, feedback feed/review.
- Gestion des erreurs, succes partiel, timeout, duplicate submit, compte manquant, compte ambigu.
- Tests backend et Flutter cibles.
- Documentation README/setup/verification.

## Scope Out

- Billing, quotas commerciaux et plans payants.
- Auth multi-tenant organisationnel complet au-dela du couple Clerk user + project ownership existant.
- Analytics post-publication avancees.
- Preview avancee par plateforme.
- Upload media Zernio et transformations media.
- Webhooks Zernio en production; seulement documenter la contrainte future.
- Suppression provider-wide d'un compte Zernio depuis ContentGlows; ce chantier fait un unlink local sauf preuve explicite de propriete exclusive.
- Support WordPress et Ghost via Zernio. Pour ce chantier, WordPress/Ghost restent exclus du publish auto et doivent afficher "non supporte par cette integration".

## Constraints

- Ne pas exposer `ZERNIO_API_KEY` ou `LATE_API_KEY` au client Flutter.
- Conserver `require_current_user`, `require_owned_content_record()` et les patterns d'ownership existants.
- Respecter les conventions Turso/libSQL du backend: migration versionnee ou ensure idempotent au startup, selon le pattern deja present.
- Ne pas ajouter de nouvelle abstraction globale si `user_data_store.py` et les services existants suffisent.
- Ne pas brancher l'UI sur une liste provider-wide.
- Ne pas traiter WordPress/Ghost comme des plateformes Zernio tant qu'un contrat dedie n'existe pas.
- Ne pas supposer qu'un compte Zernio est propre, actif, ou accessible uniquement parce que Zernio le retourne.
- Ne jamais accepter `profileId` depuis Flutter; le backend le cree/recupere depuis le projet possede.
- Ne jamais lier un compte apres OAuth sans `state` serveur valide, non expire et non consomme.
- Garder les erreurs utilisateur actionnables sans divulguer les payloads sensibles provider.

## Dependencies

Local:
- `shipglows_data/business/business.md` v1.0.0 reviewed: parcours createur et contraintes business.
- `shipglows_data/product/app/product.md` v1.0.0 reviewed: multi-projet et limites produit.
- `shipglows_data/technical/app/architecture.md` v1.0.0 reviewed: Flutter + FastAPI + Clerk, providers, offline/degraded mode.
- `shipglows_data/technical/app/guidelines.md` v1.0.0 reviewed: auth, tests, offline/sync.
- `app/CLAUDE.md` v1.0.0 reviewed: commandes, structure, Turso/libSQL.

External docs freshness:
- Verdict: `fresh-docs checked`.
- Source officielle: Zernio Quickstart, https://docs.zernio.com/ consulte le 2026-04-28. Regles utilisees: base URL `https://zernio.com/api/v1`, auth Bearer `ZERNIO_API_KEY`, concepts Profiles/Accounts/Posts, `GET /v1/accounts`, `POST /v1/posts`, `publishNow` et `scheduledFor`.
- Source officielle: Zernio Connecting Accounts, https://docs.zernio.com/guides/connecting-accounts consulte le 2026-04-28. Regles utilisees: `GET /v1/connect/{platform}` avec `profileId`, retour `authUrl`, redirect `redirect_url`, plateformes a selection secondaire.
- Source officielle: Zernio Error Handling, https://docs.zernio.com/guides/error-handling consulte le 2026-04-28. Regles utilisees: erreurs stables `type`/`code`, statuts `published`/`partial`/`failed`, erreurs par plateforme, retry, webhooks at-least-once.

## Invariants

- L'identite est toujours `current_user.user_id` issue de Clerk cote backend.
- Un `project_id` utilise par publish doit appartenir au user courant.
- Un `content_record_id` utilise par publish doit appartenir au user courant via son projet.
- Un `providerAccountId` Zernio n'est utilisable que s'il existe dans `ProjectPublishAccount` avec `user_id`, `project_id`, `provider = zernio`, `platform`, `status = active`.
- Un `zernioProfileId` est un attribut serveur du projet ContentGlows; il ne peut pas etre choisi par le client et ne doit pas etre reutilise entre projets sauf decision explicite future hors scope.
- Une session connect est valide uniquement pour le tuple `state + user_id + project_id + provider + platform + zernioProfileId`, expire en 15 minutes maximum, et devient inutilisable apres consommation.
- `GET /api/publish/accounts` retourne seulement les mappings locaux autorises du projet demande; il peut enrichir par Zernio cote serveur, mais ne renvoie jamais la liste brute provider-wide.
- Une cible de publication non autorisee produit `403` avant tout appel Zernio.
- Un seul compte par defaut est autorise par tuple `user_id + project_id + provider + platform`; plusieurs comptes par plateforme sont possibles seulement par selection explicite dans la requete.
- Les operations publish sont idempotentes ou rejetees proprement quand un contenu est deja `publishing`, `published`, ou lie a un `providerPostId` actif.
- Les secrets restent serveur-only.

## Links & Consequences

Upstream:
- Clerk auth et `require_current_user`.
- Ownership helpers dans `lab/api/dependencies/ownership.py`.
- Zernio API pour profiles, accounts, connect, posts, status/retry.
- Turso/libSQL pour persistance user/project/content metadata.

Downstream:
- Flutter `activeProjectProvider`, Settings integrations, feed/review approval flow.
- `ContentRecord.metadata["publish"]`, `target_url`, lifecycle status, et affichage des resultats.
- README et verification manuelle d'exploitation.

Consequences transverses:
- Security: reduit le risque IDOR et l'exposition provider-wide.
- Data: ajoute une structure persistante project-scoped; necessite migration/ensure.
- UX: l'utilisateur voit comptes reels, erreurs recuperables, succes partiels.
- Ops: documentation env et checklist requises; logs d'audit sans secrets.
- Perf/disponibilite: timeout/rate limit Zernio doivent eviter les boucles et fan-out non controle.
- Future webhooks: hors scope, mais toute future implementation doit deduper et verifier le mapping local.

## Documentation Coherence

- `app/README.md`: ajouter `ZERNIO_API_KEY`, base URL, flow de connexion, plateformes supportees, WordPress/Ghost non supportes par Zernio dans ce chantier, checklist manuelle.
- `shipglows_data/technical/app/architecture.md`: mettre a jour si un nouveau modele/table `ProjectPublishAccount` devient un contrat durable.
- `app/.env.example`: ajouter ou verifier `ZERNIO_API_KEY` si absent.
- `app/CHANGELOG.md`: noter l'integration Zernio project-scoped une fois implementee.
- Support/onboarding: aucune FAQ dediee dans le repo; si une doc support existe plus tard, elle devra reprendre les erreurs `missing_account`, `partial`, `failed`, `forbidden`.

## Edge Cases

- Projet A et Projet B du meme user ont des comptes differents pour la meme plateforme.
- Plusieurs comptes actifs existent pour une plateforme; auto-publish ne choisit que le compte marque default, sinon demande selection explicite.
- `accountId` forge existe chez Zernio mais pas dans le mapping local.
- Compte mappe localement mais supprime, expire, ou unhealthy chez Zernio.
- Zernio retourne `partial`: certaines plateformes ont `platformPostUrl`, d'autres ont `error`.
- Zernio retourne `failed` ou `platform_error` pour contenu invalide.
- Timeout apres `POST /v1/posts`: si `providerPostId` est inconnu, l'etat reste recuperable sans retry automatique aveugle; si connu, status reconciliation.
- Double clic approve/publish: idempotence par etat ou `409`.
- App offline ou API indisponible: afficher degraded state, ne pas simuler une publication.
- WordPress/Ghost dans les channels: exclus avec message clair.
- Connect flow pour plateformes a selection secondaire: utiliser le mode standard Zernio dans ce chantier; headless reste hors scope.
- Callback OAuth rejoue deux fois avec le meme `state`: le second appel est refuse sans modifier les mappings.
- Callback OAuth arrive avec un `state` valide mais une session dont le projet n'appartient plus au user: refuser et ne rien lier.
- Un profil Zernio existe deja pour le projet: le backend le reutilise; sinon il le cree cote Zernio et le persiste avant connect.

Endpoint contract:

| Endpoint | Auth | Scope input | Success | Failure |
|----------|------|-------------|---------|---------|
| `GET /api/publish/accounts?project_id=...` | Clerk required | `project_id` possede | comptes locaux autorises du projet | `401`, `403`, degraded si enrichissement provider echoue |
| `GET /api/publish/connect/{platform}?project_id=...` | Clerk required | `project_id` possede, platform allowlist | `{ authUrl, stateExpiresAt }`; session serveur creee | `401`, `403`, `422`, provider error mappee |
| `GET /api/publish/connect/callback?state=...` | state serveur requis | session connect non expiree | mapping local cree/reconcilie, redirection UI Settings | `400`, `403`, `409` replay/expire/mismatch |
| `DELETE /api/publish/accounts/{account_id}?project_id=...` | Clerk required | mapping local actif du projet | unlink local | `401`, `403`, `404`; pas de delete provider-wide |
| `POST /api/publish` | Clerk required | `content_record_id` possede + comptes autorises | post publie/programme, metadata persistee | `400`, `401`, `403`, `409`, `429`, `502`, `503` |
| `GET /api/publish/status/{post_id}` | Clerk required | `post_id` associe a content record possede | statut reconcilie | `401`, `403` ou `404`, provider error mappee |

## Implementation Tasks

- [ ] Tache 1 : Definir et persister `ProjectPublishAccount`
  - Fichier : `lab/api/services/user_data_store.py`
  - Action : Ajouter les fonctions de stockage/lecture du mapping local avec champs `id`, `userId`, `projectId`, `provider`, `platform`, `providerAccountId`, `zernioProfileId`, `displayName`, `username`, `status`, `isDefault`, `createdAt`, `updatedAt`, `lastSyncedAt`.
  - User story link : etablit la liste des comptes autorises par projet.
  - Depends on : None.
  - Validate with : test unitaire/service qui cree deux projets avec comptes differents et relit uniquement le projet cible.
  - Notes : Ajouter une contrainte unique logique sur `userId + projectId + provider + providerAccountId`; un seul default actif par plateforme.

- [ ] Tache 2 : Definir et persister `ProjectPublishProfile` et `PublishConnectSession`
  - Fichier : `lab/api/services/user_data_store.py`
  - Action : Ajouter `ProjectPublishProfile` pour `userId + projectId + provider -> zernioProfileId` et `PublishConnectSession` pour `state`, `userId`, `projectId`, `provider`, `platform`, `zernioProfileId`, `expiresAt`, `consumedAt`.
  - User story link : garantit que la connexion OAuth rattache un compte au bon projet.
  - Depends on : Tache 1.
  - Validate with : tests creation/reuse profile, expiration session, replay refuse, mismatch user/projet refuse.
  - Notes : Le `state` est opaque, aleatoire, stocke serveur, usage unique, et expire en 15 minutes maximum.

- [ ] Tache 3 : Ajouter migration ou ensure idempotent du mapping
  - Fichier : `lab/api/main.py` et migration a creer sous `lab/api/migrations/`
  - Action : Initialiser les tables ou structures persistantes `ProjectPublishAccount`, `ProjectPublishProfile`, `PublishConnectSession` selon les patterns Turso/libSQL existants.
  - User story link : rend le contrat durable et testable hors memoire.
  - Depends on : Taches 1-2.
  - Validate with : demarrage backend/test migration sans erreur et schema relu.
  - Notes : Ne pas casser les schemas `UserSettings`, `Project`, ou `content_records`.

- [ ] Tache 4 : Centraliser l'autorisation de compte publish
  - Fichier : `lab/api/dependencies/ownership.py`
  - Action : Ajouter ou exposer un helper qui valide `current_user.user_id + project_id + providerAccountId + platform` et retourne le mapping actif.
  - User story link : empeche l'utilisation d'un compte d'un autre projet.
  - Depends on : Taches 1-3.
  - Validate with : test `accountId` forge retourne `403` avant mock Zernio.
  - Notes : Reutiliser `require_owned_project_id()` et `require_owned_content_record()`.

- [ ] Tache 5 : Rendre `/api/publish/accounts` project-scoped
  - Fichier : `lab/api/routers/publish.py`
  - Action : Exiger `project_id`, verifier ownership, retourner uniquement les `ProjectPublishAccount` actifs du projet, enrichis si necessaire par statut provider.
  - User story link : l'UI Settings affiche les comptes reels du projet actif.
  - Depends on : Taches 1-4.
  - Validate with : integration test Project A/B; aucun compte provider-wide n'est renvoye.
  - Notes : Si Zernio est indisponible, retourner les mappings locaux avec statut degraded plutot qu'exposer une erreur brute.

- [ ] Tache 6 : Rendre connect/reconnect et callback project-scoped
  - Fichier : `lab/api/routers/publish.py`
  - Action : Adapter `GET /api/publish/connect/{platform}` pour exiger `project_id`, verifier ownership, creer/recuperer `zernioProfileId`, creer `PublishConnectSession`, appeler Zernio `GET /v1/connect/{platform}` avec `profileId`, `redirect_url` et `state`; ajouter `GET /api/publish/connect/callback` qui valide/consomme `state`, reconcilie `GET /v1/accounts`, filtre par `zernioProfileId`/platform, puis cree les mappings locaux.
  - User story link : l'utilisateur connecte un compte au projet actif.
  - Depends on : Taches 1-5.
  - Validate with : tests auth URL retournee, state expire/replay/mismatch refuses, mapping cree seulement pour le projet courant, mauvais project/user impossible.
  - Notes : Utiliser le flow standard Zernio; headless et selection secondaire custom hors scope. Flutter ne passe jamais `profileId`.

- [ ] Tache 7 : Rendre unlink/disconnect local et project-scoped
  - Fichier : `lab/api/routers/publish.py`
  - Action : Remplacer toute suppression provider-wide par un unlink local sauf preuve de propriete exclusive; verifier `project_id` et mapping avant action.
  - User story link : evite de casser les comptes d'autres projets.
  - Depends on : Taches 1-6.
  - Validate with : test Project A ne peut pas unlink Project B; Zernio delete n'est pas appele.
  - Notes : Documenter explicitement si une suppression provider devient future scope.

- [ ] Tache 8 : Durcir `POST /api/publish`
  - Fichier : `lab/api/routers/publish.py`
  - Action : Conserver `require_owned_content_record()`, resoudre `project_id`, verifier chaque cible via `ProjectPublishAccount`, appliquer allowlist plateformes, gerer duplicate/concurrent state, puis appeler Zernio `POST /v1/posts` avec `platforms: [{ platform, accountId }]`.
  - User story link : publie uniquement vers les comptes autorises du projet.
  - Depends on : Taches 1-4.
  - Validate with : tests `403 before provider call`, success, scheduled, duplicate `409`.
  - Notes : `publishNow` et `scheduledFor` sont mutuellement controles par le backend; ne pas accepter de payload libre non valide.

- [ ] Tache 9 : Persister les resultats publish detailles
  - Fichier : `lab/status/service.py` et `lab/api/routers/publish.py`
  - Action : Stocker `providerPostId`, `publishStatus`, `scheduledFor`, `syncedAt`, `platformResults[]`, `platformPostUrl`, erreurs `type/code/param/platform`, et `target_url` principal si publie.
  - User story link : l'utilisateur peut verifier le resultat ou reprendre une erreur.
  - Depends on : Tache 8.
  - Validate with : tests `published`, `partial`, `failed`, timeout connu/inconnu.
  - Notes : `partial` ne transitionne pas comme succes complet silencieux.

- [ ] Tache 10 : Rendre status/retry scopes au contenu possede
  - Fichier : `lab/api/routers/publish.py`
  - Action : Pour `GET /api/publish/status/{post_id}` et retry si expose, verifier que `post_id` est stocke sur un content record possede par le user/projet avant appel Zernio.
  - User story link : empeche la lecture ou reprise de posts d'un autre projet.
  - Depends on : Taches 8-9.
  - Validate with : test `post_id` d'un autre projet retourne `403` ou `404` sans provider call.
  - Notes : Aucun webhook dans ce chantier.

- [ ] Tache 11 : Aligner `ApiService` Flutter sur les contrats project-scoped
  - Fichier : `app/lib/data/services/api_service.dart`
  - Action : Ajouter/adapter les methodes accounts/connect/unlink/publish/status avec `projectId`, modeles typed, et mapping `ApiException`.
  - User story link : le client appelle les contrats serveur securises.
  - Depends on : Taches 5-10.
  - Validate with : tests parsing success/error et absence de logique basee sur texte d'erreur provider.
  - Notes : `scheduleContent()` utilise deja PATCH; ne pas recreer cette correction obsolette.

- [ ] Tache 12 : Adapter les modeles Flutter
  - Fichier : `app/lib/data/models/app_settings.dart`
  - Action : Etendre ou confirmer `PublishAccount`/`ChannelConfig` avec `projectId`, `provider`, `platform`, `accountId`, `displayName`, `username`, `status`, `isDefault`, et resultats publish si necessaire.
  - User story link : represente plusieurs comptes par projet et plateforme.
  - Depends on : Tache 11.
  - Validate with : tests `fromJson/toJson` comptes multiples et statuts.
  - Notes : Ne pas stocker de secret.

- [ ] Tache 13 : Adapter les providers Riverpod au projet actif
  - Fichier : `app/lib/providers/providers.dart`
  - Action : Charger les comptes par `activeProjectProvider`, resoudre les cibles de publish par default ou selection explicite, bloquer `missing_account` et `ambiguous_account`, et gerer `partial/failed/timeout`.
  - User story link : l'approbation utilise le projet actif et rend les erreurs visibles.
  - Depends on : Taches 11-12.
  - Validate with : tests providers Project A/B, aucun compte, compte ambigu, succes partiel.
  - Notes : WordPress/Ghost exclus du publish auto avec message clair.

- [ ] Tache 14 : Finaliser l'UI Settings integrations
  - Fichier : `app/lib/presentation/screens/settings/integrations_screen.dart`
  - Action : Afficher loading/error/empty/degraded, comptes reels du projet actif, default par plateforme, connect/reconnect/unlink local, et messages WordPress/Ghost non supportes.
  - User story link : l'utilisateur sait quel compte est disponible pour ce projet.
  - Depends on : Taches 11-13.
  - Validate with : widget tests ou smoke manuel Settings online/error/empty.
  - Notes : Pas de badge "Connected" hardcode.

- [ ] Tache 15 : Adapter le feedback feed/review
  - Fichier : `app/lib/presentation/screens/feed/feed_screen.dart`
  - Action : Afficher succes, scheduled, partial, failed, missing account, forbidden, timeout, et action de retry/ouvrir Settings quand applicable.
  - User story link : le resultat publish est observable et recuperable.
  - Depends on : Taches 13-14.
  - Validate with : tests ou sanity manuel approve/publish; un echec ne disparait pas silencieusement.
  - Notes : Ne pas marquer published si `partial`, `failed`, ou `reconciliation_pending`.

- [ ] Tache 16 : Ajouter tests backend de securite et provider
  - Fichier : `lab/tests/integration/test_publish_router.py`
  - Action : Couvrir auth, ownership, account authorization, accounts project-scoped, connect project-scoped, unlink local, publish success, partial, failed, timeout, duplicate, scheduled, status scoped.
  - User story link : prouve que l'isolation projet tient.
  - Depends on : Taches 1-10.
  - Validate with : `pytest lab/tests/integration/test_publish_router.py`.
  - Notes : Mock `httpx.AsyncClient`; verifier explicitement "provider not called" sur `403`.

- [ ] Tache 17 : Ajouter tests Flutter cibles
  - Fichier : `app/test/data/`, `app/test/core/`, `app/test/presentation/settings/`
  - Action : Tester parsing accounts, providers par projet actif, approve/publish success/error/partial, Settings states.
  - User story link : prouve que le client ne bypasse pas le contrat backend.
  - Depends on : Taches 11-15.
  - Validate with : `flutter test`.
  - Notes : Prioriser logique provider avant tests visuels lourds.

- [ ] Tache 18 : Mettre a jour docs et env example
  - Fichier : `app/README.md`, `app/.env.example`, `app/CHANGELOG.md`
  - Action : Documenter `ZERNIO_API_KEY`, flow profile/account/post, plateformes supportees, WordPress/Ghost exclus, verification manuelle, erreurs attendues.
  - User story link : un operateur peut configurer et verifier l'integration sans historique.
  - Depends on : Taches 1-17.
  - Validate with : lecture README par agent frais et checklist manuelle.
  - Notes : Ne jamais inclure une vraie cle.

## Acceptance Criteria

- [ ] CA1 : Given Project A et Project B ont des comptes Zernio differents, when l'utilisateur ouvre Settings sur Project A, then `/api/publish/accounts?project_id=A` retourne et affiche uniquement les comptes autorises de Project A.
- [ ] CA2 : Given un utilisateur forge un `accountId` Zernio non mappe au projet du contenu, when `POST /api/publish` est appele, then le backend retourne `403` avant tout appel Zernio.
- [ ] CA3 : Given un contenu Twitter approuve et un compte Twitter default actif pour le projet, when l'utilisateur approuve, then ContentGlows appelle Zernio avec `platforms: [{ platform: "twitter", accountId }]` et persiste `providerPostId`, statut, URL ou erreur.
- [ ] CA3b : Given l'utilisateur lance Connect depuis Project A, when Zernio redirige vers le callback ContentGlows, then le backend valide un `state` serveur non expire lie a `userId + Project A + platform + zernioProfileId`, consomme ce `state`, et cree seulement des mappings Project A.
- [ ] CA3c : Given un callback Connect rejoue le meme `state`, utilise un `state` expire, ou tente de lier Project B, when le callback est appele, then le backend refuse sans creer ni modifier de mapping.
- [ ] CA4 : Given plusieurs comptes Twitter actifs sans default ni selection explicite, when l'auto-publish tente de resoudre la cible, then aucun appel Zernio n'est fait et l'utilisateur voit `ambiguous_account`.
- [ ] CA5 : Given aucun compte autorise pour un channel requis, when l'utilisateur approuve, then l'approbation reste recuperable et le feedback propose de connecter un compte sans publication aveugle.
- [ ] CA6 : Given Zernio retourne `partial`, when le backend persiste le resultat, then l'UI affiche un succes partiel avec details par plateforme et ne marque pas le contenu comme succes complet.
- [ ] CA7 : Given Zernio retourne `failed`, `platform_error`, `rate_limit_error`, ou timeout, when le flow publish se termine, then l'erreur est mappee par `type/code`, sans secret, avec etat recuperable.
- [ ] CA8 : Given un post Zernio existe pour un autre projet, when un utilisateur appelle status/retry avec ce `post_id`, then ContentGlows refuse sans exposer le statut provider.
- [ ] CA9 : Given une publication programmee, when le backend appelle Zernio, then `scheduledFor` et `providerPostId` sont persistants et le statut reste verifiable.
- [ ] CA10 : Given l'utilisateur clique deux fois sur publish, when le premier appel est en cours ou deja finalise, then le second appel est idempotent ou retourne `409` sans doublon provider.
- [ ] CA11 : Given WordPress ou Ghost est selectionne, when le flow auto-publish s'execute, then ces channels sont exclus avec message explicite "non supporte par Zernio dans ce chantier".
- [ ] CA12 : Given un agent frais lit la spec et le README mis a jour, when il doit lancer et verifier l'integration, then il trouve fichiers, env vars, endpoints, sources Zernio, tests et checklist sans historique de conversation.

## Test Strategy

Backend:
- `pytest lab/tests/integration/test_publish_router.py`.
- Mock `httpx.AsyncClient` pour Zernio accounts/connect/posts/status.
- Verifier explicitement auth required, ownership required, account mapping required, connect state valid/expired/replayed/mismatched, `403 before provider call`, partial, failed, timeout, duplicate, scheduled, status scoped.

Flutter:
- `flutter test` depuis `app`.
- Tests modeles pour parsing comptes et resultats publish.
- Tests providers pour active project, mapping comptes, missing/ambiguous account, partial/failed.
- Tests UI Settings pour loading/error/empty/degraded et comptes reels.

Manual:
- Configurer `ZERNIO_API_KEY` serveur.
- Creer deux projets avec comptes differents.
- Connecter un compte social au projet actif via flow Zernio standard.
- Verifier Settings, approuver un contenu Twitter/LinkedIn, confirmer statut/URL.
- Tenter un `accountId` d'un autre projet et confirmer `403`.
- Simuler provider error/timeout et verifier feedback recuperable.

## Risks

- Risque high: une cle Zernio serveur partagee donne une vue provider-wide; mitigation par mapping local et refus avant provider call.
- Risque high: IDOR sur account/status/disconnect si un endpoint oublie le scope projet; mitigation par helper ownership central et tests `provider not called`.
- Risque high: OAuth callback peut lier un compte au mauvais projet si `state`/profile ne sont pas serveur-side; mitigation par `ProjectPublishProfile`, `PublishConnectSession` usage unique, expiration et tests replay/mismatch.
- Risque medium: Zernio peut retourner `partial` ou etat inconnu; mitigation par persistance detaillee et feedback recuperable.
- Risque medium: multi-account par plateforme peut creer une cible ambigue; mitigation par default unique ou selection explicite.
- Risque medium: connect OAuth avec selection secondaire peut necessiter un flow plus riche; mitigation par flow standard Zernio et headless hors scope.
- Risque medium: migration Turso/libSQL peut diverger entre local/prod; mitigation par ensure idempotent et tests startup.
- Risque low: docs env inexactes; mitigation par README/.env.example et checklist.

## Execution Notes

Lire d'abord:
- `lab/api/routers/publish.py`
- `lab/api/dependencies/ownership.py`
- `lab/api/services/user_data_store.py`
- `lab/status/service.py`
- `lab/api/main.py`
- `app/lib/data/services/api_service.dart`
- `app/lib/data/models/app_settings.dart`
- `app/lib/providers/providers.dart`
- `app/lib/presentation/screens/settings/integrations_screen.dart`
- `app/lib/presentation/screens/feed/feed_screen.dart`
- `lab/tests/integration/test_publish_router.py`

Approche avant code:
1. Construire le contrat backend et les tests de securite avant toute UI.
2. Ajouter le mapping local, le profil Zernio par projet, les sessions connect et l'autorisation centralisee.
3. Convertir les endpoints provider-wide en endpoints project-scoped, callback inclus.
4. Persister les resultats publish et leurs erreurs.
5. Brancher Flutter sur les contrats scopes.
6. Ajouter feedback UI, tests, docs.

Packages/patterns:
- Reutiliser `httpx.AsyncClient` existant pour Zernio.
- Reutiliser Dio/`ApiException` cote Flutter.
- Reutiliser Riverpod et `activeProjectProvider`.
- Eviter d'ajouter un SDK Zernio tant que le router existant couvre les appels REST.
- Eviter un store Flutter parallele aux providers existants.

Commandes de validation:
- `pytest lab/tests/integration/test_publish_router.py`
- `flutter test` dans `app`
- Sanity manuel backend avec `ZERNIO_API_KEY` configuree.

Stop conditions:
- Un endpoint publish expose encore une liste provider-wide.
- Un `accountId` invalide peut atteindre Zernio.
- Un callback connect peut lier un compte sans `state` serveur valide.
- Flutter fournit ou influence directement un `zernioProfileId`.
- Une vraie cle ou payload sensible apparait dans logs, responses, docs, ou tests.
- Une decision de scope force a supporter WordPress/Ghost via Zernio dans ce chantier.
- Les tests ne peuvent pas prouver l'isolation Project A / Project B.

## Open Questions

None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-04-28 02:25 | continue | GPT-5 | Ajout de la decision cle Zernio partagee + mapping comptes sociaux par user/projet | Spec mise a jour en 1.1.0 | /sf-ready shipglows_data/workflow/specs/app/late-integration-finalization.md |
| 2026-04-28 02:32 | sf-ready | GPT-5 | Gate readiness stricte avant implementation | not ready: sections DoR obligatoires, contrats comportementaux, docs freshness et decisions produit manquants | /sf-spec Finaliser l'integration LATE/Zernio |
| 2026-04-28 06:11 | sf-spec | GPT-5 | Refonte complete de la spec avec faits code, docs Zernio officielles, decisions security et taches ordonnees | reviewed | /sf-ready Finaliser l'integration LATE/Zernio |
| 2026-04-28 06:20 | sf-ready | GPT-5 | Gate readiness finale apres audit sous-agent et correction OAuth/profile/state | ready | /sf-start Finaliser l'integration LATE/Zernio |
| 2026-04-28 06:47 | sf-start | GPT-5.4 | Implementation backend/frontend project-scoped Zernio avec sous-agent explorateur, tests et docs | implemented | /sf-verify Finaliser l'integration LATE/Zernio |
| 2026-04-28 06:47 | sf-verify | GPT-5.4 | Verification user story, security gates, docs, tests backend et Flutter | verified | /sf-end Finaliser l'integration LATE/Zernio |
| 2026-04-28 09:09 | sf-end | GPT-5.4 | Cloture du chantier, ajout du reliquat smoke manuel Zernio et changelog | closed | /sf-ship Finaliser l'integration LATE/Zernio |
| 2026-04-28 09:09 | sf-ship | GPT-5.4 | Commit/push des changements du chantier uniquement | shipped | None |

## Current Chantier Flow

- sf-spec: reviewed
- sf-ready: ready
- sf-start: implemented
- sf-verify: verified
- sf-end: closed
- sf-ship: shipped
