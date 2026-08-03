---
artifact: exploration
created: "2026-05-08"
status: draft
scope: "Linux desktop privacy capture redaction"
risk_level: high
security_impact: "yes"
---

# Exploration Linux desktop: capture d’écran avec redaction dynamique

## Faisabilité

Oui, mais seulement selon le protocole de la session desktop.

- **Mode recommandé V1 (Wayland/X11 modernes)**: capturer via **xdg-desktop-portal** (`ScreenCast` + `RemoteDesktop`) → ouvrir un remote PipeWire → traiter/transformer les frames en local avec **GStreamer/GL** → encoder un flux déjà anonymisé.
- **Mode fallback**: quand le portail est indisponible, X11 peut fournir une capture framebuffer via Xlib/XCB (`XGetImage`), mais c’est un chemin de repli, moins stable et réservé aux sessions Xorg.

Points clés de faisabilité:
- `org.freedesktop.portal.ScreenCast` permet la création de session, la sélection de sources (moniteur/fenêtre/virtuel), le choix du mode curseur, puis `Start`.
- Les résultats de `Start` exposent des streams `PipeWire` (id + `pipewire-serial`) et recommandations de cible via `PW_KEY_TARGET_OBJECT`.
- `org.freedesktop.portal.RemoteDesktop` permet la création de session et peut être utilisé pour activer partage écran + entrée.
- `open_pipewire_remote()` renvoie un FD sur le remote PipeWire de la session: c’est la base d’un pipeline d’ingestion vidéo.
- GStreamer fournit des éléments de transformation temps réel (`gaussianblur`) et d’encodage (`x264enc`), donc la chaîne “capture → redaction → encode” est techniquement viable en local.
- OCR/vision on-device: Tesseract (C++ API), OpenCV DNN face/text, et PaddleOCR disposent de pipelines d’analyse utiles, mais la qualité/latence imposent un compromis réel.

## Couches techniques Linux

1. **Portail (permission / UX de consentement)**
   - Bus object: `org.freedesktop.portal.Desktop`.
   - Objets `Session`, `ScreenCast`, `Request` et signaux d’état pour gestion consentement/close.
   - Session versionnée (`version` côté interface) : nécessité de tolérer certaines API absentes selon version.

2. **Capture PipeWire**
   - `PipeWire` fournit l’échange de buffers vidéo entre services, avec remotes et négociation de formats.
   - Le stream screencast arrive typiquement en raw vidéo depuis le remote; il faut connecter via la cible/serial correcte pour éviter la confusion d’identifiants réutilisés.

3. **Traitement vidéo (redaction)**
   - GStreamer: pipeline graph orientée filtres/encoders.
   - Flou local via filtre vidéo (`gaussianblur`).
   - Encodage recommandé via encodeur H264 + mux (éviter AVI; préférer MP4/Matroska).
   - Points de perf critiques: latence encodeur (`x264enc` peut staller si les files/queues sont trop contraintes).

4. **Détection texte/image**
   - **Tesseract API**: pipeline OCR C++ avec retour de rectangles de composants (`GetComponentImages`/`ResultIterator`) pour générer des boîtes sans persister le texte.
   - **OpenCV**: détection texte EAST (`TextDetectionModel_EAST`) et détection de visages via `FaceDetectorYN`.
   - **PaddleOCR**: docs d’implémentation on-device (principalement mobile/native SDK), utile pour options de redaction haute performance si le team choisit de porter un modèle léger.

5. **Fallback X11**
   - Xlib/XCB: API d’accès framebuffer (`XGetImage`, `XShmGetImage`) pour capture d’images de fenêtres/zone.
   - Fallback utile sur Xorg quand Portal/Wayland est indisponible; pas une solution uniforme côté Wayland.

## Proposition V1 / V2

### V1 (prioritaire)
- **But**: mode “capture dynamique avec redaction temps réel” pour sessions desktop courantes.
- **Chemin**:
  1) créer session `ScreenCast`; 2) sélectionner source; 3) `Start` + lecture stream PipeWire; 4) appliquer détection+flou/masquage texte/visage; 5) encoder directement en vidéo sortie (pas de clear cache).
- **Limites**: OCR/frame detection partielle (petit texte, animations rapides, polices complexes), consommation CPU/GPU élevée, risque de dropout.

