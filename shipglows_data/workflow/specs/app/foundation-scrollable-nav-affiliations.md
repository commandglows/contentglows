---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: app
created: "2026-04-25"
updated: "2026-04-27"
status: ready
source_skill: sf-docs
scope: feature
owner: unknown
confidence: low
risk_level: medium
security_impact: unknown
docs_impact: yes
user_story: "unknown (legacy spec migrated to ShipGlowz metadata)"
linked_systems: []
depends_on: []
supersedes: []
evidence: []
next_step: "/sf-docs audit shipglows_data/workflow/specs/app/foundation-scrollable-nav-affiliations.md"
---
# Spec: Fondation — Navigation scrollable + Affiliations (domaine pilote)

Date: 2026-03-28

## Titre

Socle fondation pour la re-implementation des 13 domaines manquants : navigation Flutter scrollable + pattern CRUD Lab + domaine affiliations comme pilote.

## Probleme

L'app Flutter a 4 tabs fixes (Feed, Schedule, History, Settings). Il faut ajouter 13 domaines manquants. La `NavigationBar` actuelle ne supporte pas plus de 5 destinations. Aucun pattern CRUD repetable n'existe cote Lab pour les nouveaux domaines. Le domaine affiliations (programmes + liens d'affiliation) a ete supprime du legacy Node.js et jamais migre.

## Solution

1. Remplacer `NavigationBar` par une barre de navigation horizontale scrollable.
2. Creer le pattern CRUD complet cote Lab (model + store + router + migration) avec affiliations comme premier domaine.
3. Creer l'ecran Flutter affiliations (liste + formulaire) qui valide le pattern de bout en bout.

## Scope In

- Navigation scrollable Flutter (remplace NavigationBar fixe)
- Lab : migration SQL, modele Pydantic, store CRUD, router FastAPI pour affiliations
- Flutter : modele AffiliateLink, methodes ApiService, ecran affiliations (liste + create/edit + delete)
- Route `/affiliations` dans le ShellRoute

## Scope Out

- Research Exa (sera un batch suivant)
- Les 12 autres domaines manquants
- Gmail OAuth, Analytics PostHog
- Refonte theme / design system

## Contexte technique

### Patterns Lab existants (a suivre)

- **Router** : `APIRouter(prefix="/api/...", tags=[...])`, `Depends(require_current_user)` sur chaque route
- **Models** : Pydantic dans `api/models/`, Request + Response separes
- **Store** : `api/services/user_data_store.py`, SQL brut via `libsql_client`, helpers `_json_load`, `_json_dump`, `_ts`
- **Ownership** : toujours `WHERE userId = ?` dans les queries
- **Main** : import du router + `app.include_router(...)` dans `api/main.py`

### Patterns Flutter existants (a suivre)

- **Models** : `data/models/`, classes avec `fromJson`/`toJson`/`copyWith`
- **ApiService** : `data/services/api_service.dart`, Dio, methodes `fetch*`/`save*`/`delete*`
- **Screens** : `presentation/screens/<domain>/`, widgets `ConsumerWidget` ou `ConsumerStatefulWidget`
- **Navigation** : `AppShell` avec `NavigationBar`, routes dans `ShellRoute` de `GoRouter`
- **Providers** : `providers/providers.dart`, Riverpod

### Schema legacy AffiliateLink (reference — commit e096383)

```sql
CREATE TABLE AffiliateLink (
  id TEXT PRIMARY KEY NOT NULL,
  userId TEXT NOT NULL REFERENCES User(id),
  projectId TEXT,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  description TEXT,
  contactUrl TEXT,
  loginUrl TEXT,
  researchSummary TEXT,
  researchedAt INTEGER,
  category TEXT,
  commission TEXT,
  keywords TEXT,  -- JSON array
  status TEXT NOT NULL DEFAULT 'active',  -- active | expired | paused
  notes TEXT,
  expiresAt INTEGER,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL
);
```

---

## Taches d'implementation

### Bloc A — Navigation scrollable Flutter

- [ ] Tache 1 : Remplacer NavigationBar par SingleChildScrollView + Row dans AppShell
  - Fichier : `ContentGlowz_app/lib/presentation/screens/app_shell.dart`
  - Action : Remplacer le widget `NavigationBar` par une barre custom scrollable horizontalement. Garder les 4 destinations actuelles (Feed, Schedule, History, Settings) + ajouter Affiliations. Utiliser `SingleChildScrollView(scrollDirection: Axis.horizontal)` avec des `InkWell`/`NavigationDestination`-like widgets. Conserver le highlight de la tab active. La barre doit rester en `bottomNavigationBar` du Scaffold.
  - Notes : Garder le meme style visuel (Material 3, icones + labels). La barre doit etre facilement extensible (ajouter une destination = ajouter un item dans une liste).

- [ ] Tache 2 : Ajouter la route /affiliations dans le router
  - Fichier : `ContentGlowz_app/lib/router.dart`
  - Action : Ajouter `GoRoute(path: '/affiliations', ...)` dans le `ShellRoute.routes`. Importer `AffiliationsScreen`.

### Bloc B — Backend Lab (FastAPI)

- [ ] Tache 3 : Migration SQL AffiliateLink
  - Fichier : `ContentGlowz_lab/api/migrations/001_affiliate_link.sql` (nouveau)
  - Action : `CREATE TABLE IF NOT EXISTS AffiliateLink (...)` avec le schema legacy. Le `IF NOT EXISTS` rend la migration idempotente au cas ou la table existe deja dans Turso.

- [ ] Tache 4 : Executer la migration au demarrage
  - Fichier : `ContentGlowz_lab/api/services/user_data_store.py`
  - Action : Ajouter une methode `ensure_tables()` qui execute la migration SQL au premier appel. Appeler dans `_ensure_connected()` ou au demarrage via lifespan. Patron idempotent.

- [ ] Tache 5 : Modele Pydantic affiliations
  - Fichier : `ContentGlowz_lab/api/models/affiliations.py` (nouveau)
  - Action : Creer `AffiliateLinkResponse`, `AffiliateLinkCreateRequest`, `AffiliateLinkUpdateRequest`. Suivre le meme pattern que `PersonaResponse`/`PersonaCreateRequest` dans `user_data.py`.

  ```python
  class AffiliateLinkResponse(BaseModel):
      id: str
      userId: str
      projectId: str | None = None
      name: str
      url: str
      description: str | None = None
      contactUrl: str | None = None
      loginUrl: str | None = None
      researchSummary: str | None = None
      researchedAt: datetime | None = None
      category: str | None = None
      commission: str | None = None
      keywords: list[str] = Field(default_factory=list)
      status: str = "active"  # active | expired | paused
      notes: str | None = None
      expiresAt: datetime | None = None
      createdAt: datetime
      updatedAt: datetime

  class AffiliateLinkCreateRequest(BaseModel):
      projectId: str | None = None
      name: str
      url: str
      description: str | None = None
      contactUrl: str | None = None
      loginUrl: str | None = None
      category: str | None = None
      commission: str | None = None
      keywords: list[str] | None = None
      status: str | None = None
      notes: str | None = None
      expiresAt: str | None = None  # ISO date string

  class AffiliateLinkUpdateRequest(BaseModel):
      name: str | None = None
      url: str | None = None
      description: str | None = None
      contactUrl: str | None = None
      loginUrl: str | None = None
      category: str | None = None
      commission: str | None = None
      keywords: list[str] | None = None
      status: str | None = None
      notes: str | None = None
      expiresAt: str | None = None
  ```

- [ ] Tache 6 : Store CRUD affiliations
  - Fichier : `ContentGlowz_lab/api/services/user_data_store.py`
  - Action : Ajouter dans la classe `UserDataStore` :
    - `_affiliate_from_row(row)` — helper row-to-dict
    - `list_affiliations(user_id, project_id=None)` — SELECT avec filtre optionnel projectId
    - `get_affiliation(user_id, affiliation_id)` — SELECT par id + userId
    - `create_affiliation(user_id, payload)` — INSERT
    - `update_affiliation(user_id, affiliation_id, payload)` — UPDATE partiel
    - `delete_affiliation(user_id, affiliation_id)` — DELETE avec ownership check
  - Notes : Suivre exactement le pattern `list_personas`/`create_persona`/`update_persona`/`delete_persona`. Ownership via `userId = ?`.

- [ ] Tache 7 : Router FastAPI affiliations
  - Fichier : `ContentGlowz_lab/api/routers/affiliations.py` (nouveau)
  - Action : CRUD complet :
    - `GET /api/affiliations` — liste, filtre optionnel `projectId`
    - `POST /api/affiliations` — creation
    - `GET /api/affiliations/{id}` — detail
    - `PUT /api/affiliations/{id}` — update
    - `DELETE /api/affiliations/{id}` — suppression
  - Notes : Copier le pattern exact de `routers/personas.py`. `Depends(require_current_user)` partout.

- [ ] Tache 8 : Enregistrer le router dans main.py
  - Fichier : `ContentGlowz_lab/api/main.py`
  - Action : Importer `affiliations_router` et ajouter `app.include_router(affiliations_router)`.

### Bloc C — Flutter (modele + API + ecran)

- [ ] Tache 9 : Modele Dart AffiliateLink
  - Fichier : `ContentGlowz_app/lib/data/models/affiliate_link.dart` (nouveau)
  - Action : Classe `AffiliateLink` avec `fromJson`, `toJson`, `copyWith`. Champs : id, userId, projectId, name, url, description, contactUrl, loginUrl, researchSummary, researchedAt, category, commission, keywords (List<String>), status, notes, expiresAt, createdAt, updatedAt.

- [ ] Tache 10 : Methodes ApiService affiliations
  - Fichier : `ContentGlowz_app/lib/data/services/api_service.dart`
  - Action : Ajouter 4 methodes :
    - `fetchAffiliations({String? projectId})` → `List<AffiliateLink>`
    - `createAffiliation(Map<String, dynamic> data)` → `AffiliateLink`
    - `updateAffiliation(String id, Map<String, dynamic> data)` → `AffiliateLink`
    - `deleteAffiliation(String id)` → `bool`
  - Notes : Suivre le pattern `fetchPersonas`/`savePersona`. Avec `allowDemoData` fallback.

- [ ] Tache 11 : Provider Riverpod affiliations
  - Fichier : `ContentGlowz_app/lib/providers/providers.dart`
  - Action : Ajouter `affiliationsProvider` (FutureProvider qui appelle `fetchAffiliations`).

- [ ] Tache 12 : Ecran AffiliationsScreen — liste
  - Fichier : `ContentGlowz_app/lib/presentation/screens/affiliations/affiliations_screen.dart` (nouveau)
  - Action : Ecran avec :
    - AppBar "Affiliations" avec bouton "+" pour ajouter
    - Liste des liens affilies (Card par item : name, url, status badge, category, commission)
    - Filtres rapides par status (all/active/paused/expired) via chips
    - Stats en haut (total, active, paused, expired) — 4 petites cards
    - Empty state si aucun lien
    - Pull-to-refresh
    - Tap sur un item → ouvre le formulaire en mode edit
    - Swipe ou long-press → delete avec confirmation
  - Notes : Mobile-first. Pas de table desktop pour l'instant (Flutter = mobile d'abord).

