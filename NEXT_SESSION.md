# Reprise de session — vis_filets_generator

**Date** : 2026-05-02  
**Contexte** : Session interrompue à 50% de contexte. Ce fichier permet de reprendre sans perte d'information.

---

## État actuel du plugin (v1.5.0)

### Ce qui fonctionne parfaitement ✅

- **Tige filetée ISO** : géométrie parfaite, imprimée et engranée (confirmé par impression physique)
- **Écrou ISO** : filet régulier de z=0 à z=L, diamètres corrects (gap appliqué au rayon)
- **Profil plastique FDM** : profil V, angle d'overhang depuis la verticale (60° défaut), min core %
- **Tige + écrou simultanément**, hauteurs séparées indépendantes
- **Persistence des paramètres** entre sessions SketchUp
- **Dialog complet** : radio buttons profil, grisage contextuel, bilingue, virgule/point décimal

### Ce qui reste à faire ⏳

**Chanfrein** — à implémenter avec boolean subtract (Eneroth)

---

## Architecture actuelle du code

```
vis_filets_generator.rb           # Loader
vis_filets_generator/
  main.rb                         # Menu, guard @loaded
  presets.rb                      # Tables ISO M3-M20, FDM pitches
  profiles.rb                     # IsoProfile, PlasticProfile
  geometry.rb                     # generate_tige, generate_ecrou
  dialog.rb                       # UI WebDialog/HtmlDialog
```

### Commits git importants
- `592d925` — base propre (tige+écrou fonctionnels, chamfer lc=pitch)
- `81d2601` — hauteurs séparées, dialog EN, v1.4.0
- `ca4806d` — fix bore diameter, chamfer tige validée physiquement

### Fichiers actuellement déployés
`%APPDATA%\SketchUp\SketchUp 2021\SketchUp\Plugins\vis_filets_generator\`

---

## Prochaine fonctionnalité : Chanfrein par boolean subtract

### Stratégie approuvée

**Ne plus calculer le chanfrein dans `build_columns`** (trop fragile, cassait l'écrou à chaque tentative).  
**Générer la pièce sans chanfrein puis appliquer un boolean subtract Eneroth.**

La case "Thread lead-in chamfer" dans le dialog existe déjà (paramètre `chamfer`).  
Actuellement elle est ignorée en geometry.rb. Il faut l'activer avec la nouvelle approche.

### Outil chanfrein pour la tige ("ring frustum")

```
Vue de côté (coupe axiale) :

       r_minor  r_major+ε
z=L      |--------|      ← face annulaire plate (top)
         \        |
   45°    \       |      ← surface conique intérieure
            \     |      ← surface cylindrique extérieure  
z=L-lc  --------|      ← fond (anneau mince, r_major à r_major+ε)
```

- **Cylindre extérieur** : rayon = r_major + small_clearance
- **Creux conique intérieur** : apex VIRTUEL au-dessus (z = L + r_minor), 45°
  - À z=L : rayon interne = r_minor (ce qui reste du bout de la tige)
  - À z=L-lc : rayon interne = r_major (le cône rejoint le cylindre = fond)
- `lc` = hauteur du chanfrein = **1 pas** par défaut (paramètre utilisateur)
- L'outil est positionné coaxialement à la tige, face top à z=L

**Résultat après subtract** : la tige a un chanfrein conique en haut, face plate au rayon r_minor.

### Outil chanfrein pour l'écrou (cône simple × 2)

```
Vue de coupe bore :

z=0     ◄── apex cône (centre face)
          \
     45°   \                  ← surface conique
             \
