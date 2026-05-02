# Journal de bord — Tige filetée M10×1,5 L=50 mm

Session du 2026-04-30. Utilisateur : Daniel.

## Demande initiale

> Crée une vis métrique 10, pas normal, de 5 cm de long en SketchUp version 2021. 24 segments par tour, brut.

Reformulation après échange : tige filetée seule (sans tête), pas normal P = 1,5 mm, 24 segments par tour, brut (extrémités plates, sans chanfrein).

## Itérations

### Itération 1 — Choix du format

Format `.skp` natif non réalisable depuis l'environnement (format propriétaire fermé, pas de bibliothèque Python officielle). Trois options proposées :

- A. Script Ruby pour SketchUp 2021 (recommandé)
- B. Fichier STL importable
- C. Fichier DAE (Collada)

Décision utilisateur : **STL** d'abord, puis Ruby en complément.

### Itération 2 — Génération STL

Script Python (`gen_vis_m10.py`) avec :

- Profil ISO 261/724 paramétré (H = P·√3/2, crête P/8, fond P/4, flancs 30°)
- Grille (θ × z) de 24 × 801 sommets
- Maillage : 38 400 triangles latéraux + 48 triangles couvercles = **38 448 triangles**
- Écriture STL binaire avec normales calculées par produit vectoriel

**Vérification** : maillage watertight (57 672 arêtes uniques, toutes partagées par exactement 2 triangles), boîte englobante Ø 10,0000 × L 50,0000 mm. Conforme.

→ Livré : `vis_M10x1.5_L50_brut.stl`

### Itération 3 — Génération Ruby SketchUp 2021

Script Ruby `vis_M10_sketchup2021.rb` avec même fonction `radius_at(θ, z)` que le générateur Python. Méthode : `Geom::PolygonMesh` + `entities.fill_from_mesh` pour performance.

→ Livré : version 1 (4 800 octets, 130 lignes).

### Itération 4 — Bug visuel rapporté

> La version Ruby est ratée, le creux entre les filets ressort comme si c'était un deuxième filet.

**Diagnostic** : tolérance interne SketchUp ≈ 0,0254 mm (0,001″). Les arêtes axiales du script (`dz = P/24 = 0,0625 mm ≈ 0,00246″`) sont juste au-dessus de cette limite, dans la zone où SketchUp peut fusionner ou recomposer les facettes. Source : doc Trimble + communauté SketchUp Sage.

**Solution proposée et appliquée** : *scale-trick* standard SketchUp.

- Construction de toute la géométrie à `SCALE = 100×` la taille réelle (arêtes axiales ~6 mm, largement au-dessus de la tolérance).
- Application en fin de procédure de `Geom::Transformation.scaling(ORIGIN, 1/100)` au groupe pour revenir à 1:1.

Modifications chirurgicales :

1. Ajout constante `SCALE = 100.0`
2. `Geom::Point3d.new((x*SCALE).mm, (y*SCALE).mm, (z*SCALE).mm)` pour tous les sommets
3. Centre haut couvercle à `(L*SCALE).mm`
4. `group.transform!(Geom::Transformation.scaling(ORIGIN, 1.0/SCALE))` après `fill_from_mesh`

Aucune autre modification (logique métier, profil, segments inchangés).

### Itération 5 — Problèmes périphériques

- Le fichier `.rb` a subi une troncature lors d'une écriture intermédiaire (Write tool a coupé à 4898 octets) → réécriture via bash heredoc, syntaxe revérifiée OK.
- Le fichier a été renommé localement par l'utilisateur en `vis_M10x1.5_L50_brut.rb`.
- Confusion sur l'accessibilité du dossier P:\ : finalement le `Write` tool peut écrire directement sur P:\ même si le sandbox bash ne le voit pas.

## État final

- `vis_M10x1.5_L50_brut.stl` : ✓ validé, watertight, dimensions exactes
- `vis_M10x1.5_L50_brut.rb` (alias `vis_M10_sketchup2021.rb`) : ✓ syntaxe validée, scale-trick appliqué — **à valider visuellement par l'utilisateur** dans SketchUp 2021.

---

## Session du 2026-05-01

### Objectif
Création du plugin SketchUp `vis_filets_generator` — générateur paramétrique de tiges filetées et écrous hexagonaux, ISO ou optimisé FDM, compatible SketchUp 2014+.

### Fichiers créés

| Fichier | Rôle |
|---------|------|
| `vis_filets_generator.rb` | Loader, enregistre l'extension SketchUp |
| `vis_filets_generator/main.rb` | Guard `@loaded`, menu Extensions > Vis & Filets > Générer… |
| `vis_filets_generator/presets.rb` | Tables M3–M20 ISO (DIN 934) + table pas FDM recommandés |
| `vis_filets_generator/profiles.rb` | `IsoProfile` (V 60°) et `PlasticProfile` (trapézoïdal 30°) |
| `vis_filets_generator/geometry.rb` | `generate_tige` + `generate_ecrou` via `Geom::PolygonMesh` |
| `vis_filets_generator/dialog.rb` | UI `WebDialog` (2014+) / `HtmlDialog` (2017+), HTML embarqué |

