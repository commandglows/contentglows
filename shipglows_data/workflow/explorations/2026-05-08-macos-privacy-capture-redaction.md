---
artifact: exploration
created: "2026-05-08"
updated: "2026-05-08"
status: draft
scope: "macOS capture privacy redaction"
confidence: medium
risk_level: high
security_impact: "yes"
---

# Exploration macOS: Capture ecran dynamique avec redaction

## Context

Cette exploration transpose le mode Android `privacy_best_effort` au desktop macOS: capturer un ecran, une fenetre ou une zone, detecter les textes et visages dans les pixels rendus, appliquer une redaction visuelle, puis exporter uniquement un PNG/MP4 aplati marque comme confidentiel. L'objectif produit reste identique: reduire les fuites dans des videos publiques sans rendre l'interface incomprehensible.

Le mode ne peut pas promettre une anonymisation parfaite. Sur macOS, comme sur iOS et Android, les APIs de capture donnent des pixels deja composes, pas un arbre semantique modifiable de l'app tierce. Les textes ne peuvent donc pas etre "remplaces" dans l'app source; ils peuvent seulement etre couverts, floutes, pixelises ou remplaces visuellement dans la sortie ContentGlowz.

La contrainte de privacy est forte: le flux partageable doit etre un export aplati, sans couche de redaction editable, sans texte OCR stocke, sans frames claires persistantes dans l'historique normal, et avec une revue post-production obligatoire avant partage/export.

## Feasibility

macOS est techniquement favorable pour une V1 locale grace a `ScreenCaptureKit`. `SCStream` permet de capturer du contenu partageable via un `SCContentFilter` et une `SCStreamConfiguration`, puis de recevoir des frames via un `SCStreamOutput`. Apple fournit aussi `SCScreenshotManager` pour les captures fixes. Cela donne une base native macOS plus adaptee que les anciens chemins indirects QuickTime/Screenshot pour une pipeline app controlee.

La detection des zones sensibles peut s'appuyer sur Vision:
- `VNRecognizeTextRequest` detecte et reconnait du texte, avec des options utiles comme `recognitionLevel` pour arbitrer vitesse/precision et `minimumTextHeight` pour ignorer les tres petits elements.
- `VNDetectFaceRectanglesRequest` retourne des boites de visages, suffisantes pour une anonymisation visuelle par flou ou pixelisation.

La redaction peut etre appliquee par Core Image et Metal. `CIContext` peut rendre vers `CVPixelBuffer`, `IOSurface` ou `MTLTexture`, et peut etre initialise avec un device Metal. Pour la video, la sortie peut ensuite etre encodee avec `AVAssetWriter`, qui ecrit un conteneur media comme MP4/MOV et doit etre considere single-use par fichier.

Limites importantes:
- Certaines surfaces protegees ou apps DRM peuvent etre noires, bloquees ou non capturables. Apple Support mentionne deja que certaines apps peuvent ne pas permettre l'enregistrement de leurs fenetres.
- Le droit de capture depend des permissions macOS. L'utilisateur gere l'acces dans System Settings > Privacy & Security > Screen & System Audio Recording.
- Le traitement temps reel peut rater des textes pendant scroll rapide, animations, faible contraste, petite taille ou contenu partiellement masque.
- ScreenCaptureKit capture un flux de pixels; il ne fournit pas les bornes de champs, libelles ou messages des apps tierces.

Conclusion faisabilite: une V1 macOS est faisable en best-effort local, mais seulement avec wording produit prudent, revue manuelle, et arret/quarantaine si la pipeline ne peut pas finaliser une sortie redigee coherente.

## V1

Objectif V1: produire un export macOS local aplati ou le chemin normal de preview/share ne voit que la version redigee.

Scope recommande:
- Capture screenshot via `SCScreenshotManager` ou capture one-frame via ScreenCaptureKit, redaction bitmap, sauvegarde PNG aplatie.
- Capture video via `SCStream` + `SCStreamOutput`, traitement frame-by-frame, rendu Core Image/Metal vers pixel buffers, encodage `AVAssetWriter`.
- Detection texte avec `VNRecognizeTextRequest`, en mode rapide par defaut sur video et plus precis sur screenshot ou frames echantillonnees.
- Detection visage avec `VNDetectFaceRectanglesRequest`.
- Styles texte: `blur`, `pixelate`, `scramble` visuel. Le scramble doit couvrir les vrais pixels et dessiner de faux glyphes/segments sans stocker le contenu reconnu.
- Styles photo/face: `off`, `blur`, `pixelate`.
- Stabilisation temporelle: persistance courte des boites, expansion conservatrice, union des regions proches, et fallback strong pendant scroll/motion.
- Metadata asset: `privacyMode=true`, `privacyStatus=privacy_best_effort`, `reviewState=needsReview`, styles/strength/stats agreges. Ne pas stocker texte OCR, thumbnails clairs, chemins temporaires clairs, ni observations Vision brutes.
- UX: disclosure explicite avant capture, permission macOS guidee si necessaire, review acknowledgement avant share/export.

