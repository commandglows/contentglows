---
title: "Exploration Windows: mode confidentialité capture dynamique"
date: 2026-05-08
topic: "windows/privacy-capture"
status: draft
---

## Context
- Objectif: vérifier la faisabilité d’un **mode de redaction dynamique** Windows au moins équivalent au mode Web/iOS/Linux existant, pour capture d’écran arbitraire (fenêtre/affichage), masquage en direct puis **export aplati** (flux final déjà anonymisé).
- Contraintes produit: confidentialité forte, workflow **best-effort + review**, pas de promesse de suppression parfaite des données sensibles.
- Sources ciblées: `Windows.Graphics.Capture`, `Screen capture to video`, `OcrEngine`, Win2D (features/custom effects), ONNX Runtime WinUI.

## Findings

### Faisabilité technique (Windows)
- `Windows.Graphics.Capture` permet la capture d’écran d’écrans et de fenêtres via `GraphicsCapturePicker`/`GraphicsCaptureItem` avec consentement utilisateur explicite, puis `Direct3D11CaptureFramePool` + `GraphicsCaptureSession` pour recevoir les frames.
- Le pipeline est adapté au traitement frame par frame en mémoire GPU/CPU, puis à l’encodage vidéo en local (sans persister de source claire si pipeline directe).
- `Windows.Media.Ocr.OcrEngine` fournit de la détection de texte avec boîtes (`DetectedText` / bounding boxes), utile pour cibler le `blur/pixelate/scramble`.
- La détection visuelle “photo/visage/objet” n’est pas couverte nativement par OCR; il faut un second moteur ML (ex. ONNX Runtime) pour des classes visuelles supplémentaires.
- Win2D offre des effets de composition (blur et transformations) et supporte des **custom effects** (pixel shuffle/scramble par shader) quand les effets de base sont insuffisants.

### Performance et architecture recommandée
- Bonne latence si traitement GPU-first (bitmap/texture pipeline): capture -> effects -> encode.
- `OcrEngine` est souvent coûteux en temps réel: OCR au pas (`every N` frames) + suivi temporel des régions réduit la charge.
- Export “aplati” cohérent: recomposition frame à frame vers sortie vidéo unique (H.264/MP4 via API media standard Windows) sans écrire une version non anonymisée dans le produit final.

### Parité avec Web/iOS/Linux
- **Web:** mécanismes navigateur asynchrones + permissions navigateur similaires en UX, mais variabilité de support.
- **iOS:** capture ReplayKit + Vision + AVAssetWriter très proche du modèle live.
- **Linux:** dépendance Desktop Portal/Wayland/X11 plus hétérogène; Windows est plus stable côté API système si ciblage UWP/desktop classique modernisé.

## V1 recommendation
- Viser un mode **live redaction**:
  1) `GraphicsCapturePicker` -> démarrage session `Windows.Graphics.Capture`.
  2) OCR périodique via `OcrEngine` avec stabilisation des zones.
  3) Redaction visuelle ciblée (`Blur`, `Pixelate` custom effect) avec Win2D.
  4) Option visuelle `scramble` via custom effect customisée (déformation locale / permutation de blocs).
  5) Encodage direct du flux anonymisé vers un fichier vidéo final aplati.
- Afficher dès l’amorce: **best-effort + revue utilisateur obligatoire** avant finalisation/partage.

## V2
- Ajouter détection visuelle supplémentaire côté ONNX Runtime WinUI (visage/personne/logos) pour réduire les fausses négatives OCR.
- Implémenter cache de régions persistantes (zones utilisateur protégées + ROI verrouillées) pour amortir coût OCR.
- Ajouter fallback “détérioration contrôlée” si la détection chute: baisse fps / résolution temporaire + watermark de confiance.

## Risks
1. **Couverture incomplète**: OCR ne détecte pas tout (petit texte, overlays, effets) => fuite résiduelle possible.
2. **Perf variable**: 4k/60fps + OCR + effects + encode peut saturer selon GPU/CPU.
3. **Support API**: compatibilité WinRT/packaging, disponibilité dépendante runtime, privilèges capture et restrictions de plateforme.
4. **Falses attentes**: UX doit empêcher l’interprétation “anonymisation absolue”.
5. **Sécurité chaîne vidéo**: garantir suppression/rotation anti-artefacts des buffers non redacted intermédiaires.

## Sources
- Windows screen capture (Graphics Capture, permissions, picker, frame pool, sessions): https://learn.microsoft.com/en-us/windows/uwp/audio-video-camera/screen-capture
- Capture écran vers vidéo (media pipeline / enregistrement): https://learn.microsoft.com/en-us/windows/uwp/audio-video-camera/screen-capture-video
- OCR WinRT: https://learn.microsoft.com/en-us/uwp/api/windows.media.ocr.ocrengine
- Win2D features: https://learn.microsoft.com/en-us/windows/apps/develop/win2d/features
- Win2D custom effects: https://learn.microsoft.com/en-us/windows/apps/develop/win2d/custom-effects
- ONNX Runtime WinUI (optionnelle, détection visuelle complémentaire): https://learn.microsoft.com/en-us/windows/ai/models/get-started-onnx-winui

## Next step
- Valider un PoC Windows minimal (1 écran, OCR+blur+export MP4) en 1 sprint, avec une matrice de perf (1080p/1440p/4k) et preuve de non-présence de fichier clair final.