### Paramètres de l'interface

1. Profil : ISO métrique / Optimisé plastique FDM
2. D (mm) — dropdown M3–M20 (ISO) ou saisie libre, toujours éditable
3. Pas P (mm) — auto-rempli, toujours éditable
4. Hauteur (mm)
5. ☑ Tige filetée  ☑ Écrou hexagonal (checkboxes, les deux cochables simultanément)
6. Gap (mm) — toujours visible, défaut 0,3 ISO / 0,4 plastique
7. Chanfrein (case à cocher)
8. Segments/tour — contraint multiple de 6, défaut 24

### Décisions techniques

- **Scale-trick adaptatif** : `compute_scale(pitch, n_theta, uf)` → SCALE=100 si l'espacement min de l'hélice < 0,1" (mm/cm), SCALE=1 sinon (mètres). Construction à SCALE× puis `group.transform!(1/SCALE)`.
- **Unité du modèle** : `unit_factor` lit `model.options['UnitsOptions']['LengthUnit']` et retourne le facteur de conversion vers les pouces SketchUp. Coordonnées = `valeur * SCALE * uf`.
- **Écrou** : 1 seul `PolygonMesh` complet (filet interne winding inversé + faces annulaires hex + parois hex). Zéro booléen. Solide garanti.
- **Profil plastique** : trapézoïdal 30°, profondeur 0,65×P, arêtes vives, vertices placés aux 6 transitions de phase par pas.
- **Faces dégénérées** : skip `unless dup_i / dup_i2` sur les faces latérales pour éliminer les faces à hauteur nulle issues de `pad_columns!`.
- **Chanfrein** : tronc de cône haut uniquement, Lc=pitch, angle 45°. Force tous les points de la zone à `cone_r(z)` (surface lisse, pas de texture hélicoïdale). Face haute = disque plat au rayon `r_major - pitch`.
- **Compatibilité** : `WebDialog` si SU < 2017, `HtmlDialog` si SU 2017+, détection à l'exécution.

### Bugs corrigés en cours de session

| Bug | Cause | Correction |
|-----|-------|-----------|
| `can't convert Array into Float` | `[[0.0, zt]].each` au lieu de `[0.0, zt].each` | Correction syntaxe |
| Objets à mauvaise échelle | `.mm` hardcodé, unité modèle non lue | `unit_factor` + `compute_scale` |
| 48 arêtes coplanaires (haut) | `pad_columns!` duplique z=L → faces hauteur 0 | `unless dup_i / dup_i2` |
| 9 arêtes à 3 faces | Lignes centrales ajoutées comme edges mesh dans l'écrou | Suppression des lignes centrales |
| Écrou avec chanfrein = solide sans trou | Cone clip fermait l'alésage à r=0 | `apply_bore_chamfer` séparé avec `max` |
| Écrou diamètre trop grand | `r_bore_min = (D+gap)/2` au lieu de `r_minor_tige + gap` | `r_bore_min = ext_prof.r_minor + gap` |
| Gap appliqué au diamètre au lieu du rayon | Division par 2 inutile | Suppression de `gap / 2.0` |
| Chanfrein tige : creux remontaient au niveau du cône | `force cone_r` modifiait les creux | `min(r, cone_r)` → cône soustrait uniquement |
| Chanfrein tige : cylindre au bout (cône invisible) | `lc = r_major - r_minor` trop court | `lc = pitch` (1 pas, angle 45°) |

### État final validé ✅ (session 2026-05-01)

- ✅ Tige ISO sans chanfrein — géométrie parfaite, imprimée et validée
- ✅ Tige ISO avec chanfrein — imprimée, engranée et validée
- ✅ Écrou ISO sans chanfrein — diamètres corrects, jeu radial = gap
- ✅ Tige + écrou générés simultanément
- ✅ Toutes unités (mm, cm, m)
- ⚠ Profil plastique FDM — à valider à l'impression

---

## Session du 2026-05-02 — Stabilisation v1.5.0

### Corrections majeures

**Écrou cassé (régression) — cause identifiée et résolue**
- Symptôme : le filet de l'écrou ne parcourait pas toute la hauteur du trou, ou se refermait aux extrémités.
- Cause racine : le "flat-face fix" (commit `fdc9b07`) écrasait les features hélicoïdales à z=0 et z=L de l'alésage avec `r_bore_min`. Cela supprimait les crêtes naturelles du filet en début/fin de hauteur.
- Solution : restauration de `geometry.rb` et `profiles.rb` depuis le commit `592d925` (base propre) via `git checkout`. Seuls les ajouts approuvés ont été réappliqués (hauteurs séparées, min_core_ratio). Le flat-face fix a été entièrement supprimé.
- La légère non-planarité des faces annulaires (conséquence) est acceptable, conformément à la décision du 2026-05-01.

