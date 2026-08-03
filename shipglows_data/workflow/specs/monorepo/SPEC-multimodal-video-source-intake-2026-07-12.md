---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-07-12"
created_at: "2026-07-12 23:47:13 UTC"
updated: "2026-07-13"
updated_at: "2026-07-13 08:38:00 UTC"
status: ready
source_skill: 100-sg-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlowz authentifiee dans un projet qu'elle possede, je veux constituer un dossier persistant de videos, images, audios, liens publics et textes avant de creer une video, afin de pouvoir soit conserver ces sources comme pretes pour plus tard, soit demander immediatement la generation de la video sans passer par le montage."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "Clerk auth"
  - "Turso/libSQL"
  - "Amazon S3 canonical object storage"
  - "Provider-agnostic object storage and media delivery adapters"
  - "Unified Project Asset Library"
  - "Project Intelligence"
  - "AI-first branded video generation"
  - "Unified ContentGlowz Video Timeline"
  - "Sentry and safe diagnostics"
depends_on:
  - artifact: "shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/SPEC-ai-visual-reference-upload-advanced-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-unified-contentglowz-video-timeline-2026-05-14.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/technical/lab/ai-runtime-and-url-safety.md"
    artifact_version: "1.0.0"
    required_status: "draft"
  - artifact: "shipglows_data/technical/design-system-authority.md"
    artifact_version: "1.0.0"
    required_status: "draft"
  - artifact: "shipglows_data/product/app/product.md"
    artifact_version: "1.1.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "User mini-contract 2026-07-12 defines a bounded multimodal source-intake phase before video creation, with binary files, public links, pasted text, durable project assets, typed non-binary sources and an explicit sources-ready signal."
  - "User clarification 2026-07-13: source intake prepares video generation; only the execution of generation, auto-assembly, timeline editing, rendering, montage, publication and study of the complete video flow remain outside this chantier."
  - "User decision 2026-07-13 requires two independent actions: `Sources pretes` persists the current ready revision without launching generation, while `Generer la video` confirms the current valid revision and explicitly hands one idempotent request to the canonical video orchestrator."
  - "User architecture decision 2026-07-13 selects Amazon S3 as the durable canonical source for binary assets behind a provider-agnostic storage contract, so a future provider change does not alter domain models or Flutter APIs."
  - "Fresh-docs checked 2026-07-13: AWS S3 official docs cover eleven-nines durability, versioning, multipart upload, checksums, lifecycle cleanup, Block Public Access, Bucket owner enforced ownership, encryption at rest, byte-range GET and time-limited presigned access."
  - "Fresh-docs checked 2026-07-13: Bunny Optimizer can resize and convert image previews, and Bunny Stream exposes thumbnails/preview.webp, but adopting either now would duplicate media or couple private delivery to a second provider; Bunny remains an optional future preview adapter, not a V1 dependency."
  - "SPEC-unified-project-asset-library-2026-05-11.md owns the canonical project asset inventory, usage, eligibility and tombstone model; this chantier must integrate with it rather than create a second asset library."
  - "SPEC-ai-visual-reference-upload-advanced-2026-05-11.md fixes backend-proxied multipart upload, server-only Bunny credentials, image validation, metadata stripping, idempotence, compensation and 10 MiB image limits."
  - "Project Intelligence already provides project ownership checks, source records, text normalization, raw and normalized hashes, deduplication primitives, source removal and bounded ingestion patterns reusable for pasted text."
  - "SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md requires an explicit content-complete readiness signal before background video generation and one canonical video orchestrator."
  - "SPEC-unified-contentglowz-video-timeline-2026-05-14.md fixes the canonical video model and a 180-second V1 maximum; this intake must not create a competing draft or timeline model."
  - "Code evidence 2026-07-12: the legacy Reels request accepts client-supplied user_id, bunny_storage_key and bunny_cdn_hostname, while its Flutter diagnostics may include the entered URL; it is an explicit security anti-model for this chantier."
  - "shipglows_data/technical/lab/ai-runtime-and-url-safety.md requires rejection of malformed, non-public, localhost, link-local, private, metadata and mixed-resolution URLs before external fetches."
next_step: "/102-sg-start Multimodal Video Source Intake"
---

# Title

Multimodal Video Source Intake

## Status

Ready. This spec defines the guided, project-scoped collection phase that precedes video generation. It creates a persistent source folder linked to owned content, accepts bounded binary and non-binary source types, exposes recoverable per-source states, and offers two explicit exits: save the current revision as `sources_ready` for later, or confirm that revision and hand one generation request to the canonical video orchestrator now. The execution of generation and the end-to-end video flow remain separate lifecycle stages.

## User Story

En tant que creatrice ContentGlowz authentifiee dans un projet qu'elle possede, je veux creer ou ouvrir un dossier de sources et y ajouter des videos, images, audios, liens HTTP(S) publics et textes colles, afin de preparer les matieres d'une future video puis de choisir entre les conserver comme pretes pour plus tard ou demander immediatement la generation, sans devoir commencer le montage.

## Minimal Behavior Contract

Dans un projet et pour un contenu appartenant a la creatrice authentifiee, ContentGlowz permet de creer ou rouvrir un dossier persistant, d'y ajouter des fichiers video, image et audio, des liens web publics et du texte colle, puis d'afficher pour chaque source un type, un apercu ou des metadonnees sans danger et un etat recuperable. Les fichiers valides deviennent des project assets durables lies au dossier; les liens et textes restent des sources typees et ne deviennent jamais de faux assets. Quand la revision courante est valide, `Sources pretes` la conserve pour plus tard sans lancer de generation, tandis que `Generer la video` confirme cette meme revision si necessaire et remet exactement une demande idempotente a l'orchestrateur video canonique. Toute mutation ulterieure invalide le signal pour les demandes futures. En cas d'echec de source, les succes restent utilisables et l'erreur est recuperable sans fuite; en cas d'echec de remise a l'orchestrateur, le dossier reste pret et aucun job fantome ou doublon ne doit etre annonce. Le cas facile a oublier est un double clic, retry reseau ou remplacement concurrent: il doit conserver la provenance, cibler une revision exacte et ne jamais rattacher au dossier un asset d'un autre projet.

## Success Behavior

- Given une creatrice Clerk authentifiee possede le projet et le contenu cible, when elle cree ou ouvre le dossier de sources, then le backend retourne le meme dossier actif pour ce contenu et aucune timeline, generation ou render job n'est cree.
- Given elle ajoute un fichier image, video ou audio autorise, when le controle serveur reussit, then les octets valides sont stockes durablement dans S3 via l'adaptateur de stockage canonique, un project asset est cree ou dedoublonne, une source binaire pointe vers son `asset_id`, et l'UI affiche un apercu ou des metadonnees approuvees par le backend.
- Given elle colle un texte non vide, when l'ajout reussit, then le texte normalise, ses hashes, son compte de caracteres et son apercu prive sont persistants dans une source `pasted_text` sans creer de project asset.
- Given elle ajoute une URL HTTP(S) publique, when la validation SSRF et la collecte bornee de metadonnees reussissent, then une source `public_link` conserve l'URL canonique et des metadonnees sures sans importer automatiquement la ressource distante comme asset.
- Given une operation contient plusieurs sources et certaines sont invalides, when le traitement se termine, then chaque source a son propre resultat, les succes restent attaches au dossier et les echecs sont retentables ou remplacables.
- Given toutes les sources conservees sont dans un etat compatible, when la creatrice confirme `Sources pretes`, then le dossier enregistre l'auteur, l'horodatage et une revision de readiness consommable plus tard par l'orchestrateur video canonique.
- Given toutes les sources conservees sont compatibles, when la creatrice choisit `Generer la video` sans avoir clique auparavant sur `Sources pretes`, then le backend confirme atomiquement la revision courante et remet exactement une demande ids-only a l'orchestrateur video canonique.
- Given le dossier est deja `ready`, when la creatrice choisit `Generer la video`, then la demande cible exactement `ready_revision`, l'UI confirme sa mise en file avec un identifiant non sensible et aucun second clic ou retry reseau ne cree de doublon.
- Given une source est ajoutee, retiree, remplacee ou revalidee apres readiness, when la revision du dossier change, then l'etat devient `changed_after_ready` et aucune generation future ne peut reutiliser silencieusement l'ancien signal.
- Given la creatrice retire une source, when l'operation reussit, then le lien au dossier est tombe, la source n'est plus eligible pour un futur draft, et l'asset binaire suit la retention et les usages de la Unified Project Asset Library plutot qu'une suppression physique immediate.
- Given elle remplace une source, when la nouvelle source est prete, then l'ancien lien devient `superseded`, le nouveau lien devient actif et l'historique conserve les identifiants de versions sans reecrire la provenance.
- Proof of success: les tests et la QA montrent qu'un dossier mixte survit au rechargement, ne fuit jamais entre projets, distingue clairement sources/asset, peut rester `ready` sans generation, peut remettre une seule demande explicite a l'orchestrateur, puis passe a `changed_after_ready` apres mutation sans reutiliser silencieusement une ancienne revision.

