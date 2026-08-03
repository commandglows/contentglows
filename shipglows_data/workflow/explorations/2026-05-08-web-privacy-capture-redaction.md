---
title: "Exploration Web: capture d’écran vidéo avec redaction dynamique"
date: 2026-05-08
topic: "web/browser privacy-capture"
status: draft
---

## Contexte synthétique
Spec ciblée: `shipglows_data/workflow/specs/app/SPEC-android-privacy-capture-dynamic-redaction.md`.
- Statut: en cours (Draft), mode best-effort, redaction V1 Android-only avec OCR ML Kit texte + visages + blur/pixelate/scramble.
- Exigences explicitement vues: pipeline n’offre pas l’anonymisation parfaite; ajout d’un écran de disclosure et relecture manuelle.
- But de cette exploration: vérifier la faisabilité **web/browser** pour un mode équivalent.

## Faisabilité (web)
Oui, faisable en V1, mais limité:
- `getDisplayMedia()` fournit un flux vidéo et impose consentement explicite à chaque capture; ne peut pas restreindre le choix écran AVANT sélection utilisateur et la permission ne se persiste pas entre sessions (`getDisplayMedia()` specs/security MDN).
- `MediaStreamTrackProcessor` + `VideoFrame` permettent une transformation par frame en JS/Worker.
- Le rendu et la ré-encodage peuvent se faire via `OffscreenCanvas` + `Canvas 2D` (blur/pixelate) ou GPU (`WebGL`/`WebGPU`) puis encodeur (WebCodecs `VideoEncoder`) pour un MP4 redactionné.
- Les performances en temps réel sont la contrainte clé (throttle OCR + frame dropping + pipeline asynchrone requis).

## V1 (web MVP)
- Capture: `navigator.mediaDevices.getDisplayMedia()`.
- Traitement: `MediaStreamTrackProcessor` (worker de préférence) pour recevoir `VideoFrame`.
- OCR: idéalement `TextDetector` quand dispo (Shape Detection) ou fallback WASM.
  - Text detection n’est pas stable/standardisée partout; disponibilité inégale, souvent non universelle.
- Redaction par région:
  - blur/crop de zones détectées;
  - pixelate via `imageSmoothingEnabled=false` + redraw réduit;
  - option "scramble" = redraw avec formes/aléa textuel (pas de réécriture réelle dans le buffer source).
- Encodage local: `VideoEncoder` ou pipeline MediaRecorder secondaire quand le coût est trop élevé.
- Export: uniquement version floutée/cachée, jamais du flux clear.

## V2 (amélioration)
- Gestion régionale plus fine avec APIs de **Region/Element Capture** quand supportées:
  - `CaptureController` + `CropTarget.fromElement()` pour réduire tôt la zone capturée.
  - améliore les perf et réduit le volume de données à traiter.
- Intégrer `Capture Handle` côté tab-collaboration:
  - évite l’effet de boucle/auto-capture de la propre page.
  - utile pour orchestration multi-app et UX (expositions controlées de `handle`).
- OCR fallback robuste: ajout WASM on-device (ex. Tesseract.js) pour plateformes sans TextDetector, en reconnaissant latence accrue et précision variable.

## Risques techniques
1. Variabilité browser:
   - TextDetection face/barres souvent en pilote d’implémentation/flags selon plate-forme.
   - `MediaStreamTrackProcessor`/`Generator` ont des différences de contexte global (window/worker) d’une implémentation à l’autre.
2. Performance:
   - OCR frame par frame sur 30/60 fps est trop coûteux; besoin de stratégie d’échantillonnage et d’amortissement.
3. Confidentialité/attaque de reprise:
   - la redaction est best-effort; possibilité de fuite par dépassement (`dropped frame`, bords des zones).
4. Support: WebGL/WebGPU/WebCodecs ne sont pas homogènes cross-OS; fallback nécessaire.

## Risques produit / sécurité
- Risque d’UX trompeuse si la UI suggère une anonymisation forte (interdire affirmation d’exhaustivité).
- Falses négatifs OCR: texte non détecté ou mal localisé ⇒ affichages clairs fugitifs.
- Stockage: éviter toute persistance d’images/PDF non redacted hors sandbox et documents temporaires contrôlés.

## Recommandation
- Lancer en **V1 web** avec:
  - traitement 100% client;
  - TextDetector conditionnel + fallback pixelation/blur basique quand indisponible;
  - cadence OCR réduite + suivi temporel des boîtes;
  - double garde-fou UI (best-effort + revue obligatoire).
- Reporter `region capture` et `capture handle` au **V2**, car utiles mais trop dépendantes du support navigateur aujourd’hui.

## Sources web (consultées)
- MDN Screen Capture API: `MediaDevices.getDisplayMedia`, consentement/permissions, `CropTarget`/`RestrictionTarget`, compat.
  - https://developer.mozilla.org/en-US/docs/Web/API/Screen_Capture_API
  - https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getDisplayMedia
- MDN WebCodecs API: accès bas niveau frames/encodeur/décodeur; feature dédiée aux workers.
  - https://developer.mozilla.org/en-US/docs/Web/API/WebCodecs_API
- MDN MediaStreamTrackProcessor / Generator + Insertable Streams.
  - https://developer.mozilla.org/en-US/docs/Web/API/MediaStreamTrackProcessor
  - https://developer.mozilla.org/en-US/docs/Web/API/MediaStreamTrackGenerator
- MDN Canvas 2D: filtre + pixelation (`imageSmoothingEnabled=false`) + manipulation pixel (`getImageData`/`putImageData`).
  - https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/filter
  - https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/imageSmoothingEnabled
  - https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Pixel_manipulation_with_canvas
- MDN/WebGPU API: disponibilité limitée/non baseline + contexte sécurisé.
  - https://developer.mozilla.org/en-US/docs/Web/API/WebGPU_API
- W3C Screen Capture WD 2025 (region capture + contraintes + permissions).
  - https://www.w3.org/TR/screen-capture/
- W3C Region Capture WD 2023 (`CropTarget`, `cropTo`).
  - https://www.w3.org/TR/mediacapture-region/
- W3C Capture Handle (identity): `setCaptureHandleConfig`, `getCaptureHandle`, `capturehandlechange`.
  - https://w3c.github.io/mediacapture-handle/identity/
- Chrome doc capture handle (statut/usage concret).
  - https://developer.chrome.com/docs/web-platform/capture-handle/
- Shape Detection (Chrome capabilities): détection visages/barcodes/texte, état et stabilité.
  - https://developer.chrome.com/docs/capabilities/shape-detection
- Source alternative OCR on-device/WASM:
  - https://tesseract.projectnaptha.com/
  - https://github.com/naptha/tesseract.js
