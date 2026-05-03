# Spécifications fonctionnelles détaillées (FSD)

**Projet** : Plugin SketchUp `vis_filets_generator` — Générateur de filets paramétriques
**Version** : 1.8.0
**Date** : 2026-05-03

---

## 1. Objectif

Plugin SketchUp (format `.rbz`) générant des **tiges filetées** et **écrous hexagonaux** paramétriques directement dans le modèle SketchUp actif. Deux profils de filet : ISO métrique standard et optimisé impression 3D FDM.

Compatibilité : SketchUp 2014 à la version la plus récente.

---

## 2. Paramètres utilisateur

| # | Paramètre | Type | Valeurs / défaut |
|---|-----------|------|-----------------|
| 1 | Profil | Radio | ISO métrique / Optimisé plastique FDM |
| 2 | D (diamètre nominal) | Dropdown + saisie libre | M3–M32 (ISO) ; saisie libre (FDM) |
| 3 | Pas P | Saisie numérique | Auto-rempli depuis table ISO ou 0,25×D (FDM), toujours éditable |
| 4 | Hauteur | Saisie numérique | mm dans l'unité du modèle |
| 5 | Pièces | Checkboxes | ☑ Tige filetée  ☑ Écrou hexagonal (combinables) |
| 6 | Gap | Saisie numérique | 0,3 mm défaut ISO ; 0,4 mm défaut plastique |
| 7 | Chanfrein d'entrée | Case à cocher + hauteur (mm) | Non (défaut) ; hauteur = 1 pas |
| 8 | Segments/tour | Entier multiple de 6 | 24 (défaut) |
| 9 | Angle / verticale (°) | Entier 10–85, visible si profil plastique | 60° |
| 10 | Min. core (%D) | Entier, visible si profil plastique | 70% |

Chaque mode (ISO / FDM) mémorise ses propres paramètres indépendamment — restaurés au switch de mode.

Toutes les valeurs dimensionnelles sont dans l'**unité courante du modèle SketchUp** (mm, cm, m…).

---

## 3. Géométrie générée

### 3.1 Tige filetée

- Filet externe hélicoïdal, axe Z, base à l'origine
- Diamètre extérieur : D
- Profil ISO : V 60°, fond = D/2 − 5H/8 (H = P√3/2)
- Profil plastique FDM : flancs à angle constant = `max_overhang_angle` (depuis la verticale). Si la profondeur théorique dépasse `r_major − r_minor_min` (contrainte min_core), le fond devient **plat** à `r_minor_min` (profil trapézoïdal) — l'angle ne change jamais.
- Vertices placés exactement aux transitions de profil (crêtes, fonds, transitions flanc/plat) — arêtes vives, pas de lissage
- Extrémités : faces plates (z=0 et z=hauteur)
- Chanfrein d'entrée (optionnel) : boolean subtract d'un ring frustum en haut de la tige (hauteur = `chamfer_height`, défaut = 1 pas)

### 3.2 Écrou hexagonal

Généré par **boolean subtract** (prisme hex plein − bore rod) :
- Hauteur = paramètre Hauteur
- Même profil de filet que la tige (ISO ou plastique), gap appliqué au rayon
- Bore rod s'étend de 0,01 unité sous z=0 et 0,5 unité au-dessus de z=L → coupes parfaitement nettes
- Solide watertight sans arêtes parasites

**Taille hex (travers-plats s_flat) :**
- Preset ISO M3–M32 : table DIN 934
- FDM plastique (saisie libre) : ISO de taille ≥ D le plus proche, sinon 2×D
- ISO saisie libre : ISO ≥ D le plus proche, sinon 1,75×D

### 3.2 Écrou hexagonal — chanfrein

- Outil sablier unique (cone_bas + cylindre_central + cone_haut) soustrait en **un seul boolean**
- Le cylindre central (r < r_bore_min) traverse l'alésage sans toucher le filet
- Fiable sur toute la gamme M3–M32 — élimine les échecs de chaînage booléen

### 3.3 Génération simultanée

Si tige + écrou cochés : générés à l'**origine commune** (x=0). Pendant le chanfrein, l'écrou est temporairement décalé pour éviter les interférences booléennes avec la tige, puis ramené à x=0.

---

## 4. Architecture technique

### 4.1 Structure des fichiers

```
vis_filets_generator.rb           # Loader + SketchupExtension
vis_filets_generator/
  main.rb                         # Menu + guard @loaded
  presets.rb                      # Tables ISO M3–M32 + FDM pitches
  profiles.rb                     # IsoProfile, PlasticProfile
  geometry.rb                     # Génération PolygonMesh
  dialog.rb                       # UI WebDialog / HtmlDialog
```

### 4.2 Scale-trick adaptatif

Construction à `SCALE×` (100 si petit, 1 si grand) puis `group.transform!(1/SCALE)`. Critère : `pitch/N_theta * unit_factor < 0,1"` → SCALE=100, sinon SCALE=1. Garantit que les arêtes restent au-dessus de la tolérance interne SketchUp (~0,001").

### 4.3 Unité du modèle

`unit_factor` lit `model.options['UnitsOptions']['LengthUnit']` — toutes les coordonnées = `valeur × SCALE × uf`. L'utilisateur saisit les dimensions dans l'unité affichée par SketchUp (ex. 10 m → objet de 10 m).

### 4.4 Colonnes hélicoïdales

Pour chaque colonne angulaire i : z-positions placées exactement aux transitions de profil (crêtes, fonds, transitions trapézoïdales). Pas de grille régulière → arêtes vives sans arrondis. Colonnes uniformisées par `pad_columns!` ; faces dégénérées ignorées (`unless dup_i`).

---

## 5. Limitations connues

- Chanfrein booléen : fiable sur toute la gamme M3–M32 (validé M3–M12)
- Filet à droite uniquement
- Pas de tête de boulon (vis hex DIN 933) — écrou DIN 934 uniquement
- N_THETA doit être multiple de 6 (validé automatiquement dans le dialog)
