# Document des exigences produit (PRD)

**Projet** : Plugin SketchUp `vis_filets_generator` (« Vis & Filets ») — Générateur de filets paramétriques
**Version courante** : 1.10.1
**Date** : 2026-10-29

Le PRD décrit le *quoi* et le *pourquoi* ; le *comment* (algorithmes, entrées/sorties, limitations) est dans [FSD.md](FSD.md).

---

## 1. Contexte et problème

Les plugins de filetage existants pour SketchUp obligent à dessiner le profil à la main ou produisent des solides inutilisables (maillages non fermés, arêtes fusionnées par la tolérance interne de SketchUp, ~0,001″). Modéliser une pièce filetée destinée à l'impression 3D FDM (tige, écrou, trou taraudé) est donc long et peu fiable.

## 2. Utilisateurs et usages

- **Utilisateurs** : modeleurs SketchUp qui conçoivent des pièces mécaniques, en particulier pour l'impression 3D FDM ; plugin public diffusé sur GitHub et SketchUcation.
- **Usages** :
  - générer une tige filetée et/ou un écrou hexagonal assortis, en ISO ou en profil optimisé FDM ;
  - générer un taraud et le soustraire d'un solide pour obtenir un trou taraudé ;
  - placer directement les pièces à l'endroit voulu du modèle, perpendiculairement à une face.

## 3. Objectifs et critères de succès

- Solides **watertight** acceptés tels quels par le slicer.
- Géométrie ISO correcte (ISO 261 / ISO 724, DIN 934) et profils FDM imprimables sans support.
- Fonctionne dans toute unité de modèle (mm, cm, m…) et de SketchUp 2014 à la dernière version.
- Génération et placement en quelques clics, annulables en un seul Ctrl+Z.

## 4. Périmètre

**Inclus** : tige filetée, écrou hexagonal, taraud ; profils ISO métrique et FDM ; chanfrein d'entrée ; placement à la souris ; interface en anglais ; documentation EN + FR.

**Exclu** : filet à gauche ; tête de vis (DIN 933) ; filets non métriques (UNC/UNF, gaz, trapézoïdaux normalisés) ; export STL (assuré par SketchUp ou ses extensions).

## 5. Exigences fonctionnelles