### V2 (évolutif)
- Ajouter suivi temporel robuste des boîtes (tracking), modes de redaction plus intelligents (pixelate, scramble visuel), et un service de vérification qualité plus strict.
- Ajouter pré-sélection de zones persistantes (UI masking) pour réduire les fausses détections.
- Envisager une chaîne hybride “desktop portal + fallback X11 + GPU shader backend” si un pipeline CPU pur montre des limites de perf.

## Risques

- **Compatibilité desktop**: `ScreenCast`/`RemoteDesktop` peuvent varier selon backend/DE (GNOME/KDE/compositor); nécessité de gérer proprement `interface missing` et permissions.
- **Performance**: OCR + blur + encode peut saturer; qualité audio/vidéo dépend du réglage encodeur (`x264enc` peut introduire de la latence/buffering).
- **Couverture X11/Wayland**: fallback X11 non universel en environnement Wayland.
- **Sécurité produit**: redaction visuelle toujours best-effort; impossible de garantir “zero leak” tant que le modèle détecte mal une zone à temps.
- **Opérations persistées**: il faut garantir un seul artefact redacted écrit localement; éviter tout fichier clair intermédiaire ou le sécuriser immédiatement.

## Sources (consultées, liens officiels/techniques)

### xdg-desktop-portal (Linux desktop)
- XDG API Reference: <https://flatpak.github.io/xdg-desktop-portal/docs/api-reference>
- ScreenCast interface: <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html>
- Remote Desktop interface: <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.RemoteDesktop.html>
- Intro xdg-desktop-portal: <https://flatpak.github.io/xdg-desktop-portal/>

### PipeWire
- PipeWire docs home: <https://docs.pipewire.org/>
- PipeWire API (SPA params): <https://docs.pipewire.org/group__spa__param.html>
- PipeWire video raw format / SPA: <https://docs.pipewire.org/video_2raw_8h.html>
- PipeWire protocol native/env remotes: <https://sanchayanmaity.pages.freedesktop.org/pipewire/page_module_protocol_native.html>
- DMA-BUF sharing docs: <https://docs.pipewire.org/page_dma_buf.html>
- Libportal `open_pipewire_remote`: <https://libportal.org/method.Session.open_pipewire_remote.html>

### GStreamer (pipeline + filtres + encode)
- `gaussianblur` (effet vidéo temps réel): <https://gstreamer.freedesktop.org/documentation/gaudieffects/gaussianblur.html>
- `x264enc` propriétés/exemples (latence, encode): <https://gstreamer.freedesktop.org/documentation/x264/index.html>
- GStreamer plugin docs: <https://gstreamer.freedesktop.org/documentation/>

### Vision / OCR on-device
- Tesseract API example: <https://tesseract-ocr.github.io/tessdoc/APIExample.html>
- Tesseract API reference: <https://tesseract-ocr.github.io/tessapi/5.x/a02438.html>
- OpenCV cascade face tutorial (approche classique): <https://docs.opencv.org/4.x/db/d28/tutorial_cascade_classifier.html>
- OpenCV DNN face detection (FaceDetectorYN): <https://docs.opencv.org/4.x/d0/dd4/tutorial_dnn_face.html>
- OpenCV TextDetectionModel_EAST: <https://docs.opencv.org/4.x/d8/ddc/classcv_1_1dnn_1_1TextDetectionModel__EAST.html>
- PaddleOCR on-device deployment: <https://paddlepaddle.github.io/PaddleOCR/main/en/version3.x/deployment/on_device_deployment.html>

### X11 fallback
- Xlib C interface (GetImage): <https://x.org/releases/current/doc/libX11/libX11/libX11.pdf>
- X11/Xlib guide: <https://xorg.freedesktop.org/wiki/guide/xlib-and-xcb/>

## Recommandation

Pour une exploration “durable” Linux desktop, démarrer par **V1 hybride**:
- **canal principal** = `xdg-desktop-portal + PipeWire + GStreamer + redaction visuelle`,
- **canal de compatibilité** = fallback X11 uniquement sur sessions Xorg.

Objectif réaliste: sécurité pratique (pas d’artefact clair par défaut), en assumant une transparence explicite “best-effort” et un contrôle QA (relecture obligatoire avant export).