z=lc          ──── r_bore_minor  ← base cône
```

- **Cône solide** (pas de cylindre extérieur)
- Apex au centre de la face (z=0 et z=L)
- S'ouvre vers l'intérieur de l'écrou à 45°
- Base radius = lc (= 1 pas) × tan(45°) = lc (rayon de la base du cône)
- Soustrait à z=0 ET z=L → deux cônes

### Code à écrire dans geometry.rb

```ruby
# Après create_rod_group, si chamfer=true :
def self.apply_chamfer_rod(model, rod_group, params, length, r_major, r_minor, sc, uf)
  lc = params.fetch('chamfer_height', params['pitch'].to_f)  # 1 pas par défaut
  # 1. Créer ring frustum (PolygonMesh)
  # 2. group.entities.fill_from_mesh(...)
  # 3. group.transform!(1/sc)
  # 4. Eneroth subtract: rod_group.subtract!(tool_group)
end

def self.apply_chamfer_nut(model, nut_group, params, length, r_bore_min, sc, uf)
  lc = params.fetch('chamfer_height', params['pitch'].to_f)
  # 1. Créer cône simple (PolygonMesh) × 2
  # 2. fill_from_mesh + transform
  # 3. Eneroth subtract: nut_group.subtract!(cone_top) + .subtract!(cone_bot)
end
```

### Paramètre dialog à ajouter

Nom : "Chamfer height (mm)" — défaut : P (pitch), visible si chamfer coché.  
Clé params : `'chamfer_height'`

### Code Eneroth pour subtract solide

Utiliser la méthode éprouvée du plugin sketchup-solid-batch-Eneroth :
```ruby
require 'Eneroth Solid Tools/eneroth_solid_tools'
# OU : utiliser Sketchup's own solid tools si disponible
result = Eneroth::SolidTools.subtract(target_group, tool_group)
```

Ou l'équivalent natif SketchUp (disponible depuis SU 2015) :
```ruby
target_group.subtract(tool_group)
# Retourne le groupe résultat ou nil si échec
```

**Note** : vérifier la disponibilité selon la version SU.  
`Sketchup::Group#subtract` est disponible depuis SketchUp 2015 (SU API Level 14).  
Pour SU 2014 : utiliser Eneroth.

---

## Commandes utiles pour la reprise

### Reload en console Ruby
```ruby
load 'C:/Users/danie/AppData/Roaming/SketchUp/SketchUp 2021/SketchUp/Plugins/vis_filets_generator/geometry.rb'
load 'C:/Users/danie/AppData/Roaming/SketchUp/SketchUp 2021/SketchUp/Plugins/vis_filets_generator/profiles.rb'
load 'C:/Users/danie/AppData/Roaming/SketchUp/SketchUp 2021/SketchUp/Plugins/vis_filets_generator/dialog.rb'
```

### Déploiement
```powershell
$dst = "C:\Users\danie\AppData\Roaming\SketchUp\SketchUp 2021\SketchUp\Plugins\vis_filets_generator"
$src = "P:\develop\2026\claude\sketchup-filets\vis_filets_generator"
Copy-Item "$src\geometry.rb" "$dst\geometry.rb" -Force
Copy-Item "$src\profiles.rb" "$dst\profiles.rb" -Force
Copy-Item "$src\dialog.rb"   "$dst\dialog.rb"   -Force
```

### Git (NAS P:, méthode lock-safe)
```powershell
$repo = "P:\develop\2026\claude\sketchup-filets"
Remove-Item -Force "$repo\.git\index.lock" -ErrorAction SilentlyContinue
git -C $repo add <fichiers>; git -C $repo commit -m "message"; git -C $repo push
```

---

## Décisions techniques importantes à retenir

| Sujet | Décision |
|-------|---------|
| Gap écrou | Appliqué au **rayon** (pas au diamètre) : `r_bore = r_tige ± gap` |
| Flat-face fix bore | **NE PAS APPLIQUER** — casse le filet de l'écrou |
| Chanfrein | **Boolean subtract uniquement** — pas de calcul dans build_columns |
| Profil plastique | Profil V, depth = (P/2)×tan(angle_vertical), borné par min_core |
| Scale-trick | Adaptatif : SCALE=100 si pitch/N×uf < 0.1", SCALE=1 sinon |
| Hauteur dialog | 660px (WebDialog + HtmlDialog) |