## Error Behavior

- Une session Clerk absente ou invalide retourne `401`; aucun dossier, upload ou source n'est cree.
- Un projet, contenu, dossier, source ou asset absent, archive, supprime ou non possede retourne `403` ou `404` selon les conventions existantes, sans divulguer nom de fichier, URL, texte, hash, storage path ou metadonnees.
- Un type, contenu sniffe, taille, duree, dimension, nom ou signature invalide produit une erreur typee par source et n'ajoute aucun asset eligible.
- Un fichier vide, tronque, chiffre, polyglotte, archive ou dont le MIME declare contredit le contenu est rejete avant readiness.
- Une URL non HTTP(S), avec credentials, localhost, IP privee/link-local/metadata, DNS mixte, redirection vers une destination interdite ou revalidation echouee est rejetee avant toute requete sortante.
- Un timeout ou echec de metadata distante laisse la source `failed` ou `metadata_unavailable` avec retry explicite; il ne transforme pas l'URL en asset et ne bloque pas la modification des autres sources.
- Si S3 echoue avant persistence metadata, l'operation echoue sans source utilisable; si S3 reussit mais la transaction metadata echoue, le backend supprime la version/object en quarantaine ou enregistre `orphan_cleanup_needed` sans annoncer le succes.
- Si une persistence asset reussit mais le lien au dossier echoue, une compensation idempotente retire le nouvel usage et garde l'asset non selectionnable par ce dossier jusqu'a reparation.
- Un retry avec la meme cle d'idempotence retourne le resultat existant; un meme contenu binaire ou texte normalise dans le meme projet produit un lien dedoublonne ou un conflit type, jamais deux sources actives involontaires.
- Une tentative de readiness avec zero source active prete, une source `pending_validation`, `processing`, `failed`, `replacement_pending` ou une revision client obsolete retourne un conflit recuperable et ne change pas l'etat du dossier.
- Une tentative de generation avec les memes preconditions invalides ne cree ni readiness partielle ni demande de generation et affiche les sources a corriger.
- Si l'orchestrateur refuse, timeout ou devient indisponible apres la confirmation de readiness, le dossier reste `ready`, la remise reste `not_enqueued` ou `enqueue_failed`, l'UI propose un retry idempotent et n'annonce jamais qu'une video est en generation sans identifiant accepte.
- Le changement de projet actif pendant un upload ou une mutation fait ignorer la reponse obsolete par Flutter et ne l'applique jamais au nouveau contexte.
- Ce qui ne doit jamais arriver: faire confiance a un `user_id` client, accepter une cle Bunny ou un hostname CDN du client, journaliser URL privee ou texte brut, exposer URL signee ou storage path, conserver EXIF/GPS, suivre une redirection SSRF dangereuse, creer un faux asset pour un lien/texte, lancer une generation depuis `Sources pretes`, ou creer une demande de generation sans clic explicite et revision valide.

## Problem

ContentGlowz dispose deja d'une bibliotheque d'assets, de primitives Project Intelligence, d'une timeline canonique et d'une direction AI-first pour la video, mais il manque un contrat unique pour la phase ou la creatrice rassemble ses matieres avant de declarer le contenu pret. Sans ce contrat, chaque entree pourrait inventer son propre upload, son propre modele de source ou sa propre notion de readiness, avec des risques de doublons, de fuite inter-projets, de credentials Bunny exposes, d'URL non sures et de divergence avec le futur orchestrateur video.

Le flux Reels historique est voisin fonctionnellement mais dangereux comme fondation: il accepte `user_id`, `bunny_storage_key` et `bunny_cdn_hostname` depuis la requete et sa surface Flutter peut placer l'URL saisie dans les diagnostics. La nouvelle intake doit remplacer progressivement ce point d'entree utilisateur, mais ne doit reutiliser ni son contrat de confiance, ni sa gestion de secrets, ni sa journalisation.

## Solution

Ajouter un domaine `video_source_folder` backend-owned, rattache a un projet et a un contenu possedes, avec des `video_source` typees et versionnees. Les sources binaires deleguent leur durabilite et leur gouvernance a la Unified Project Asset Library, qui persiste un `StorageLocator` provider-agnostic et utilise un adaptateur S3 comme implementation V1; les textes reutilisent les primitives de normalisation/hash/dedoublonnage de Project Intelligence; les URLs reutilisent le garde SSRF central. Le stockage, la livraison privee et la generation de previews sont trois interfaces distinctes afin qu'un futur adaptateur Bunny, CloudFront ou autre ne modifie ni le modele domaine ni Flutter. Le dossier expose deux commandes separees sur la meme revision valide: persister `sources_ready` sans side effect aval, ou enregistrer readiness puis remettre une commande ids-only et idempotente a l'orchestrateur video existant. Il ne fabrique ni brouillon, ni timeline, ni moteur de generation concurrent.

## Scope In