| ID | Exigence | Priorité | Statut |
|----|----------|----------|--------|
| EF-01 | Générer une tige filetée paramétrique (diamètre D, pas P, hauteur, segments par tour multiple de 6) | indispensable | livrée en v1.0.0 |
| EF-02 | Profil ISO métrique 60° avec presets M3–M32 (pas auto-rempli, toujours modifiable) | indispensable | livrée en v1.0.0 (gamme M3–M32 en v1.8.0) |
| EF-03 | Profil optimisé FDM : angle de flanc constant réglable, noyau minimal (%D), fond plat trapézoïdal si nécessaire | indispensable | livrée en v1.2.0 (fond trapézoïdal en v1.6.0) |
| EF-04 | Générer un écrou hexagonal DIN 934 assorti, avec jeu radial (gap) | indispensable | livrée en v1.0.0 (booléen hex − alésage en v1.8.0) |
| EF-05 | Respecter l'unité courante du modèle pour toutes les dimensions | indispensable | livrée en v1.1.0 |
| EF-06 | Mémoriser les paramètres, séparément pour chaque mode ISO / FDM | important | livrée en v1.2.0 (par mode en v1.6.0) |
| EF-07 | Hauteurs séparées pour la tige et l'écrou | important | livrée en v1.4.0 |
| EF-08 | Chanfrein d'entrée optionnel (haut de la tige, deux faces de l'écrou), hauteur réglable | important | livrée en v1.6.0 (outil sablier de l'écrou en v1.7.0) |
| EF-09 | Générer un taraud (alésage fileté, pointe 45°, corps, carré d'entraînement) prêt à soustraire ; couleur reprise du matériau sélectionné | important | livrée en v1.9.0 |
| EF-10 | Retour visuel pendant le calcul : barre d'état, fenêtre « Generating… », curseur d'attente | souhaitable | livrée en v1.9.1 (fenêtre et curseur en v1.10.0) |
| EF-11 | Une génération complète (placement compris) = une seule étape d'annulation | important | livrée en v1.10.0 |
| EF-12 | Bouton « Place with mouse » : les pièces suivent la souris avec l'inférence SketchUp ; Esc, clic droit ou autre outil annule sans rien laisser | important | livrée en v1.10.0 |
| EF-13 | Placement perpendiculaire à la face survolée (y compris dans un groupe/composant) : tige et écrou posés, taraud enfoncé de sa longueur filetée | important | livrée en v1.10.0 |
| EF-14 | Aperçu de placement **cylindrique** adapté aux pièces rondes : cercles bas et haut, contour selon la caméra, axe en pointillés | souhaitable | livrée en v1.10.1 |

## 6. Exigences non fonctionnelles

| ID | Exigence | Priorité | Statut |
|----|----------|----------|--------|
| NF-01 | Robustesse : solides watertight, sans arête parasite ; géométrie construite au-dessus de la tolérance SketchUp (scale-trick) | indispensable | livrée |
| NF-02 | Compatibilité SketchUp 2014 → dernière version (WebDialog / HtmlDialog), Ruby 2.0+ (pas de syntaxe Ruby ≥ 2.3) | indispensable | livrée (compat. Ruby 2.2 en v1.9.2) |
| NF-03 | Aucune dépendance externe ; booléens via SketchUp Pro ou Eneroth Solid Tools, avec repli explicite s'ils sont absents | indispensable | livrée |
| NF-04 | Langue : interface en anglais (langue de référence) ; documentation utilisateur EN + FR | important | livrée en v1.9.2 |
| NF-05 | Performance : génération par `PolygonMesh` ; aperçu de placement fluide pendant les mouvements de souris et l'orbite | important | livrée |
| NF-06 | Annulation propre : annuler le placement ne laisse aucune pièce ni étape d'annulation parasite | important | livrée en v1.10.0 |

## 7. Contraintes et dépendances

- API Ruby SketchUp ; booléens disponibles seulement avec SketchUp Pro ou l'extension gratuite Eneroth Solid Tools.
- Tolérance interne de SketchUp (~0,001″) : impose le scale-trick pour les petits pas.
- Diffusion : dépôt GitHub (releases avec `.rbz`) et SketchUcation (plugin `thread_generator_dro`, mis à jour par l'auteur ; chaque nouveau `.rbz` dépublie le plugin jusqu'à sa revalidation par les modérateurs ; images d'article limitées à 690 px de large).

## 8. Critères d'acceptation

| Exigences | Critère |
|-----------|---------|
| EF-01, EF-02, NF-01 | Une tige M10 × 1,5 est un solide (Entity Info : « Solid Group ») de diamètre extérieur 10 mm, sans arête parasite. |
| EF-03 | En profil FDM, l'angle de flanc vaut l'angle saisi ; le fond devient plat quand le noyau minimal est atteint. |
| EF-04 | L'écrou se visse sur la tige générée avec le même profil (jeu = gap) ; faces haut et bas planes. |
| EF-05 | Dans un modèle en mètres, saisir 10 donne un diamètre de 10 m. |
| EF-09 | Le taraud soustrait d'un bloc donne un trou taraudé qui accepte la tige de même profil. |
| EF-11, NF-06 | Un seul Ctrl+Z supprime toute la génération ; Esc pendant le placement ne laisse aucune pièce. |
| EF-12, EF-13 | Sur une face inclinée, les pièces sont alignées sur sa normale ; le taraud est enfoncé de sa longueur filetée. |
| EF-14 | Pendant le placement, chaque pièce est représentée par un cylindre orange englobant (écrou : cercle par les sommets de l'hexagone) avec son axe en pointillés ; le contour suit l'orbite, en perspective comme en projection parallèle. |
| NF-02 | Le plugin se charge et génère sous SketchUp 2017 (Ruby 2.2) et sous la dernière version. |

## 9. Questions ouvertes et décisions

**Décisions**
- 2026-04-30 : script Ruby SketchUp plutôt que fichier `.skp` (format fermé) ; scale-trick ×100 contre la tolérance de SketchUp.
- 2026-05-02 : chanfrein et écrou par booléens (SketchUp Pro / Eneroth) plutôt que par géométrie maison.
- 2026-05-03 : chanfrein de l'écrou par un outil sablier unique (un seul booléen).
- 2026-10-09 : la génération entière est une seule opération d'annulation ; le clic de placement y est chaîné.
- 2026-10-29 : aperçu de placement cylindrique (option « contour selon la caméra » retenue face au fil de fer à génératrices fixes) ; rayon de l'écrou = cercle passant par les sommets de l'hexagone ; axe en pointillés ajouté.

**Questions ouvertes**
- Filet à gauche, tête de vis DIN 933 : à prévoir ?
- Profil FDM : valeurs par défaut à valider selon les matériaux et imprimantes.
- v1.10.1 envoyée sur SketchUcation le 2026-10-29 : en attente de validation par les modérateurs.

## 10. Historique des livraisons

| Date | Version / commit | Exigences livrées |
|------|------------------|-------------------|
| 2026-05-01 | v1.0.0 (`139dc6d`) | EF-01, EF-02, EF-04 |
| 2026-05-01 | v1.1.0 (`ca4806d`) | EF-05, corrections écrou et chanfrein |
| 2026-05-01 | v1.2.0 (`592d925`) | EF-03, EF-06 |
| 2026-05-01 | v1.3.0 (`fdc9b07`) | faces haut/bas de l'écrou planes (NF-01) |
| 2026-05-01 | v1.4.0 (`81d2601`) | EF-07, dialogue en anglais |
| 2026-05-02 | v1.5.0 (`25ef890`) | stabilisation de l'écrou |
| 2026-05-02 | v1.6.0 (`8749e58`) | EF-08 (booléen), EF-03 (fond trapézoïdal), EF-06 (par mode) |
| 2026-05-03 | v1.7.0 (`5353702`) | EF-08 (outil sablier de l'écrou) |
| 2026-05-03 | v1.8.0 (`eecf9cf`) | EF-04 (booléen hex − alésage), EF-02 (M3–M32) |
| 2026-05-03 | v1.8.1 (`580c510`) | aide hauteur d'écrou FDM, chanfrein P/2 auto |
| 2026-05-04 | v1.9.0 (`d40a7da`) | EF-09 |
| 2026-05-04 | v1.9.1 (`9ef8f07`) | EF-10 (barre d'état) |
| 2026-05-05 | v1.9.2 (`f4609b2`) | NF-02 (Ruby 2.2), NF-04 — première publication SketchUcation |
| 2026-10-09 | v1.10.0 (`59fe5a8`) | EF-10 (fenêtre, curseur), EF-11, EF-12, EF-13, NF-06 — release GitHub |
| 2026-10-29 | v1.10.1 (`a607a36`) | EF-14 — release GitHub ; SketchUcation mise à jour depuis la v1.9.2 (en attente de validation) ; nouvelle vidéo de démonstration |
