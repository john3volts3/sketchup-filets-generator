# vis_filets_generator — SketchUp Plugin

> **Finally — a thread plugin that just works.**
> Watertight solids, correct ISO geometry, FDM-ready profiles, and a lead-in chamfer. No manual profiling, no broken meshes, no workarounds.

Parametric generator for **threaded rods** and **hex nuts** in SketchUp, optimised for FDM 3D printing. Compatible with SketchUp 2014 through the latest version.

---

## Why this plugin?

Existing SketchUp thread plugins either require drawing the profile by hand or fail to produce usable solids. This plugin generates **watertight solids** ready for the slicer, in any SketchUp unit (mm, cm, m…).

## Installation

1. Download `build/vis_filets_generator.rbz`
2. In SketchUp: **Window → Extension Manager → Install Extension**
3. Select the `.rbz` file
4. Restart SketchUp

## Usage

Menu **Extensions → Vis & Filets → Generate…**

| # | Parameter | Description |
|---|-----------|-------------|
| 1 | **Thread type** | ISO metric (60°) or FDM plastic optimised (V-profile, angle-limited) |
| 2 | **D** | Nominal diameter — M3–M20 dropdown (ISO) or free input |
| 3 | **Pitch P** | Auto-filled from ISO table, always editable |
| 4 | **Parts** | ☑ Threaded rod  ☑ Hex nut (combinable) |
| 5 | **Rod height** | Length of the threaded rod |
| 6 | **Nut height** | Height of the hex nut |
| 7 | **Gap** | Radial clearance added to nut bore (default 0.3 mm ISO / 0.4 mm plastic) |
| 8 | **Chamfer** | Thread lead-in chamfer on rod (top) and nut (both faces) — boolean subtract |
| 9 | **Chamfer height** | Chamfer axial height (default = 1 pitch), visible when chamfer is checked |
| 10 | **Segments / turn** | Angular resolution, multiple of 6 (default 24) |
| 11 | **Max overhang angle** | FDM plastic only — flank angle from vertical (default 60°) |
| 12 | **Min. core %D** | FDM plastic only — minimum core diameter as % of D (default 70%) |

> **Units**: all values are entered in the current SketchUp model unit. If the model is in metres, entering `10` generates a 10-metre diameter thread.

## Thread profiles

### ISO metric
Standard 60° V-profile per ISO 261 / ISO 724. Vertices placed exactly at crests and roots — sharp edges, no mesh smoothing.

### FDM plastic optimised
Flank angle is **always constant** = `max_overhang_angle` regardless of pitch. Thread depth:
`depth = (P/2) × tan(angle_from_vertical)`

If the computed depth would bring the root below `min_core`, a **flat root** is used instead (trapezoidal profile) — the angle never changes, only the flat width grows.

| Angle (from vertical) | Depth M10 (P=1.5mm) | From horizontal |
|---|---|---|
| 45° | 0.75 mm | 45° — universal limit |
| 60° | 1.30 mm | 30° — standard printer |
| 70° | 2.06 mm | 20° — good cooling |

Each mode (ISO / FDM) remembers its own parameters independently — restored on mode switch.

## Hex nut

Generated as a single `PolygonMesh` with no booleans:
- Hexagonal outer shape DIN 934 (M3–M20 table built-in)
- Threaded bore: `r_bore = r_thread ± gap` (gap applied to radius)
- Watertight solid guaranteed

## Thread lead-in chamfer

Boolean subtract, height = `chamfer_height` (default 1 pitch):
- **Rod**: ring frustum subtracted from the top — crests taper to root radius over the chamfer height.
- **Nut**: two solid frustums subtracted from top and bottom faces — bore opens conically on entry.
- Requires SketchUp Pro (native Solid Tools) or the **Eneroth Solid Tools** plugin (free, SketchUp Make compatible). Detected automatically.

## Technical notes

### Adaptive scale trick
SketchUp internal tolerance ≈ 0.001". For mm/cm threads, the plugin builds geometry at **100×** then applies `group.transform!(1/100)`. In metres, geometry is already large (SCALE = 1).

### Compatibility
- SketchUp 2014–2016: `UI::WebDialog`
- SketchUp 2017+: `UI::HtmlDialog` (auto-detected)
- Ruby 2.0+, no external dependencies

## Known limitations

- Right-hand thread only
- No bolt head (DIN 933) — hex nut (DIN 934) only
- FDM plastic profile: to be validated per material and printer