- Creation, ouverture, lecture et archivage d'un dossier actif de sources par contenu possede.
- Lien obligatoire `project_id` + `content_id`; lien optionnel ulterieur vers une generation run ou une version de timeline canonique, sans nouveau modele de draft.
- Sources V1: `binary_video`, `binary_image`, `binary_audio`, `public_link`, `pasted_text`.
- Etats source V1: `pending_validation`, `processing`, `ready`, `metadata_unavailable`, `failed`, `replacement_pending`, `superseded`, `removed`, `orphan_cleanup_needed`.
- Etats dossier V1: `collecting`, `ready`, `changed_after_ready`, `archived`.
- Session d'upload creee et autorisee par FastAPI, avec protocole client provider-neutral: petite charge proxifiee si elle respecte le budget runtime, ou URLs presignees opaques pour upload S3 multipart vers une quarantaine privee; Flutter ne recoit jamais de credential AWS, nom de bucket faisant autorite ou SDK S3.
- Creation/reutilisation d'un project asset canonique pour chaque binaire durable et d'un usage `video_source_folder` vers le dossier.
- `ObjectStorageProvider` backend avec operations create-upload-session, put/upload-part, complete, stat/checksum, copy/promote, delete-version et open-range/read; implementation V1 `S3ObjectStorageProvider` et fake deterministe pour les tests.
- `MediaDeliveryProvider` separe du stockage, retournant uniquement des URLs privees ephemeres apres ownership check; implementation V1 S3 presigned GET, avec CloudFront signed delivery comme configuration compatible mais non obligatoire.
- `MediaPreviewProvider` separe, produisant des objets derives (thumbnail image/video et forme d'onde audio) stockes comme usages/assets derives dans S3; Bunny Optimizer/Stream reste un futur adaptateur optionnel et n'est pas appele en V1.
- Persistance directe de texte type et URL type comme sources, sans `asset_id` et sans ligne asset artificielle.
- Apercus/metadonnees sures: nom nettoye, type reel, octets, dimensions, duree, thumbnail/onde ou playback approuve quand disponible, titre/hostname public pour un lien, extrait prive borne pour un texte.
- Retrait, remplacement, retry, dedoublonnage, idempotence, provenance et compensation des echecs partiels.
- Signal explicite revisionne `sources_ready` et invalidation automatique apres mutation.
- Deux actions UI et API distinctes: `Sources pretes` ne lance aucun job; `Generer la video` confirme la revision si necessaire puis remet une demande idempotente au seul orchestrateur video canonique.
- Persistance du resultat de handoff (`not_requested`, `enqueue_pending`, `enqueued`, `enqueue_failed`), de l'idempotency key serveur/client et de l'identifiant canonique accepte, sans dupliquer l'etat interne du job video.
- Remplacement progressif possible de l'entree UI Reels par cette intake securisee, sans migrer les donnees, cookies ou jobs Reels dans ce chantier.
- UI Flutter guidee dans le workflow contenu/video, avec erreurs actionnables, progression par source et aucune surface DAM/playground generique.
- Tests backend, Flutter, securite, storage compensation, diagnostics redaction et QA manuelle.

## Scope Out

- Execution de la generation video apres acceptation du handoff, auto-assemblage, selection de scenes, storyboard, timeline, montage, preview de la video generee, rendu final, publication ou autopublish.
- Etude ou refonte du flux video complet.
- Creation d'un second orchestrateur video, d'un second modele de timeline ou d'un objet de draft cache.
- Migration complete, reprise des donnees, gestion de cookies Instagram ou suppression du backend Reels historique.
- Telechargement automatique du media pointe par une URL, scraping profond, crawling, transcription, OCR, embeddings, facts, recommandations ou synthese AI.
- Import de liens authentifies, intranet, cloud prive, `file:`, `ftp:`, `data:`, IP litterales privees ou URLs contenant des credentials.
- SDK/provider storage dans Flutter, credentials AWS/Bunny cote client, bucket public, ACL objet, URLs signees persistantes comme autorite ou couplage du modele domaine a S3/Bunny.
- Copie automatique des originaux vers Bunny Storage/Stream, dependance V1 a Bunny Optimizer, ou double source canonique S3+Bunny.
- DAM public/global, dossiers imbriques generiques, tags libres avances, bulk editor, partage inter-projets ou collaboration multi-role.
- Moderation juridique, verification copyright/licence, reconnaissance faciale, malware sandbox complete ou garantie que tout contenu accepte est publiable.
- Upload hors ligne et synchronisation binaire en arriere-plan; V1 peut conserver un brouillon UI local non sensible, mais la readiness exige l'etat serveur.

## Constraints

- Authentification via `require_current_user`; l'identite et `user_id` sont derives exclusivement de Clerk cote serveur.
- Chaque route revalide l'ownership du projet, du contenu, du dossier, de la source, de l'asset et de toute cible canonique; Flutter n'est jamais une frontiere d'autorisation.
- Les credentials AWS, role/keys, region, bucket, endpoint, KMS key et details de provider proviennent uniquement de la configuration backend/role runtime. Aucun champ client equivalent n'est accepte, meme optionnel; les URLs presignees sont courtes, scopees a une operation et ne deviennent jamais des donnees durables.
- Le bucket S3 canonique est prive avec Block Public Access, Object Ownership `Bucket owner enforced`, versioning et encryption serveur; SSE-S3 est le baseline, SSE-KMS est autorise par configuration quand le besoin de controle de cle le justifie.
- Les uploads multipart utilisent checksum SHA-256, tailles/part counts bornes, finalisation idempotente et lifecycle `AbortIncompleteMultipartUpload`; la quarantaine expire automatiquement et n'est jamais eligibile comme project asset avant validation/promotion.
- Le backend choisit le namespace, l'object key, l'upload ID et les numeros de parts; chaque session opaque est liee au Clerk user, projet, contenu, dossier, taille, MIME attendu, checksum, expiration et idempotency key. La finalisation refuse toute divergence ou session rejouee hors de son etat permis.
- La configuration CORS S3, si Flutter web utilise les URLs presignees, allowliste les origins produit, methodes et headers strictement necessaires; elle n'ouvre ni lecture publique ni wildcard de credentials.
- Le contrat Reels existant est un anti-modele explicite et ne doit pas etre copie, adapte ou appele par la nouvelle intake.
- Allowlist V1 image: `image/jpeg`, `image/png`, `image/webp`; maximum 10 MiB, 4096 px par cote et 16 megapixels decodes.
- Allowlist V1 video: `video/mp4`; maximum 200 MiB et 180 secondes. Le backend verifie conteneur, codec lisible, dimensions et duree; renommer un fichier ne suffit pas.
- Allowlist V1 audio: `audio/mpeg`, `audio/mp4`, `audio/wav`, `audio/x-wav`; maximum 50 MiB et 180 secondes, avec verification du contenu et de la duree decodee.
- Limites V1 d'ajout: 10 sources par operation, au plus 8 binaires, 250 MiB cumules et 100 sources actives par dossier.
- Texte colle V1: UTF-8 normalise, 1 a 100 000 caracteres apres normalisation; aucun texte brut dans logs, breadcrumbs, analytics ou diagnostics copies.
- Lien V1: 1 a 2048 caracteres, HTTP(S) public uniquement, maximum 10 liens par operation, 5 redirections, 2 MiB de reponse maximum pour metadata, timeout total 10 secondes et revalidation SSRF a chaque redirection/connexion.
- Abus V1: maximum 20 operations d'ajout par utilisateur et projet par heure, aligne sur le plafond d'upload existant; la readiness doit confirmer la politique finale sans laisser la limite ouverte.
- Les metadata fournies par le client sont des hints; MIME sniffing, hash, dimensions, duree, storage path, source type, statut et eligibility sont determines par le serveur.
- Les originaux image durables sont nettoyes d'EXIF/GPS et metadata annexes. Pour video/audio, seules les metadata techniques allowlistees sont conservees; tags, commentaires et geolocalisation incorpores sont retires ou rejetes selon la capacite de sanitization confirmee a la readiness.
- Les thumbnails, formes d'onde et URLs de playback sont des representations derivees; elles ne remplacent pas l'asset durable et leurs URLs signees ne sont jamais persistees comme source de verite.
- L'UI respecte `tools/design-tokens/contentglowz_theme.json`, `AppThemeTokens`, `AppSpacing`, `AppRadii`, `AppText` et `Theme.of(context)`; aucun literal visuel ad hoc ni surface generique de gestion d'assets.
- Les diagnostics reutilisent la surface Sentry/Copy diagnostics existante avec commit/build et temps Paris/UTC, mais excluent texte utilisateur, URL complete, signed URL, storage path, nom sensible, cookies, headers et secrets.
- `Sources pretes` et `Generer la video` utilisent deux commandes explicites et auditables. La premiere ne peut jamais appeler l'orchestrateur; la seconde cible une `ready_revision` exacte et exige une idempotency key pour absorber double clic, retry et relecture reseau.
- L'intake persiste seulement l'etat de remise et l'identifiant retourne par l'orchestrateur; le statut detaille du job, sa timeline et ses artefacts restent sous l'autorite du domaine video canonique.

## Test Contract

- Surface/stack profile: mixed Flutter + FastAPI + Clerk auth + Turso/libSQL + provider-agnostic storage/delivery contracts + Amazon S3 + parsing media + URL SSRF.
- Proof profile: automated backend and Flutter tests, storage contract tests, controlled S3 provider integration, authenticated device/web QA and adversarial security checks.
- Proof order: focused unit tests -> migration/storage contract -> router/store integration -> Flutter tests/analyze -> token drift -> controlled S3/URL integration -> authenticated manual device/web checklist.
- Checklist path: `shipglows_data/workflow/test-checklists/multimodal-video-source-intake.md`.
- Required scenario IDs: `INTAKE-MIXED-001`, `INTAKE-TENANT-002`, `INTAKE-S3-COMPENSATION-003`, `INTAKE-SSRF-004`, `INTAKE-READINESS-005`, `INTAKE-GENERATE-IDEMPOTENCY-006`, `INTAKE-STALE-PROJECT-007`, `INTAKE-DIAGNOSTICS-008`, `INTAKE-UPLOAD-SESSION-009`, `INTAKE-BUNNY-OFF-010`.
- Required results: a mixed folder persists; tenant crossing is denied; S3/Turso split-brain is compensated; SSRF targets are blocked before fetch; readiness-only dispatches nothing; generate-now dispatches at most once; stale responses are ignored; sensitive storage/user data stays redacted; forged/expired upload sessions fail; previews work without Bunny.
- Automated backend proof: model/store/migration tests, storage contract tests shared by fake/S3 adapters, router ownership tests, multipart limit/checksum/sniffing tests, asset-link integration tests, text normalization/dedup tests, SSRF tests, idempotence/concurrency tests, readiness-only versus generation-handoff tests, S3 compensation tests and diagnostics-redaction tests.
- Automated Flutter proof: typed model/API/provider tests, per-source state rendering, stale-project response rejection, retry/replace/remove flows, two-CTA behavior, readiness invalidation and token-drift scan.
- Contract/integration proof: deterministic fake object-storage/delivery adapters and bounded fake URL fetcher first; controlled S3 integration with server configuration only after fresh-docs and environment checks pass.
- Provider proof: S3 multipart object creation, checksum/version capture, range read, short-lived delivery URL, quarantine promotion, cleanup and metadata correlation in a non-production test bucket, without printing credentials, bucket names, object keys or signed URLs.
- Browser/auth proof: non applicable because the owned intake surface is Flutter; Clerk ownership remains covered by backend tests and authenticated device QA.
- Manual/device proof: authenticated creator creates a mixed folder, backgrounds/foregrounds the app during upload, changes active project, retries a failure, replaces/removes a source, saves it ready without generation, then explicitly requests generation once and verifies retry/double-click behavior before mutating after ready.
- Ordered proof path: focused unit tests -> storage contract/router/store integration -> Flutter tests/analyze -> token drift -> controlled S3/URL integration -> authenticated manual/device checklist.
- Manual checklist path to create during implementation: `shipglows_data/workflow/test-checklists/multimodal-video-source-intake.md`.
- Exception-with-proof: no generation execution, render, publish or Bunny provider proof is run because those systems are downstream/optional; contract tests prove `Sources pretes` dispatches nothing, `Generer la video` remet au plus une demande acceptee, and preview delivery does not require Bunny.

## Dependencies

- Unified Project Asset Library owns asset identity, storage descriptors, project scoping, usage links, eligibility, tombstones and retention.
- Advanced visual reference upload supplies the hardened upload-validation baseline, image caps, metadata stripping, idempotence and compensation semantics; its Bunny-specific transport is not reused as the canonical provider.
- Project Intelligence supplies reusable text normalization, raw/normalized SHA-256 hashes, source-style persistence and deduplication primitives; its facts/recommendations/jobs are not imported into this workflow.
- AI-first branded video generation owns the canonical enqueue contract and all execution after acceptance; this intake may call only that entrypoint with `folder_id`, `sources_ready_revision`, owned content context and an idempotency key.
- Unified ContentGlowz Video Timeline remains the only video draft/timeline authority and supplies the 180-second V1 duration ceiling.
- Clerk/FastAPI ownership patterns: `lab/api/dependencies/auth.py`, `lab/api/dependencies/ownership.py` and existing `require_owned_project`/owned-content helpers.
- URL safety: `lab/api/services/url_safety.py` and `shipglows_data/technical/lab/ai-runtime-and-url-safety.md`.
- Design authority: `shipglows_data/technical/design-system-authority.md` and the canonical token generation path.
- Observability: existing Sentry/runtime diagnostics surface, with privacy defaults for private text and user-owned media.
- `fresh-docs checked`: AWS S3 official docs and boto3 1.43.46 API docs consulted on 2026-07-13 for durability, versioning, multipart/checksum, lifecycle abort, private bucket controls, encryption, range GET, managed file-like upload and time-limited `generate_presigned_url`; local lock is boto3 1.43.45 and compatible with the selected calls.
- `fresh-docs checked`: Bunny Optimizer and Bunny Stream preview capabilities were reviewed on 2026-07-13; they are useful optional adapters but intentionally not V1 dependencies because they would add duplicate storage/delivery coupling without measured need.
- `fresh-docs checked`: official FastAPI request-files docs confirm `UploadFile` uses a spooled file and is appropriate for large binaries; local locks are FastAPI 0.139.0, Starlette 1.3.1 and python-multipart 0.0.32. Application byte/duration limits remain mandatory because spooling is not a security limit.
- `fresh-docs checked`: official pub.dev docs select `file_picker` 11.0.2 for native multi-select and extension/type filtering across Android, iOS, web and desktop; implementation must add it explicitly to `app/pubspec.yaml` and lock it before use.

## Invariants

- Un dossier appartient a exactement un `user_id`, un `project_id` et un `content_id`; `user_id` vient de Clerk et n'est jamais accepte comme autorite client.
- Au plus un dossier actif existe par `(project_id, content_id, purpose=video_source_intake)`; create/open est idempotent.
- Une source appartient a exactement un dossier et herite de son scope projet; aucun lien cross-project n'est possible.
- Une upload session appartient a exactement un utilisateur/projet/dossier/revision et ne peut finaliser que l'object key et le checksum choisis par le serveur; une URL presignee expiree ou modifiee n'accorde aucun droit domaine.
- Une source binaire `ready` a exactement un `asset_id` durable et eligible; une source `public_link` ou `pasted_text` n'a jamais d'`asset_id`.
- Un objet/quarantine upload sans metadata canonique n'est pas un asset produit; une metadata sans objet S3/version/checksum valide n'est pas une source binaire prete.
- Le domaine ne depend jamais d'une classe boto3, d'un bucket, d'une URL S3 ou d'un hostname CDN: seul `StorageLocator(provider, namespace, object_key, version, checksum)` traverse la couche asset, et seul l'adaptateur transforme ce locator en operation provider.
- L'original canonique et les representations derivees ont des locators et usages distincts; une preview n'est jamais promue en original et sa suppression ne supprime pas l'original.
- Les hashes servent au dedoublonnage dans le scope projet et ne sont pas exposes comme identifiants publics.
- Le signal readiness porte une revision exacte, un auteur et un timestamp; il n'est vrai que pour la revision courante du dossier.
- Ajouter, remplacer, retirer, retenter ou revalider une source incremente la revision et invalide la readiness precedente.
- `ready` ne signifie ni licence verifiee, ni moderation editoriale, ni generation lancee, ni publication autorisee.
- `Sources pretes` ne cree jamais de generation request; il place le dossier dans la liste des dossiers prets a reprendre plus tard.
- `Generer la video` est le seul declencheur de handoff dans cette intake; une revision et une idempotency key donnees produisent au plus un identifiant de demande canonique.
- Une demande acceptee conserve la revision qu'elle a consommee; une mutation ulterieure n'altere pas cette demande historique et exige une nouvelle action explicite pour une nouvelle revision.
- Le retrait du dossier bloque tout nouvel usage depuis ce dossier, mais ne supprime pas physiquement un asset encore utilise ailleurs.
- Le remplacement cree une nouvelle provenance et ne reecrit pas les usages historiques.
- Aucune URL distante ou signed URL n'est une autorite durable pour un binaire; seules les references asset serveur le sont.
- Les erreurs partielles sont visibles et recuperables; aucun succes global ne masque `failed` ou `orphan_cleanup_needed`.

## Links & Consequences

- Backend: introduire un router, des modeles, un service/store et une migration idempotente dedies a l'intake, tout en reutilisant les services project asset, auth/ownership, URL safety et text processing existants.
- Asset library: ajouter le target/usage `video_source_folder`, le `StorageLocator` provider-agnostic et les media-kind eligibility checks necessaires, sans deuxieme table d'asset concurrente; conserver une lecture compatible des anciens `bunny://` assets.
- Project Intelligence: extraire ou reutiliser proprement les primitives pures de texte/hash/dedup; ne pas coupler l'intake aux jobs de facts/recommendations.
- Flutter: ajouter modeles, methodes `ApiService`, provider project-scoped et ecran/etapes de collecte rattaches au contenu; les widgets ne font pas leurs propres appels HTTP et ignorent le provider concret derriere les upload instructions/preview URLs.
- Storage/delivery: `ObjectStorageProvider`, `MediaDeliveryProvider` et `MediaPreviewProvider` sont des ports backend separes; S3 implemente le stockage V1, S3 presigned GET la livraison V1, CloudFront peut remplacer la livraison par configuration, Bunny peut etre ajoute plus tard uniquement comme adaptateur preview/delivery.
- Video orchestration: remettre maintenant uniquement `folder_id` + `sources_ready_revision` + contexte de contenu possede + idempotency key au point d'entree canonique; pas de payload contenant raw URLs, raw text ou storage descriptors, et aucun suivi de job duplique dans l'intake.
- Legacy Reels: la future navigation peut rediriger l'entree utilisateur vers l'intake, mais les routes/cookies/donnees Reels restent intactes dans ce chantier.
- Offline/degraded mode: les lectures cachees peuvent rester visibles comme potentiellement obsoletes; upload, retrait, remplacement et readiness exigent confirmation serveur.
- Performance: uploads stream/spool de facon bornee, listes paginees si necessaire et metadata media calculees hors du thread de requete quand le cout depasse le budget confirme a la readiness.
- Securite/operations: prevoir nettoyage d'orphelins, retries bornes, metriques a faible cardinalite par code d'etat/type, et alertes sans contenu utilisateur.

## Documentation Coherence

- Aucun document produit ou technique n'est modifie pendant `100-sg-spec`, conformement a la mission bornee.
- L'implementation devra mettre a jour la documentation API `lab`, le guide Flutter `app`, les limites d'upload, les codes d'erreur, la retention/compensation et la difference entre source, project asset et readiness.
- La documentation utilisateur devra expliquer que `Sources pretes` clot temporairement la collecte mais ne genere, ne monte et ne publie rien.
- La documentation utilisateur devra distinguer visuellement et semantiquement `Sources pretes`, qui conserve le dossier dans la liste des dossiers prets, de `Generer la video`, qui remet immediatement une demande au flux video sans promettre que le rendu est deja termine.
- La documentation support devra couvrir retries, sources bloquees, uploads S3 incomplets/orphelins, invalidation apres remplacement et signalement d'un lien rejete sans demander l'URL privee complete.
- La documentation d'architecture devra expliquer le statut canonique de S3, les trois ports storage/delivery/preview, les locators sans URL durable, la compatibilite legacy Bunny et les conditions mesurees avant d'activer un adaptateur Bunny ou CloudFront.
- Les docs Reels devront, lors d'un chantier ulterieur de migration, marquer l'ancien point d'entree comme legacy et ne jamais presenter son contrat actuel comme reference securisee.
- Le changelog n'est pas modifie par cette spec; il sera evalue apres implementation et verification.

## Edge Cases

- Le meme fichier est ajoute deux fois dans le meme dossier, puis dans deux dossiers du meme projet.
- Deux uploads concurrents portent la meme cle d'idempotence ou le meme hash.
- Un batch mixte contient neuf sources valides et une source invalide.
- Le client annonce une image alors que les octets contiennent une video, une archive ou un polyglotte.
- Une video MP4 respecte la taille mais depasse 180 secondes, a un codec non lisible ou une metadata de duree incoherente.
- Un audio contient artwork, commentaire, localisation ou tags prives a retirer.
- S3 accepte/finalise l'objet mais Turso echoue; Turso accepte l'attempt mais S3 ne contient plus la version attendue.
- Un multipart expire avec des parts incompletes; lifecycle et reconciliation doivent liberer le stockage sans creer d'asset.
- Un ancien asset `bunny://` est lu apres l'introduction du locator S3; il reste consultable sans devenir la valeur par defaut des nouveaux uploads.
- Une preview derivee est absente ou perimee tandis que l'original est sain; l'UI montre un fallback metadata et permet une regeneration sans toucher l'original.
- La connexion tombe apres upload mais avant que Flutter recoive la reponse; le retry doit retrouver le resultat.
- Le projet actif change pendant upload, metadata polling, retrait ou readiness.
- La creatrice double-clique `Generer la video`, ferme l'app pendant `enqueue_pending` ou retry apres une reponse perdue; une seule demande canonique doit exister.
- Un attaquant remplace l'upload ID, l'object key, le part number, le checksum ou le dossier lors de finalisation; le backend refuse sans stat/promote cross-tenant et sans divulguer le locator attendu.
- La confirmation readiness reussit mais l'orchestrateur refuse ou timeout; le dossier reste reprenable comme `ready` et la generation n'est pas affichee comme lancee.
- Une demande de generation a consomme la revision N, puis une source change et le dossier passe a N+1; la demande N reste historisee et N+1 n'est jamais generee implicitement.
- L'acces au projet est perdu entre le debut et la finalisation.
- L'URL publique redirige vers localhost, une IP privee, un endpoint metadata ou une resolution DNS mixte.
- Le domaine change d'IP entre validation et connexion; l'adresse effectivement connectee doit etre revalidee.
- Une page publique est trop volumineuse, lente, sans titre, non HTML ou retourne une boucle de redirections.
- Une URL identique avec fragment, casse d'hostname ou parametres de tracking est ajoutee deux fois; la canonicalisation ne doit pas fusionner deux ressources semantiquement distinctes de maniere destructive.
- Le texte ne contient que des espaces, depasse 100 000 caracteres ou se normalise vers un doublon.
- Une creatrice marque ready au meme moment qu'un autre retry finalise une source; la revision optimistic-concurrency doit refuser l'un des deux changements.
- Une source prete est remplacee, mais le nouvel upload echoue; l'ancienne reste explicite et aucune bascule silencieuse n'a lieu.
- Une source est retiree alors que son asset est utilise ailleurs; seul le lien du dossier est retire.
- Une source `metadata_unavailable` peut etre gardee comme lien visible mais ne permet pas readiness tant que la politique de compatibilite n'est pas satisfaite par un retry ou un remplacement.
- L'utilisateur ouvre un cache offline marque ready alors que le serveur est `changed_after_ready`; aucune action aval n'est permise avant resynchronisation.

## Implementation Tasks

- [x] Tache 1: Fixer les contrats de domaine, etats et API de l'intake
  - Fichiers: `lab/api/models/video_source_intake.py`, `lab/api/routers/video_source_intake.py`
  - Action: Definir les schemas folder/source, les enums, la revision optimistic-concurrency, les erreurs typees et les routes create/open/list/add/remove/replace/retry/mark-ready.
  - User story link: Fournir un dossier persistant et des etats comprehensibles sans lancer la video.
  - Depends on: none
  - Validate with: tests de schema et revue du contrat JSON, dont absence de `user_id`, credentials/provider config, bucket/object key, raw storage URL et autorite metadata client; les champs Bunny legacy restent explicitement interdits.
  - Notes: Les requetes utilisent project/content/folder/source ids et idempotency keys; l'identite vient de Clerk.

- [x] Tache 2: Ajouter la persistence idempotente du dossier, des sources et revisions
  - Fichiers: `lab/api/migrations/`, `lab/api/services/video_source_intake_store.py`
  - Action: Creer les tables/indexes/contraintes pour folder, source, version/remplacement, readiness revision, attempts et cleanup state, avec migrations/ensures Turso conformes au projet.
  - User story link: Faire survivre le dossier au rechargement avec provenance et recuperation.
  - Depends on: Tache 1
  - Validate with: tests migration/store pour create-open idempotent, ownership scope, concurrency, replacement, removal et readiness invalidation.
  - Notes: Ne pas dupliquer les colonnes d'asset; conserver seulement `asset_id` et l'usage canonique pour les binaires.

- [x] Tache 3: Introduire le locator et les ports provider-agnostic dans la Unified Project Asset Library
  - Fichiers: `lab/status/db.py`, `lab/status/schemas.py`, `lab/status/service.py`, `lab/api/models/status.py`, `lab/api/services/project_asset_storage.py`, migration/index associe
  - Action: Ajouter le target/action `video_source_folder`, persister un `StorageLocator` structure (`provider`, `namespace`, `object_key`, `version`, `checksum_sha256`) sans URL signee, introduire les interfaces `ObjectStorageProvider`, `MediaDeliveryProvider`, `MediaPreviewProvider`, accepter image/video/audio durables selon eligibility et conserver une lecture compatible des assets Bunny existants.
  - User story link: Faire des binaires des assets durables reutilisables et migrables sans creer une bibliotheque concurrente ni verrouiller le domaine sur S3.
  - Depends on: Tache 1, Tache 2
  - Validate with: tests migration/contract pour locators S3 et legacy Bunny, absence d'URL durable, same-project, media kinds, dedup, usage unlink, tombstone et retention.
  - Notes: Une source lien/texte ne traverse jamais ce chemin.

- [x] Tache 4: Implementer l'adaptateur S3, l'upload securise et ses compensations
  - Fichiers: `lab/api/services/object_storage.py`, `lab/api/services/s3_object_storage.py`, `lab/api/services/media_delivery.py`, `lab/api/services/media_preview.py`, `lab/api/services/video_source_media_service.py`, `lab/api/routers/video_source_intake.py`, `lab/requirements.txt`, lockfiles
  - Action: Ajouter boto3 comme dependance directe bornee, creer des upload sessions provider-neutral, streamer/spooler ou emettre des URLs multipart presignees vers une quarantaine privee, sniffer/decoder/nettoyer les metadata, calculer/verifier SHA-256, promouvoir l'objet S3 valide, generer des previews derivees, emettre des GET presignes courts et compenser chaque echec partiel.
  - User story link: Ajouter des videos, images et audios avec etats recuperables et apercus surs.
  - Depends on: Tache 2, Tache 3 et resolution fresh-docs S3/boto3/FastAPI
  - Validate with: storage contract tests fake/S3, tests MIME/size/duration/dimensions, multipart interruption/abort, checksum, replay, orphan cleanup, preview isolation, signed URL expiry, metadata sanitization et charge memoire bornee.
  - Notes: Ne pas reutiliser `lab/api/routers/reels.py`, ses modeles ou son passage de credentials.

- [x] Tache 5: Reutiliser les primitives texte Project Intelligence sans importer son pipeline AI
  - Fichiers: `lab/api/services/project_intelligence_processor.py`, `lab/api/services/video_source_text_service.py`
  - Action: Extraire/reutiliser normalisation, hashes et dedup pour `pasted_text`, appliquer la limite de 100 000 caracteres et produire uniquement un apercu prive borne.
  - User story link: Conserver le texte comme vraie source typee, persistante et dedoublonnee.
  - Depends on: Tache 2
  - Validate with: tests UTF-8, whitespace, empty, limite, raw/normalized duplicate et redaction logs/diagnostics.
  - Notes: Ne pas declencher chunks, facts, recommendations ou AI synthesis dans ce chantier.

- [x] Tache 6: Implementer l'intake de liens avec garde SSRF
  - Fichiers: `lab/api/services/url_safety.py`, `lab/api/services/video_source_link_service.py`, `lab/api/routers/video_source_intake.py`
  - Action: Canonicaliser prudemment, refuser destinations interdites, revalider DNS/IP et redirections, collecter seulement metadata bornee et persister une source lien sans asset.
  - User story link: Ajouter des liens publics sans ouvrir une surface SSRF ni faux import media.
  - Depends on: Tache 2
  - Validate with: tests localhost/private/link-local/metadata/mixed DNS/rebinding simulation/redirect chain/oversize/timeout et absence d'appel externe apres rejet.
  - Notes: Ne jamais inclure l'URL complete dans logs, Sentry, analytics ou erreurs utilisateur partageables.

- [x] Tache 7: Implementer la readiness revisionnee et le handoff explicite vers la generation
  - Fichiers: `lab/api/services/video_source_intake_service.py`, `lab/api/routers/video_source_intake.py`
  - Action: Separer la commande readiness-only de la commande generate-now; calculer les memes preconditions, enregistrer `sources_ready_revision`, invalider apres mutation, puis remettre pour generate-now un descriptor ids-only et une idempotency key au point d'entree canonique de generation. Persister seulement l'etat de remise et l'identifiant accepte.
  - User story link: Permettre a la creatrice soit de conserver ses sources pretes, soit de demander leur generation maintenant sans double action obligatoire.
  - Depends on: Tache 3, Tache 4, Tache 5, Tache 6
  - Validate with: tests zero/pending/failed/ready, revision stale, race ready-vs-upload, readiness-only sans dispatch, generate-now atomique, double clic/retry idempotent et echec d'orchestrateur conservant le dossier `ready`.
  - Notes: Le descriptor ne contient ni raw text, ni raw URL, ni storage locator, ni URL signee/CDN, seulement ids, types, revisions et etats approuves. Ne pas reimplementer la queue ni le job video.

- [x] Tache 8: Ajouter les contrats Flutter et le state project-scoped
  - Fichiers: `app/pubspec.yaml`, `app/pubspec.lock`, `app/lib/data/models/video_source_intake.dart`, `app/lib/data/services/api_service.dart`, `app/lib/providers/video_source_intake_provider.dart`
  - Action: Ajouter `file_picker` 11.0.2, serialization typee, execution des upload instructions opaques via le service central, progression, retry/replace/remove, commandes readiness-only/generate-now, etats de handoff, cache explicite et stale-response guards sur project/content/revision.
  - User story link: Rendre la collecte fiable dans l'app et recuperable apres interruption.
  - Depends on: Tache 1, Tache 7 et resolution fresh-docs du file picker Flutter
  - Validate with: Flutter unit/provider tests pour upload instructions provider-neutral, erreurs typees, partial batch, project switch, background/foreground, revision conflict, double clic/retry de generation et redaction diagnostics.
  - Notes: Aucun widget ne cree son propre client HTTP et aucune configuration S3/Bunny n'entre dans le modele Flutter.

- [x] Tache 9: Construire l'UI Flutter guidee de collecte
  - Fichiers: `app/lib/presentation/screens/editor/video_source_intake_screen.dart`, widgets dedies sous `app/lib/presentation/widgets/`
  - Action: Afficher un parcours compact ajouter-fichiers/lien/texte, cartes par source, progression/etat, apercu sur, retirer/remplacer/retry et deux actions distinctes: `Sources pretes` pour conserver sans lancer, `Generer la video` pour remettre maintenant a l'orchestrateur. Afficher la meme raison de blocage source sur les deux actions et un etat `enqueue_pending` non recliquable.
  - User story link: Permettre de preparer maintenant puis de choisir entre reprendre plus tard et lancer le flux video, sans exposer un DAM ou un montage premature.
  - Depends on: Tache 8
  - Validate with: widget tests, semantics/accessibilite, tailles de cible, dynamic text, dark mode et `design_system_drift_check.py --changed --format markdown`.
  - Notes: Toute valeur visuelle passe par l'autorite de tokens; pas de playground generique. Les libelles, hierarchie et confirmations doivent rendre impossible la confusion entre « dossier conserve comme pret » et « generation demandee ».

- [x] Tache 10: Ajouter l'entree de navigation et preparer le remplacement progressif de Reels
  - Fichiers: `app/lib/router.dart`, surface contenu/video concernee, `app/lib/presentation/screens/reels/reels_screen.dart`
  - Action: Relier le contenu possede a l'intake et, si l'entree Reels est exposee, proposer une redirection produit vers la collecte securisee sans supprimer ni migrer le backend legacy.
  - User story link: Donner un point d'entree coherent avant la future creation video.
  - Depends on: Tache 9
  - Validate with: route/widget tests prouvant le project/content scope et qu'aucune requete intake ne transporte `user_id`, credential/provider config, bucket ou URL signee dans diagnostics.
  - Notes: La migration complete Reels fera l'objet d'un chantier separe.

- [ ] Tache 11: Couvrir integration, securite, observabilite et QA
  - Fichiers: `lab/tests/test_video_source_intake_*.py`, tests Flutter correspondants, `shipglows_data/workflow/test-checklists/multimodal-video-source-intake.md`
  - Action: Implementer le Test Contract, les abuse cases, les compensations, la privacy Sentry et le parcours manuel/device.
  - User story link: Prouver que le dossier est durable, isole, recuperable, conservable sans generation et remis une seule fois a l'orchestrateur sur demande explicite.
  - Depends on: Tache 4 a Tache 10
  - Validate with: suites ciblees backend/Flutter, token drift, integration S3/URL controlee et checklist authentifiee.
  - Notes: Les fixtures utilisent des URLs/secrets factices et jamais de contenu utilisateur reel.

- [x] Tache 12: Aligner la documentation apres implementation
  - Fichiers: docs API/app/support et localisation identifiees pendant implementation
  - Action: Documenter contrats, limites, source-vs-asset, S3 canonique/provider agnostique, ports storage-delivery-preview, les deux actions, etats de handoff, erreurs/retry, retention, privacy et statut legacy de Reels/Bunny sans changer les promesses hors scope.
  - User story link: Expliquer clairement la difference entre conserver un dossier pret et demander sa generation maintenant.
  - Depends on: Tache 11
  - Validate with: revue de coherence documentaire, copy UX et readiness/verify du chantier.
  - Notes: Aucun document n'est modifie pendant la creation de cette spec.

## Acceptance Criteria

- [x] CA 1: Given une creatrice Clerk authentifiee possede le projet et le contenu, when elle cree deux fois le dossier intake, then le backend retourne le meme dossier actif project-scoped et ne lance aucun job video.
- [x] CA 2: Given une utilisatrice non authentifiee ou non proprietaire, when elle lit ou mute un dossier/source/asset, then elle recoit `401`, `403` ou `404` sans fuite de metadata.
- [ ] CA 3: Given un fichier image JPEG/PNG/WebP valide sous 10 MiB et les limites decodees, when il est ajoute, then un project asset durable avec locator S3 versionne/checksumme est lie au dossier, une preview derivee est separee de l'original et la source devient `ready`.
- [ ] CA 4: Given une video MP4 valide sous 200 MiB et 180 secondes, when elle est ajoutee, then son type, sa duree et ses dimensions sont determines cote serveur et son asset est durable.
- [ ] CA 5: Given un audio autorise sous 50 MiB et 180 secondes, when il est ajoute, then ses metadata techniques allowlistees sont persistantes et ses tags prives ne figurent ni dans l'asset public ni dans les diagnostics.
- [x] CA 6: Given un MIME mensonger, fichier vide, archive, polyglotte, duree excessive ou contenu non decodeable, when l'upload est traite, then seule cette source echoue avec une erreur typee et aucun asset eligible n'est cree.
- [x] CA 7: Given un texte entre 1 et 100 000 caracteres, when il est colle, then il est normalise/dedoublonne comme source `pasted_text`, reste sans `asset_id` et n'apparait brut dans aucun log ou diagnostic.
- [x] CA 8: Given une URL HTTP(S) publique sure, when elle est ajoutee, then elle reste une source `public_link`, ses metadata sont collectees dans les bornes et aucun binaire distant n'est transforme en asset.
- [x] CA 9: Given une URL vers localhost, IP privee, metadata, DNS mixte ou redirection interdite, when elle est ajoutee, then elle est rejetee avant fetch dangereux et l'erreur partageable ne contient pas l'URL complete.
- [x] CA 10: Given S3 finalise un binaire mais Turso echoue, when la compensation s'execute, then la version/quarantaine est supprimee ou marquee `orphan_cleanup_needed` et le dossier ne la considere jamais prete.
- [x] CA 11: Given la meme idempotency key est rejouee apres une perte reseau, when le backend recoit le retry, then il retourne le resultat initial sans second asset ni seconde source active.
- [x] CA 12: Given un ajout mixte contient succes et echecs, when il se termine, then chaque source affiche son etat, les succes persistent et les echecs peuvent etre retries/remplaces sans recommencer tout le batch.
- [x] CA 13: Given une source est remplacee, when le nouveau binaire devient pret, then l'ancienne version est `superseded`, la nouvelle est active et la provenance historique demeure immutable.
- [x] CA 14: Given un asset est utilise ailleurs, when sa source est retiree du dossier, then seul l'usage intake est retire et aucune suppression physique prematuree n'a lieu.
- [x] CA 15: Given toutes les sources actives sont compatibles et le dossier a au moins une source `ready`, when la creatrice confirme `Sources pretes`, then le backend enregistre la revision, l'identite Clerk et l'horodatage de readiness sans creer ni remettre aucune demande de generation.
- [x] CA 16: Given les sources sont compatibles mais le dossier est encore `collecting`, when la creatrice choisit `Generer la video`, then le backend confirme atomiquement la revision courante et remet exactement une demande ids-only a l'orchestrateur canonique.
- [x] CA 17: Given une demande de generation a ete acceptee ou sa reponse a ete perdue, when la creatrice double-clique ou retry avec la meme idempotency key et la meme revision, then le meme identifiant canonique est retourne sans second job.
- [x] CA 18: Given readiness reussit mais l'orchestrateur refuse ou timeout, when le handoff se termine, then le dossier reste `ready`, l'etat devient `enqueue_failed`, aucun succes de generation n'est affiche et un retry idempotent est disponible.
- [x] CA 19: Given un dossier est `ready`, when une source est ajoutee, retiree, remplacee ou revalidee, then il devient `changed_after_ready` jusqu'a nouvelle confirmation et aucune nouvelle generation n'est implicite.
- [x] CA 20: Given une source reste pending, failed, replacement_pending ou orphan_cleanup_needed, when la creatrice tente l'une des deux actions, then le backend refuse avec les source ids/codes actionnables sans contenu prive et ne remet aucune demande.
- [x] CA 21: Given le projet actif change pendant une requete, when l'ancienne reponse arrive, then Flutter l'ignore et ne pollue ni l'UI ni le cache du nouveau projet.
- [x] CA 22: Given la future entree intake remplace visuellement Reels, when elle envoie une requete, then le payload ne contient ni `user_id`, ni credential/bucket/provider config, ni champ Bunny legacy, et les diagnostics ne contiennent ni URL complete, URL presignee, object key ni texte brut.
- [x] CA 23: Given `Generer la video` obtient un identifiant accepte, when le contrat intake est inspecte, then aucune timeline, scene, preview video, render ou publication n'est creee par l'intake et le suivi detaille reste dans le domaine video canonique.
- [ ] CA 24: Given l'UI est implementee, when le drift check et les widget tests tournent, then les deux actions sont distinctes, accessibles et non ambigues, et les valeurs visuelles utilisent l'autorite design-system en dark mode, dynamic type et navigation clavier/tactile.
- [x] CA 25: Given les plafonds V1 et l'architecture provider-agnostic sont appliques, when 101-sg-ready revoit la spec, then S3/boto3, FastAPI multipart/UploadFile et le choix Flutter de fichier disposent chacun d'une preuve de docs officielles actuelle ou la spec reste non ready.
- [x] CA 26: Given un asset nouvellement uploade, when ses donnees persistantes et reponses API sont inspectees, then aucune URL presignee/CDN n'est une autorite durable et le domaine ne depend que du locator provider-neutral.
- [x] CA 27: Given un asset Bunny legacy et un nouvel asset S3 coexistent, when la bibliotheque les lit, then les deux restent utilisables via leurs adaptateurs sans que Bunny soit appele pour stocker ou previsualiser le nouvel asset.
- [x] CA 28: Given Bunny est desactive, when une image/video/audio S3 valide est affichee, then la preview ou le fallback metadata fonctionne via les adapters V1 et aucun appel Bunny n'est requis.
- [x] CA 29: Given une upload session valide, when le client forge le dossier, l'object key, l'upload ID, le part number ou le checksum a la finalisation, then le backend refuse sans promotion, sans asset et sans divulgation cross-tenant.
- [ ] CA 30: Given Flutter web utilise une URL presignee, when l'origin ou les headers ne sont pas allowlistes, then CORS refuse l'operation et aucune politique bucket publique n'est ajoutee pour contourner l'erreur.

## Test Strategy

- Unit backend: validation de chaque MIME/limite, sniffing, metadata sanitization, URL canonicalization/SSRF, normalisation/hash texte, state machine, readiness revision, handoff idempotent et redaction.
- Store/migration: locators provider-neutral, compatibilite legacy Bunny, contraintes uniques, ownership scope, optimistic concurrency, retries, versions, replacement, tombstone, etat de handoff et cleanup state sur Turso/libSQL.
- Router/auth: Clerk identity derivation, project/content/folder/source/asset ownership, erreurs sans enumeration, batch partiel, separation des deux commandes et payloads sans secrets.
- Integration: fake storage/delivery/preview contracts puis S3 non-production pour multipart/stat/range/delete/checksum/version/presign; faux resolver/fetcher pour DNS, redirects, timeouts et limites; service asset reel en base de test.
- Flutter: serialization, ApiService multipart, provider stale guards, progression, partial batch, retries, replacement/removal, readiness-only, generate-now, etats de handoff et diagnostics expurges.
- UI: widget/golden seulement si le projet les utilise deja, semantics et comprehension des deux actions, dynamic type, dark mode, erreurs longues/localisees, cibles tactiles et token drift.
- Manual/device: suivre la checklist dediee avec un projet de test possede et des fixtures non sensibles; verifier persistance apres restart, conservation ready sans generation, demande explicite unique et absence de navigation vers montage/rendu.
- Adversarial: cross-project ids, forged upload-session/part/object locators, expired presigned URLs, spoofed fields Reels, replay, double clic/retry de generation, revision stale, MIME confusion, decompression/metadata bombs, SSRF redirects/rebinding, race readiness/mutation/handoff et S3/database split-brain.
- Fresh docs: S3/boto3, FastAPI/Starlette/python-multipart and file_picker contracts are checked against official docs on 2026-07-13; any material installed-version drift reopens readiness.

## Risks

- Securite storage/auth: reutiliser le contrat Reels ou exposer S3 au client elargirait identite, bucket et credentials. Mitigation: Clerk server-derived, bucket prive, IAM least privilege, upload sessions scopees, URLs courtes, aucun SDK provider Flutter et tests de schema/payload.
- SSRF: une URL apparemment publique peut rediriger ou re-resoudre vers une cible interne. Mitigation: garde central, resolution/revalidation a chaque hop, adresse connectee controlee, fetch borne et tests adversariaux.
- Confidentialite: texte, URLs, noms et metadata media peuvent fuiter via Sentry ou diagnostics. Mitigation: allowlist de champs, hashes/ids, redaction centrale et tests de non-divulgation.
- Split-brain S3/Turso: echec partiel peut laisser multipart, version ou source fantome. Mitigation: attempts durables, quarantine, lifecycle abort, compensation idempotente, `orphan_cleanup_needed`, reconciliation et aucune readiness partielle cachee.
- Performance/couts: video 200 MiB et metadata probing peuvent saturer memoire, CPU, requetes ou egress. Mitigation: multipart direct presigne vers quarantaine, streaming/spooling borne pour validation, range reads, previews derivees, limites cumulees et budgets/metrics avant ajout d'un CDN secondaire.
- Provider abstraction theater: une interface trop generique pourrait masquer les garanties S3 ou devenir un wrapper inutilisable. Mitigation: port base sur les capacites reelles requises par le domaine, contract tests communs, capability flags explicites, adaptateur S3 de reference et aucune promesse de lowest-common-denominator.
- Preview provider creep: Bunny peut accelerer/transformer les previews mais introduire duplication, cout, purge et seconde frontiere d'acces. Mitigation: previews V1 derivees dans S3, delivery ephemere, Bunny seulement derriere `MediaPreviewProvider` apres mesure de latence/cout/qualite et revue securite.
- Codec/sanitization: `video/mp4` ou `audio/*` ne garantit pas un codec exploitable ni un retrait fiable des tags. Mitigation: decode/probe allowliste, rejet ferme et confirmation de l'outillage a la readiness.
- Duplication de modele: creer une nouvelle bibliotheque ou un draft intake concurrent fragmenterait le produit. Mitigation: `asset_id` canonique pour binaires, source typed pour texte/lien et handoff ids-only vers timeline/orchestrateur existants.
- Readiness stale: un signal ancien pourrait declencher une future generation avec des sources modifiees. Mitigation: revision optimistic-concurrency et invalidation automatique apres toute mutation.
- Double dispatch: double clic, timeout ou retry pourrait lancer deux generations couteuses. Mitigation: idempotency key liee au dossier/revision, contrainte d'unicite, retour du meme identifiant canonique et UI non recliquable pendant `enqueue_pending`.
- Readiness-orchestrator split: readiness peut etre persistee alors que la remise echoue. Mitigation: etat de handoff distinct, dossier conserve `ready`, aucun faux succes, retry idempotent et reconciliation bornee.
- UX scope creep: la collecte peut deriver vers DAM ou editeur video. Mitigation: parcours guide contenu-scoped, actions limitees aux sources plus le seul handoff explicite, et aucune timeline, scene, execution de generation ou rendu dans l'intake.
- Migration Reels: rediriger l'entree sans plan de donnees peut creer deux historiques. Mitigation: ce chantier permet seulement un remplacement progressif de surface; migration/retirement complet exigent une spec separee.
- Fresh-docs: les versions/provider contracts actuels n'ont pas ete valides pendant ce draft. Mitigation: trois gaps bloquants sont nommes et doivent etre resolus par `101-sg-ready`.

## Execution Notes

- Lire d'abord cette spec, `SPEC-unified-project-asset-library-2026-05-11.md`, `project_intelligence_processor.py`, `ai-runtime-and-url-safety.md` et `design-system-authority.md`; consulter les fichiers Reels uniquement comme anti-modele.
- Ordre d'execution: contrats/state machine -> persistence -> asset usage -> media/text/link services -> readiness et handoff canonique -> Flutter data/state -> UI/navigation -> integration/security/docs.
- Fresh-docs checked 2026-07-13 for S3/boto3 durability, versioning, multipart, checksum, lifecycle, security, range and presign; FastAPI `UploadFile`; pub.dev `file_picker` 11.0.2; and Bunny Optimizer/Stream capabilities. Do not transform documentation examples into production configuration.
- Reutiliser les abstractions existantes par responsabilite: ownership Clerk, Unified Project Asset Library, Project Intelligence text primitives, URL safety et diagnostics. Ne pas reutiliser un module seulement parce qu'il est voisin fonctionnellement.
- Le modele dossier recommande: identity project/content, `revision`, `status`, `ready_revision`, `ready_by`, `ready_at`; le handoff recommande conserve `ready_revision`, `idempotency_key`, `enqueue_status`, optional canonical request id et timestamps sans recopier le job; le modele source recommande: type, lifecycle status, optional asset id, safe metadata, hashes, replacement lineage, attempt/error code et timestamps; le locator asset recommande contient provider/namespace/object_key/version/checksum sans URL durable.
- API ids-only pour les usages aval; aucun raw URL/text/storage descriptor ne traverse l'orchestrateur video. `Sources pretes` n'appelle jamais ce contrat; `Generer la video` est son seul appelant dans cette surface.
- Validation ciblee attendue apres implementation: pytest intake/asset/storage-contract/S3/url/text, Flutter tests/analyze, metadata/migration checks, design drift, puis integration S3 et QA device; Bunny est explicitement absent du chemin V1.
- Stop/reroute vers `101-sg-ready` si les docs officielles contredisent les plafonds ou l'approche; vers une spec migration si la suppression/reprise de Reels devient necessaire; vers la spec video si le chantier depasse le handoff et commence a executer generation, selection de scenes, timeline, rendu ou publication.
- Observabilite: erreurs Sentry avec codes stables, source type, etape et ids non sensibles; pas de haute cardinalite par URL/hash/user text. Les copied diagnostics commencent par commit/build et timestamps Paris/UTC.
- Les limites V1 sont approuvees pour implementation; toute revision doit etre explicite, plus sure ou mesuree, et preserve les acceptance criteria.

## Open Questions

None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-07-12 23:47:13 UTC | 100-sg-spec | GPT-5 Codex | Created the bounded draft spec for multimodal source intake before video creation, including canonical asset/source reuse, explicit readiness, legacy Reels security prohibitions, V1 limits and freshness gaps | Draft saved | /101-sg-ready Multimodal Video Source Intake |
| 2026-07-13 06:53:28 UTC | 100-sg-spec | GPT-5 Codex | Corrected the generation boundary and added independent readiness-only and explicit generate-now actions with revisioned, idempotent orchestration handoff | Draft updated to v0.2.0 | /101-sg-ready Multimodal Video Source Intake |
| 2026-07-13 08:25:58 UTC | 100-sg-spec | GPT-5 Codex | Replaced Bunny-canonical storage with S3 behind provider-neutral storage/delivery/preview ports; kept Bunny as a measured optional preview adapter after official capability review | Draft updated to v0.3.0 | /101-sg-ready Multimodal Video Source Intake |
| 2026-07-13 08:38:00 UTC | 101-sg-ready | GPT-5 Codex | Completed structural, adversarial, security, documentation and fresh-docs review; hardened upload-session ownership/CORS and confirmed S3/boto3, FastAPI and file_picker contracts | Ready v1.0.0 | /102-sg-start Multimodal Video Source Intake |
| 2026-07-13 09:27:36 UTC | 102-sg-start | GPT-5 Codex | Implemented the provider-neutral intake domain, S3 reference adapter, durable asset locators, secure multipart validation, text/link sources, revisioned readiness and generation handoff, Flutter UX, tests and docs | Implemented locally; automated proof complete | /103-sg-verify Multimodal Video Source Intake |
| 2026-07-13 09:27:36 UTC | 103-sg-verify | GPT-5 Codex | Ran full backend and Flutter suites, static analysis, checklist parser, diff hygiene and design-token drift review; classified inherited editor drift separately | Partial: 429 backend and 165 Flutter tests pass; 4 hosted/provider/device scenarios remain | /005-sg-ship Multimodal Video Source Intake |
| 2026-07-13 09:29:27 UTC | 005-sg-ship | GPT-5 Codex | Published the complete local implementation and its partial verification record to create the hosted validation target | Shipped for hosted proof; formal closure remains deferred | /405-sg-prod ContentGlowz |
| 2026-07-13 09:34:41 UTC | 405-sg-prod | GPT-5 Codex | Correlated commit 9b62d80 with GitHub/Vercel/Blacksmith and live health evidence; collected the complete Android CI log and checked the API/app endpoints | Partial: Blacksmith checks pass, Vercel skipped both builds, and the live API still serves d5fb4d0 | Identify and trigger the matching API deployment, then rerun /405-sg-prod ContentGlowz |
| 2026-07-13 09:41:19 UTC | 002-sg-maintain | GPT-5 Codex | Removed the stale deployment-provider blueprint, active CORS allowance and related technical documentation after the operator clarified that the provider is not used | Verified locally; historical public articles intentionally left for an editorial decision | /005-sg-ship Remove stale provider references |
| 2026-07-13 09:41:19 UTC | 005-sg-ship | GPT-5 Codex | Published the verified operational cleanup and corrected deployment trace wording | Shipped; no hosted behavior claim | Choose whether to remove or rewrite historical public provider references |

## Current Chantier Flow

- `100-sg-spec`: done; draft updated with two independent actions, S3 canonical storage, provider-neutral ports, optional Bunny previews and idempotent ids-only generation handoff.
- `101-sg-ready`: done; ready v1.0.0 after adversarial/security review and official docs checks.
- `102-sg-start`: done locally; backend, storage, persistence, Flutter, tests and docs implemented.
- `103-sg-verify`: partial; automated checks pass, while real S3, deployed web CORS, authenticated device and hosted mixed-flow proof remain intentionally `NOT_RUN`.
- `104-sg-end`: deferred; formal closure requires the hosted/provider/device proof.
- `005-sg-ship`: shipped for hosted proof; this does not close the four external verification gaps.
- `405-sg-prod`: partial; Android CI is green for `9b62d80`, Vercel skipped the app/site builds, and `api.contentglowz.com` still reports `d5fb4d0`; the API deployment provider is not documented.
- `002-sg-maintain`: done; obsolete operational provider configuration and terminology removed.
- `005-sg-ship`: shipped the maintenance cleanup; public historical provider references remain outside this bounded change.
- Prochaine commande: choose whether to remove or rewrite the historical public provider references; independently, identify and trigger matching app/API deployments before rerunning `/405-sg-prod ContentGlowz`.
