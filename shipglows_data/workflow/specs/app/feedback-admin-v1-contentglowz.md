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
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
user_story: "En tant qu'admin ContentGlowz, je veux un ecran in-app pour lister, filtrer et traiter les feedbacks utilisateurs textes et audio."
linked_systems: []
depends_on: []
supersedes: []
evidence: []
next_step: "/sf-docs audit shipglows_data/workflow/specs/app/feedback-admin-v1-contentglowz.md"
---
# Feedback Admin v1 pour ContentGlowz

## Adaptation au projet actuel

Le plan initial mentionne Convex, mais le projet actuel est une app Flutter branchée sur un backend FastAPI via `ApiService`. L’adaptation retenue est donc:

- backend cible: FastAPI existant
- client Flutter: Riverpod + `ApiService`
- admin dans l’app existante, accessible depuis `Settings`
- contrôle client par helper `isFeedbackAdmin`
- contrôle serveur attendu via allowlist email sur les routes admin FastAPI

## Contrat backend attendu

Routes ajoutées côté API:

- `POST /api/feedback/text`
- `POST /api/feedback/audio/upload-url`
- `POST /api/feedback/audio`
- `GET /api/feedback/admin`
- `POST /api/feedback/admin/:id/review`

Payload métier attendu:

- entrée feedback: `type`, `message`, `audioStorageId`, `audioUrl`, `durationMs`, `platform`, `locale`, `userId`, `userEmail`, `createdAt`, `status`
- upload audio: `uploadUrl`, `storageId`, `method`, `headers`

## Décisions d’implémentation Flutter

- brouillon texte conservé localement dans `SharedPreferences`
- historique local réduit aux derniers feedbacks envoyés depuis l’appareil
- les nouvelles soumissions sont envoyées au backend et deviennent la source de vérité
- l’audio est enregistré localement en PCM, converti en WAV, uploadé, puis lié à une entrée feedback backend
- l’écran admin lit les feedbacks distants, filtre par statut/type, lit l’audio via `audioUrl` et marque les entrées comme lues

## Compatibilité

- aucune dépendance au vieux snapshot `quitcoke_feedback_entries` n’existe dans ce repo
- la migration douce se traduit ici par une séparation nette entre:
  - stockage local de confort
  - stockage backend pour les nouvelles soumissions