- [ ] Tache 13 : Formulaire AffiliationFormSheet
  - Fichier : `ContentGlowz_app/lib/presentation/screens/affiliations/affiliation_form_sheet.dart` (nouveau)
  - Action : BottomSheet ou page modale avec les champs :
    - name (required), url (required), description, category (dropdown), commission, contactUrl, loginUrl, keywords (chips/tags input), status (dropdown), notes, expiresAt (date picker)
  - Notes : Reutilisable en mode create et edit. Pattern similaire a `PersonaEditorScreen`.

---

## Criteres d'acceptation

- [ ] CA1 : Given l'app Flutter demarre, when l'utilisateur est connecte, then la bottom nav affiche Feed, Schedule, History, Settings, Affiliations et on peut scroller horizontalement.
- [ ] CA2 : Given l'utilisateur tape sur Affiliations dans la nav, when l'ecran charge, then la liste des liens affilies s'affiche (ou empty state).
- [ ] CA3 : Given l'utilisateur tape "+", when il remplit name + url et valide, then le lien est cree dans Turso et apparait dans la liste.
- [ ] CA4 : Given un lien existe, when l'utilisateur tape dessus et modifie le nom, then le lien est mis a jour dans Turso.
- [ ] CA5 : Given un lien existe, when l'utilisateur le supprime et confirme, then le lien disparait de la liste et est supprime de Turso.
- [ ] CA6 : Given l'utilisateur filtre par "active", when des liens ont differents status, then seuls les liens actifs s'affichent.
- [ ] CA7 : Given un token Clerk invalide, when Flutter appelle GET /api/affiliations, then FastAPI repond 401 et Flutter gere l'erreur.
- [ ] CA8 : Given un utilisateur A, when il appelle GET /api/affiliations/{id} d'un lien de l'utilisateur B, then FastAPI repond 404.
- [ ] CA9 : Given la table AffiliateLink n'existe pas dans Turso, when le serveur demarre, then la migration la cree automatiquement.