## File structure

```
vis_filets_generator.rb        # Loader + extension registration
vis_filets_generator/
  main.rb                      # Menu entry point
  presets.rb                   # ISO M3–M20 tables + FDM recommended pitches
  profiles.rb                  # IsoProfile (60°), PlasticProfile (angle-limited V)
  geometry.rb                  # PolygonMesh generation (rod + nut)
  dialog.rb                    # UI (WebDialog / HtmlDialog)
build/
  vis_filets_generator.rbz     # Installable extension
```

---

---

# vis_filets_generator — Plugin SketchUp

> **Enfin — un plugin de filets qui fonctionne vraiment.**
> Solides watertight, géométrie ISO correcte, profils adaptés à l'impression FDM, et chanfrein d'entrée. Sans dessin manuel, sans maillage cassé, sans contournement.

Générateur paramétrique de **tiges filetées** et **écrous hexagonaux** pour SketchUp, optimisé pour l'impression 3D FDM. Compatible SketchUp 2014 jusqu'à la version la plus récente.

## Pourquoi ce plugin ?

Les plugins de filets existants exigent de dessiner le profil manuellement ou ne génèrent pas de solides exploitables. Ce plugin produit des **solides watertight** prêts pour le slicer, dans n'importe quelle unité SketchUp.

## Installation

1. Télécharger `build/vis_filets_generator.rbz`
2. Dans SketchUp : **Fenêtre → Gestionnaire d'extensions → Installer l'extension**
3. Sélectionner le fichier `.rbz`
4. Redémarrer SketchUp

## Utilisation

Menu **Extensions → Vis & Filets → Generate…**

| # | Paramètre | Description |
|---|-----------|-------------|
| 1 | **Type de filet** | ISO métrique (60°) ou Plastique FDM optimisé (profil V, angle limité) |
| 2 | **D** | Diamètre nominal — dropdown M3–M20 (ISO) ou saisie libre |
| 3 | **Pas P** | Auto-rempli depuis la table ISO, toujours éditable |
| 4 | **Pièces** | ☑ Tige filetée  ☑ Écrou hexagonal (combinables) |
| 5 | **Hauteur tige** | Longueur de la tige filetée |
| 6 | **Hauteur écrou** | Hauteur de l'écrou hexagonal |
| 7 | **Gap** | Jeu radial ajouté à l'alésage de l'écrou (défaut 0,3 mm ISO / 0,4 mm plastique) |
| 8 | **Chanfrein** | Chanfrein d'entrée sur la tige (haut) et l'écrou (deux côtés) — boolean subtract |
| 9 | **Hauteur chanfrein** | Hauteur axiale du chanfrein (défaut = 1 pas), visible si chanfrein coché |
| 10 | **Segments/tour** | Résolution angulaire, multiple de 6 (défaut 24) |
| 11 | **Angle overhang max** | Plastique FDM uniquement — angle flanc depuis la verticale (défaut 60°) |
| 12 | **Min. core %D** | Plastique FDM uniquement — diamètre noyau minimum en % de D (défaut 70%) |

> **Unité** : toutes les valeurs sont saisies dans l'unité courante du modèle SketchUp. Si le modèle est en mètres, taper `10` génère un filet de 10 mètres de diamètre.

## Profils de filet

### ISO métrique
Profil en V 60° conforme ISO 261 / ISO 724. Vertices placés exactement aux crêtes et fonds.

### Plastique FDM optimisé
L'angle des flancs est **toujours constant** = `max_overhang_angle`, quel que soit le pas. Si la profondeur théorique dépasse la contrainte `min_core`, un **fond plat** est utilisé (profil trapézoïdal) — l'angle ne change jamais.
`profondeur = (P/2) × tan(angle_depuis_verticale)`

Chaque mode (ISO / Plastique) mémorise ses propres paramètres — restaurés au changement de mode.

## Limitations connues

- Filet à droite uniquement
- Pas de tête de vis (DIN 933) — écrou DIN 934 uniquement
- Chanfrein : nécessite SketchUp Pro ou le plugin **Eneroth Solid Tools**
- Profil plastique : à valider selon le matériau et l'imprimante

## Fichiers de référence (prototype initial)

- `vis_M10x1.5_L50_brut.rb` — script Ruby standalone M10×1,5 L=50mm
- `vis_M10x1.5_L50_brut.stl` — STL de référence validé (38 448 triangles, watertight)
