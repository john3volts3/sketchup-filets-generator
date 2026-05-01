# Tige filetée M10 × 1,5 — L = 50 mm — brut

Génération paramétrique d'une tige filetée métrique standard, livrée en deux formats :

- **STL binaire** (`vis_M10x1.5_L50_brut.stl`) — directement utilisable en impression 3D ou import dans n'importe quel slicer / modeleur.
- **Script Ruby SketchUp 2021** (`vis_M10_sketchup2021.rb`, peut être renommé localement) — génère la même géométrie nativement dans une scène SketchUp.

## Spécifications

| Paramètre | Valeur | Source |
|---|---|---|
| Norme | ISO 261 (série métrique) / ISO 724 (cotes de base) | ISO |
| Diamètre nominal D | 10,000 mm | ISO 261 |
| Pas P (normal/gros) | 1,500 mm | ISO 261 |
| Hauteur théorique du triangle H | 1,2990 mm = P · √3/2 | ISO 724 |
| Rayon de crête | 5,0000 mm = D/2 | — |
| Rayon de fond | 4,1881 mm = D/2 − 5H/8 | ISO 724 |
| Profil | triangulaire 60°, crête tronquée à P/8, fond tronqué à P/4, flancs à 30° | ISO 724 |
| Longueur | 50 mm | spec utilisateur |
| Tête | aucune (tige filetée brute, extrémités plates) | spec utilisateur |
| Segments par tour (θ) | 24 | spec utilisateur |
| Niveaux par pas (z) | 24 → dz = 0,0625 mm | choix résolution |

## Fichier STL

- **Triangles** : 38 448
- **Taille** : ~1,9 Mo
- **Watertight** : oui (toutes les arêtes sont partagées par exactement 2 triangles, vérifié)
- **Boîte englobante** : Ø 10 mm × L 50 mm
- **Origine** : base de la tige à z = 0, axe Z

## Script Ruby SketchUp 2021

### Utilisation

1. Ouvrir SketchUp 2021
2. Menu : **Fenêtre → Console Ruby**
3. Exécuter (les slashes forward sont obligatoires pour Ruby sous Windows) :

   ```ruby
   load 'P:/develop/print3d/2026-3D/claude-tige-filetee/vis_M10x1.5_L50_brut.rb'
   ```

4. La vis est créée à l'origine, axe Z, dans un Group nommé `Vis M10x1.5 L50 brut`.

### Astuce d'échelle (point clé)

Le script construit la géométrie à **100 × la taille réelle**, puis applique `Geom::Transformation.scaling(ORIGIN, 1/100)` au groupe pour revenir à 1:1.

Raison : SketchUp a une tolérance interne d'environ **0,001 pouce ≈ 0,0254 mm** en dessous de laquelle les arêtes courtes peuvent être fusionnées ou recomposées de manière imprévisible (référence : doc Trimble et communauté SketchUp Sage). Or `dz = P/24 = 0,0625 mm ≈ 0,00246″` est juste au-dessus de cette limite — assez pour produire un artefact visuel de « double filet » dans le creux.

À 100×, les arêtes axiales font ~6 mm, bien au-delà de toute tolérance. La transformation finale ramène la pièce à la taille exacte sans réintroduire les défauts.

## Vérifications effectuées

- STL ouvert et parsé : 38 448 triangles, watertight parfait, dimensions exactes (Ø 10,000 mm × L 50,000 mm).
- Script Ruby validé syntaxiquement (`ruby -c`).
- Profil ISO recalculé manuellement : H = 1,2990, fond = 4,1881 → conforme tabulation ISO 724.

## Limites connues

- Le profil est une approximation linéaire ISO simplifiée (pas de congé R = H/6 au fond, généralement omis pour FDM).
- Les extrémités sont coupées droites : pas de chanfrein de queue, ni d'amorce d'engagement de filet.
- La tige est « brute » : pas de tête, pas de fente, pas de marquage.