## Dependances

- `libsql_client` (deja present dans lab)
- `dio` (deja present dans app)
- `go_router` (deja present dans app)
- `flutter_riverpod` (deja present dans app)
- Aucune nouvelle dependance requise.

## Risques

- La table `AffiliateLink` existe peut-etre deja dans Turso (migration legacy). Le `IF NOT EXISTS` previent le crash.
- `ApiService` fait deja 750+ lignes. Ajouter 4 methodes c'est acceptable mais il faudra envisager un split par domaine dans un batch futur.
- La nav scrollable peut poser des problemes d'UX si trop de tabs. Pour 5 tabs c'est correct, a reevaluer a 10+.

## Ordre d'implementation recommande

1. Bloc B (Lab backend) — taches 3-8
2. Bloc A (Navigation) — taches 1-2
3. Bloc C (Flutter client) — taches 9-13

Le backend d'abord pour pouvoir tester avec curl/Swagger. La nav ensuite car c'est un prerequis pour voir l'ecran. Le client Flutter en dernier.

## Reference legacy

Le code complet legacy est accessible dans le git history de ContentGlowz_site :
```bash
git show e096383:chatbot/lib/db/schema.ts          # Schema Drizzle
git show e096383:chatbot/lib/db/queries.ts          # Queries CRUD
git show e096383:chatbot/app/api/affiliations/route.ts  # API list+create
git show e096383:chatbot/app/api/affiliations/\[id\]/route.ts  # API get+update+delete
git show e096383:chatbot/hooks/use-affiliations.ts  # Hook React
git show e096383:chatbot/components/dashboard/affiliations-tab.tsx   # Tab UI
git show e096383:chatbot/components/dashboard/affiliations-table.tsx # Table
git show e096383:chatbot/components/dashboard/affiliation-form-modal.tsx  # Form
```
