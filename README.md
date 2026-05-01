# vis_filets_generator — Plugin SketchUp

Générateur paramétrique de **tiges filetées** et **écrous hexagonaux** pour SketchUp, optimisé pour l'impression 3D FDM. Compatible SketchUp 2014 à la version la plus récente.

## Pourquoi ce plugin ?

Les plugins de filets existants pour SketchUp exigent de dessiner le profil manuellement ou ne génèrent pas de solides exploitables. Ce plugin produit directement des **solides watertight** prêts pour le slicer, dans n'importe quelle unité SketchUp (mm, cm, m…).

## Installation

1. Télécharger `build/vis_filets_generator.rbz`
2. Dans SketchUp : **Fenêtre → Gestionnaire d'extensions → Installer l'extension**
3. Sélectionner le fichier `.rbz`
4. Redémarrer SketchUp

## Utilisation

Menu **Extensions → Vis & Filets → Générer…**

Une boîte de dialogue s'ouvre avec les paramètres suivants :

| # | Paramètre | Description |
|---|-----------|-------------|
| 1 | **Profil** | ISO métrique (60°) ou Optimisé plastique FDM (trapézoïdal 30°) |
| 2 | **D** | Diamètre nominal — dropdown M3–M20 (ISO) ou saisie libre |
| 3 | **Pas P** | Auto-rempli depuis la table ISO, toujours éditable |
| 4 | **Hauteur** | Longueur de la pièce, dans l'unité courante du modèle |
| 5 | **Pièces** | ☑ Tige filetée  ☑ Écrou hexagonal (les deux cochables simultanément) |
| 6 | **Gap** | Jeu radial ajouté à l'alésage de l'écrou (défaut 0,3 mm ISO / 0,4 mm plastique) |
| 7 | **Chanfrein** | Chanfrein d'entrée 45° sur la tige (haut) et l'écrou (deux côtés) |
| 8 | **Segments/tour** | Résolution angulaire, multiple de 6 (défaut 24) |

Cliquer **Générer** : les objets apparaissent à l'origine du modèle dans des groupes nommés `Tige M10x1.5 L50 ISO` et `Ecrou M10x1.5 L50 ISO`.

> **Unité** : toutes les valeurs sont saisies dans l'unité affichée par SketchUp. Si le modèle est en mètres, taper `10` génère un objet de 10 mètres de diamètre.

## Profils de filet

### ISO métrique
Profil en V 60° conforme ISO 261 / ISO 724. Vertices placés exactement aux crêtes et fonds de filet — arêtes vives, aucun arrondi de maillage.

### Optimisé plastique FDM
Profil trapézoïdal 30° avec profondeur réduite à 0,65 × P. Recommandé pour l'impression 3D :
- Pas recommandé auto-calculé (≈ 0,25 × D)
- Flancs moins inclinés → moins d'overhang → meilleure qualité d'impression
- Profondeur réduite → tolérance accrue aux écarts dimensionnels FDM

## Écrou hexagonal

L'écrou est généré en un seul `PolygonMesh` sans booléen :
- Forme extérieure hexagonale DIN 934 (table M3–M20 intégrée)
- Alésage fileté : `r_bore = r_tige ± gap` (jeu appliqué au rayon)
- Solide watertight garanti

## Chanfrein d'entrée

Le chanfrein est un tronc de cône (45°, longueur = 1 pas) :
- **Tige** : haut uniquement. `min(r, cone_r)` — le cône soustrait les crêtes progressivement, les creux restent intacts jusqu'à être atteints par le cône.
- **Écrou** : deux côtés. `max(r, r_chamfer)` — miroir exact du chanfrein tige, l'alésage s'évase vers les faces.

## Notes techniques

### Scale-trick adaptatif
SketchUp a une tolérance interne ≈ 0,001 pouce. Pour les filets en mm/cm, les arêtes hélicoïdales (≈ P/N) peuvent approcher cette limite. Le plugin construit la géométrie à **100×** puis applique `group.transform!(1/100)`. En mètres, la géométrie est déjà grande (SCALE = 1).

### Compatibilité
- SketchUp 2014–2016 : `UI::WebDialog`
- SketchUp 2017+ : `UI::HtmlDialog` (détection automatique)
- Ruby 2.0+ (aucune dépendance externe)

## Limitations connues

- Filet à droite uniquement
- Pas de tête de vis (DIN 933) — écrou DIN 934 uniquement
- Profil plastique FDM à valider selon le matériau et la machine

## Structure du projet

```
vis_filets_generator.rb        # Loader + enregistrement extension
vis_filets_generator/
  main.rb                      # Menu + point d'entrée
  presets.rb                   # Tables M3–M20 ISO + pitches FDM recommandés
  profiles.rb                  # IsoProfile (60°), PlasticProfile (30°)
  geometry.rb                  # Génération PolygonMesh (tige + écrou)
  dialog.rb                    # Interface utilisateur (WebDialog / HtmlDialog)
build/
  vis_filets_generator.rbz     # Extension installable
```

## Fichiers de référence (prototype initial)

- `vis_M10x1.5_L50_brut.rb` — script Ruby standalone M10×1,5 L=50mm (origine du projet)
- `vis_M10x1.5_L50_brut.stl` — STL de référence validé (38 448 triangles, watertight)