Comportement d'erreur:
- Si la permission Screen & System Audio Recording est absente, ne pas demarrer et guider vers les reglages macOS.
- Si Vision ou le rendu/encodage echoue, ne pas sauvegarder un asset normal marque privacy.
- Si des fichiers ou buffers clairs temporaires sont inevitables, les garder app-private, hors historique, non partageables, et les supprimer au succes/echec; si suppression impossible, quarantaine locale et warning cleanup.
- Si la pipeline prend trop de retard, reduire fps/resolution ou force `strong`; si la coherence reste insuffisante, stopper plutot que produire une fausse promesse.

## V2

V2 devrait ameliorer la robustesse plutot que promettre une garantie:
- Mode fenetre/app cible avec filtres ScreenCaptureKit plus fins pour reduire les zones a analyser.
- Suivi temporel plus avance: optical flow, tracking de regions, detection de cuts, hysteresis par couche.
- Detection complementaire de documents/cartes via Vision rectangles ou heuristiques image-like pour photos, avatars, documents, QR codes et cartes.
- UI de revue locale plus riche: timeline des zones redigees, jump vers frames a risque, reprocessing en `strong`.
- Politique de qualite: score interne non affiche comme garantie, seulement utilise pour demander une revue plus stricte ou bloquer le partage direct.
- Exploration des performances par familles Mac Apple silicon/Intel, resolutions externes, multi-display et audio system capture.

## Risks

- Faux negatifs OCR: texte petit, police fine, faible contraste, motion blur, scroll rapide, sous-titres, URLs, tokens, notifications transitoires.
- Faux sentiment de securite: le wording doit rester "best-effort", "non exhaustif", "manual review required".
- Fuite temporaire locale: toute capture claire intermediaire augmente le risque en cas de crash, logs, thumbnails, autosave ou selection accidentelle.
- Performance: Vision + Core Image + encodage peuvent saturer CPU/GPU a haute resolution ou multi-ecran.
- Permissions et UX macOS: l'utilisateur peut refuser ou retirer Screen & System Audio Recording; l'app doit se recuperer proprement.
- Contenu non capturable/protege: certains contenus peuvent etre noirs ou absents; ne pas presenter cela comme une redaction reussie.
- Audio: la tache porte sur la redaction visuelle. Si la capture inclut l'audio systeme ou micro, les donnees sensibles parlees restent hors scope V1 sauf option explicite de mute.
- Compatibilite App Store/notarisation: la capture ecran est sensible; l'app doit etre transparente sur l'enregistrement et l'usage local des donnees.

## Sources

Sources officielles Apple consultees le 2026-05-08:

- ScreenCaptureKit / capture macOS:
  https://developer.apple.com/documentation/ScreenCaptureKit/capturing-screen-content-in-macos
  https://developer.apple.com/documentation/screencapturekit/scstream
- Vision texte et visages:
  https://developer.apple.com/documentation/vision/vnrecognizetextrequest
  https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest
- Core Image / Metal:
  https://developer.apple.com/documentation/CoreImage
  https://developer.apple.com/documentation/coreimage/cicontext
- AVAssetWriter:
  https://developer.apple.com/documentation/avfoundation/avassetwriter
- Permissions macOS / Screen & System Audio Recording:
  https://support.apple.com/en-euro/guide/mac-help/mchld6aa7d23/mac
  https://support.apple.com/guide/mac-help/take-a-screenshot-mh26782/mac
  https://support.apple.com/en-la/102618

## Recommendation

Demarrer macOS par une V1 native locale, best-effort, sans fichier clair expose au parcours normal: ScreenCaptureKit pour le flux, Vision pour boites texte/visages, Core Image/Metal pour redaction, `AVAssetWriter` pour ecrire un MP4 aplati. Le produit doit imposer une revue post-production avant partage et conserver le statut `privacy_best_effort`.

Ne pas lancer une promesse "privacy-safe" ou "anonymisation automatique". La recommandation durable est un mode d'assistance a la redaction: utile pour reduire fortement le travail manuel, mais jamais suffisant sans verification humaine avant publication.
