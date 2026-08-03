---
artifact: exploration
created: "2026-05-08"
updated: "2026-05-08"
status: draft
scope: "iOS capture privacy redaction"
confidence: medium
risk_level: high
security_impact: "yes"
---

# Exploration iOS: Capture écran dynamique avec redaction

## Faisabilité (apps arbitraires)

Sur iOS, pour couvrir des apps tierces arbitraires, la capture passe par `ReplayKit` (`startCapture` / sample buffers ou Broadcast Upload Extension). On récupère des `CMSampleBuffer` et on peut appliquer un traitement image avant export via `AVAssetWriter` (pipeline vidéo perso), donc techniquement faisable en live sans dépendre de la source applicative.

Contraintes:
- La source est des pixels déjà rendus, donc pas de réécriture sémantique de texte (pas de “modifier le texte réel”).
- `ReplayKit` documente un flux de buffers via `RPBroadcastSampleHandler`/`processSampleBuffer(_:with:)` et le mode d’échantillons (`RPBroadcastProcessModeSampleBuffer`).
- `startCapture` expose `CMSampleBuffer` + type de média (`RPScreenRecorder`).
- `AVAssetWriter` est l’outil standard pour écrire le résultat (single-use per file, session start/finish).
- `Core Image` + `CIContext` supporte filtre en chaîne (ex: flou, masques) avec rendu GPU (incluant Metal).

## Temps réel vs post-production

### Redaction temps réel (V1 recommandé si objectif “pas de fichier clair”)
- Avantage: on peut éviter de persister un MP4/PNG clair si la pipeline écrit directement le flux redressé.
- Implémentation: OCR/vision sur frames, stabilisation temporelle (sauvegarde/migration des boîtes), flou/mosaic/scalade sur ROI, puis encodage.
- Risque: latence CPU/GPU + taux de faux négatifs élevé si texte petit/rapide/effets visuels.

### Post-production (V2 ou backup UX)
- Avantage: plus simple à intégrer dans un premier temps (traitement après la capture brute).
- Désavantage majeur: le contenu clair existe au moins temporairement (stockage local, crash, leakage si gestion lifecycle imparfaite, partages accidentels), donc non aligné avec “confidentialité forte”.

Recommandation de faisabilité: iOS vaut mieux viser un mode “live / close-to-live” + garde-fous post-prod.

## Vision, Core Image, Metal, AVAssetWriter

- `VNRecognizeTextRequest` fournit les boîtes et observations de texte avec options de performance (`recognitionLevel`) et langue; utile pour zones de flou ciblé.
- `VNDetectFaceRectanglesRequest` donne boîtes faciales pour anonymisation visuelle complémentaire.
- `Core Image` permet composition masquante via filtres intégrés; `CIFilter` + `CIContext` avec rendu Metal (`init(mtlDevice:)`) réduit la pression CPU.
- `AVAssetWriter` reste la brique iOS naturelle pour écrire un MP4 nettoyé en local.

## V1 / V2

### V1
- Scope: capture d’écran ReplayKit + OCR texte (Vision) + redaction ciblée (blur/pixelate/scramble visuel) + export via AVAssetWriter.
- Objectif: aucune preuve de fichier clair normalisé côté assets finaux.
- Contraintes: pas de garantie absolue; review user obligatoire.

### V2
- Option Broadcast Upload Extension pour traitement plus poussé/isolé.
- Amélioration de robustesse: suivi d’objets/temporalité plus stable, UI de disclosure plus stricte, filets de sécurité sur fallback (arrêt si pipeline en retrait).

## Risques principaux

- Faux négatifs OCR (petit texte, motion, contraste), donc fuite résiduelle.
- Contournement par contenu non-capturable (contenu protégé, cas `AVPlayer` incompatible rapporté côté ReplayKit).
- Charge/perf iOS variable selon device, résolution, fps.
- Risque de conformité App Review si UX capture/logging n’indique pas clairement quand ça enregistre (`explicit consent`, indication claire), ou si la promesse marketing dépasse le “best effort”.
- Sur-couplage d’un pipeline live fragile (buffer drops, back-pressure, arrêt brutal).

## Sources officielles consultées (access date 2026-05-08)

- ReplayKit / sample buffers:  
  https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler  
  https://developer.apple.com/documentation/replaykit/rpscreenrecorder/startcapture%28handler%3Acompletionhandler%3A%29  
  https://developer.apple.com/documentation/replaykit/rpsystembroadcastpickerview  
  https://support.apple.com/en-gb/guide/security/seca5fc039dd/web
- Vision texte/face:  
  https://developer.apple.com/documentation/vision/vnrecognizetextrequest  
  https://developer.apple.com/documentation/vision/recognizing-text-in-images
  https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest
- Core Image / Metal:  
  https://developer.apple.com/documentation/CoreImage  
  https://developer.apple.com/documentation/CoreImage/CIContext
- AVAssetWriter:  
  https://developer.apple.com/documentation/avfoundation/avassetwriter
- App Store / conformité:
  https://developer.apple.com/app-store/review/guidelines/  
  https://developer.apple.com/app-store/user-privacy-and-data-use/

## Recommandation

Commencer iOS en V1 live-redaction:
- Capture écran via ReplayKit in-app + traitement par frame avec Vision,  
- masquage visuel local (CI + Metal) + écriture directe AVAssetWriter,  
- fallback explicite vers post-production uniquement si la performance/qualité OCR chute, avec mention “best effort + review obligatoire”.