**Chanfrein — approche abandonnée, nouvelle stratégie définie**
- Les tentatives de chanfrein par calcul direct dans `build_columns` ont causé des régressions en cascade (tige OK mais écrou cassé à chaque fois).
- Nouvelle approche décidée pour la session suivante : **boolean subtract avec les outils Eneroth**.
  - Tige : soustraire un "ring frustum" (cylindre avec cône creusé) positionné au sommet de la tige
  - Écrou : soustraire un cône simple des deux faces de l'alésage
  - Hauteur du chanfrein : 1 pas (valeur par défaut), configurable via paramètre dans le dialog

### État v1.5.0 ✅

- ✅ Tige ISO sans chanfrein — parfaite (imprimée et engranée)
- ✅ Écrou ISO sans chanfrein — parfait (filet régulier de z=0 à z=L)
- ✅ Profil plastique FDM (angle d'overhang + min core)
- ✅ Hauteurs séparées tige/écrou, persistence des paramètres
- ✅ Dialog en anglais, paramètres grisés si non applicables
- ⏳ Chanfrein — à implémenter en session suivante (boolean Eneroth)

---

## Session du 2026-05-01 (suite — v1.2.0)

### Nouvelles fonctionnalités

**Persistence des paramètres** (`dialog.rb`)
- `Sketchup.write_default` / `read_default` — tous les paramètres sont sauvegardés dans le registre SketchUp à chaque génération et restaurés à l'ouverture du dialog.
- Fonction JS `initForm(SAVED)` : restaure les valeurs sans déclencher les handlers de cascade.

**Profil plastique FDM refait** (`profiles.rb`)
- Ancien : trapézoïdal 30° avec sections plates → angle du flanc ≈ 21° depuis l'horizontale (bavures à l'impression).
- Nouveau : profil en V (même forme qu'ISO) avec profondeur dérivée de l'angle d'overhang max.
- Formule : `depth = (P/2) × tan(angle_vertical)`
- Le profil plastique devient distinct de l'ISO par sa profondeur (adaptée à l'imprimante), non par sa forme.

**Paramètre "Angle / verticale (°)"** (`dialog.rb`)
- Visible uniquement pour le profil plastique FDM.
- Défaut : 60° (depuis la verticale = 30° depuis l'horizontale — imprimante standard).
- Permet d'adapter le profil au refroidissement de l'imprimante (valeur élevée = imprimante performante = filet plus profond).
- Sauvegardé avec les autres paramètres.

### Corrections

| Bug | Cause | Correction |
|-----|-------|-----------|
| Profil plastique sans overhang correct | Sections plates → angle flanc 21° | Profil en V, angle paramétrable |
| Paramètre angle sans effet | Cap 0,65P trop bas (atteint dès 52°) | Suppression du cap, seul garde-fou physique r_minor ≥ 0.1×r_major |

### État v1.2.0 ✅

- ✅ Paramètres persistants entre sessions
- ✅ Profil plastique paramétrable par angle d'overhang (validé visuellement)
- ✅ Angle 30° vs 70° depuis la verticale → profondeurs clairement différentes

---

## Session du 2026-05-01 (suite — v1.3.0)

### Correction : faces top/bottom de l'écrou

**Problème** : les faces annulaires (top et bottom) de l'écrou comportaient des lignes parasites et n'étaient pas planes. Cause : `b_idx[0]` et `b_idx[nz-1]` avaient des rayons variables (profil hélicoïdal oscillant entre r_bore_min et r_bore_max), rendant les triangles de la face annulaire non coplanaires.

**Approche rejetée** : ajout d'anneaux de transition séparés → désastreux (anneau parasite, lignes dans tous les sens).

**Correction retenue** (`build_columns`, bore=true) : forcer r=r_bore_min aux caps z=0 et z=L pour le bore. Si une feature existe déjà à z=0 avec un rayon du profil (ex. r_bore_max), ce rayon est écrasé par r_bore_min. Résultat : toutes les colonnes ont r=r_bore_min aux extrémités → faces annulaires planes.

**État** : acceptable pour opérations booléennes sur solides. Quelques lignes résiduelles visibles mais n'affectent pas la solidité.
- ⚠ Chanfrein écrou — à valider à l'impression
- Plugin livré dans `P:\develop\2026\claude\sketchup-filets\`
- Copié dans `%APPDATA%\SketchUp\SketchUp 2021\SketchUp\Plugins\`

## Sources et références utilisées

- ISO 261:1998 — *ISO general purpose metric screw threads — General plan*
- ISO 724:1993 — *ISO general-purpose metric screw threads — Basic dimensions*
- Trimble SketchUp Ruby API : classe `Geom::PolygonMesh`, méthode `Sketchup::Entities#fill_from_mesh`
- Documentation SketchUp Sage et forums Trimble : « Working with small geometry » (problématique tolérance 0,001″)
