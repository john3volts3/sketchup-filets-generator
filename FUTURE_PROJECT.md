# Projet futur — Skill et plugin SketchUp pour générateur de filets

**Statut** : à reprendre dans une nouvelle session.
**Date de création de ce document** : 2026-04-30.
**Auteur** : Daniel + Claude (Cowork mode).

Ce document permet de reprendre le travail dans une autre session, sans rien perdre du contexte. Lire en premier la section "Reprise" en bas.

---

## 1. Contexte et origine

Ce projet fait suite à une session de génération d'une tige filetée M10×1,5 L=50 mm pour SketchUp 2021. Voir documents associés :

- `README.md` — doc utilisateur du livrable initial
- `JOURNAL.md` — journal de bord des itérations
- `FSD.md` — spécifications fonctionnelles du livrable initial
- `vis_M10x1.5_L50_brut.stl` — STL livré
- `vis_M10x1.5_L50_brut.rb` (alias `vis_M10_sketchup2021.rb`) — script Ruby SketchUp 2021 livré

Pendant cette session, une astuce de modélisation cruciale a été identifiée : le **scale-trick** (construire à 100× la taille réelle puis appliquer une transformation de mise à l'échelle 1/100). Sans cela, SketchUp recompose les facettes à cause de sa tolérance interne ~0,0254 mm. Cette astuce doit être centrale dans le futur plugin.

## 2. Périmètre du projet futur

### 2.1 Skill `sketchup-filets-mecaniques`

À placer dans le dossier des user skills (typiquement `~/.claude/skills/sketchup-filets-mecaniques/SKILL.md`).

Contenu cible :

- Règle d'or scale-trick (construction à 100×, transformation finale 1/100), avec exemple de code
- Méthode `Geom::PolygonMesh` + `entities.fill_from_mesh(mesh, weld=true, smooth_flags=12)` pour performance
- Conversion mm → pouces SketchUp via `.mm`
- Profil ISO 261/724 pour métrique standard (formules H = P·√3/2, fond = D/2 − 5H/8, crête P/8, fond P/4)
- Profils alternatifs pour FDM (voir §3)
- Snippet de référence : la fonction `radius_at(θ, z)` validée
- Encapsulation dans `Sketchup::Group` + `start_operation` / `commit_operation` (annulable d'un Ctrl+Z)

### 2.2 Plugin SketchUp `vis_filets_generator`

Plugin packagé en `.rbz` (zip standard SketchUp) installable via Fenêtre → Préférences → Extensions → Installer extension.

Structure standard :

```
vis_filets_generator/
├── vis_filets_generator.rb        # loader (déclare l'extension)
└── vis_filets_generator/
    ├── main.rb                    # point d'entrée, menu
    ├── ui_dialog.rb               # HtmlDialog (HTML/JS embed)
    ├── geometry.rb                # générateur de filets (scale-trick)
    ├── profiles.rb                # profils (ISO, trapèze, sawtooth)
    ├── presets.rb                 # tables M3..M20 ISO + presets FDM
    └── shapes.rb                  # tige, boulon hex, écrou hex
```

#### Menu et UI

Menu : **Extensions → Vis & Filets → Générer...**

`UI::HtmlDialog` (compatible SU 2017+) avec onglets ou sections :

- Type : **Métrique ISO** | **Plastique FDM**
- Forme : **Tige filetée** | **Boulon (vis hex DIN 933)** | **Écrou hex (DIN 934)**

Si Métrique sélectionné :
- Combo M3 / M4 / M5 / M6 / M8 / M10 / M12 / M16 / M20 avec pas normal pré-rempli
- Possibilité override manuel du pas (pour pas fin / extra-fin)
- Longueur (mm)
- Segments par tour (défaut 16, recommandé pour FDM)

Si Plastique FDM sélectionné :
- Diamètre nominal (mm) — libre
- Pas (mm) — pré-rempli avec valeur recommandée selon Ø (table en §3.2), modifiable
- Jeu radial (mm) — défaut 0,3 mm pour clearance impression
- Profil : Triangulaire 60° | **Trapézoïdal 30° (recommandé)** | Sawtooth asymétrique
- Profondeur de filet (% du pas) — défaut 40 % (au lieu de 54 % ISO) pour tolérance FDM
- Longueur (mm)
- Segments par tour (défaut 16)

Bouton **Générer** → exécute la génération dans le modèle SketchUp actif.

#### Géométrie

Toute la génération passe par `geometry.rb`, qui implémente :

- Application systématique du scale-trick `SCALE = 100`
- Fonction de profil paramétrable (différentes formes)
- Génération du cylindre fileté (tige) ou du trou fileté (écrou) avec `radius_at(θ, z)`
- Génération de la tête hexagonale (boulon) ou du corps hexagonal (écrou) par extrusion d'un hexagone régulier
- Booléennes minimales (juste un placement / fusion par groupe)
- Polycount cible : **9 600 à 16 000 triangles** par pièce maximum (vs 38 448 actuellement)
  - 16 segments/tour × 12 niveaux/pas par défaut, vs 24 × 24 actuellement
  - Soit dz = P/12 ≈ 0,125 mm en pas 1,5 mm — au-dessus de la tolérance même sans scale-trick (mais on le garde par sécurité)

## 3. Spécifications techniques pour les filets imprimés 3D

### 3.1 Sources et état de l'art

- ISO 2901..2904 — Filetage trapézoïdal Tr (référence pour le profil 30°)
- Recherche FDM : K. Hodonsky et al. (2019), études sur la résistance mécanique des assemblages filetés imprimés en PLA et PETG
- Communauté maker : recommandations Prusa, Bambu Lab et Hubs sur l'impression de filets
- *Functional 3D-Printed Threaded Fasteners* (J. Vesterling et al., publications OnShape/Markforged disponibles publiquement)

### 3.2 Table de pas recommandés FDM (buse 0,4 mm, hauteur de couche 0,2 mm)

| Diamètre nominal | Pas mini praticable | Pas recommandé | Profondeur de filet |
|---|---|---|---|
| 6 mm | 1,0 mm | **1,5 mm** | 0,4 × P = 0,60 mm |
| 8 mm | 1,5 mm | **2,0 mm** | 0,4 × P = 0,80 mm |
| 10 mm | 1,5 mm | **2,0 mm** | 0,4 × P = 0,80 mm |
| 12 mm | 2,0 mm | **2,5 mm** | 0,4 × P = 1,00 mm |
| 16 mm | 2,5 mm | **3,0 mm** | 0,4 × P = 1,20 mm |
| 20 mm | 3,0 mm | **3,5 mm** | 0,4 × P = 1,40 mm |
| 25 mm | 3,5 mm | **4,0 mm** | 0,4 × P = 1,60 mm |

Justification :
- Pas trop fin → couches imprimées plus épaisses que les flancs → filet écrasé
- Pas trop grossier → moins de tours d'engagement, moindre résistance au cisaillement

### 3.3 Profils alternatifs pour FDM

**Trapézoïdal symétrique 30°** (recommandé par défaut, conforme ISO 2901) :
- Angle d'inclusion 30° (au lieu de 60° ISO métrique)
- Flancs moins inclinés → moins d'overhang → meilleure surface de contact
- Profil plus tolérant aux écarts dimensionnels FDM

**Sawtooth asymétrique** (option) :
- Un flanc à 0° (perpendiculaire à l'axe), un flanc à 30°
- Adapté aux assemblages unidirectionnels (résistance en arrachement)
- Moins courant en FDM, mais imprime bien

**Triangulaire 60°** (compatibilité ISO uniquement) :
- À utiliser si compatibilité avec une vis métallique standard requise
- Sinon préférer trapézoïdal 30°

### 3.4 Tolérances et jeux

- **Jeu radial vis-écrou** : 0,3 mm de chaque côté (gap diamétral total 0,6 mm) sur le diamètre nominal
- **Variante** : jeu 0,2 mm pour assemblages serrés, 0,4 mm pour assemblages faciles à monter à la main
- **Approche** : la tige est générée à dimensions nominales ; l'écrou voit son diamètre intérieur agrandi du jeu (et son diamètre de fond diminué d'autant)

## 4. Décisions déjà prises (à ne pas re-débattre)

1. **Scale-trick obligatoire** dans toute la génération (`SCALE = 100`)
2. **Méthode `fill_from_mesh`** plutôt que `add_face` un par un (perf)
3. **Polycount par défaut réduit** : 16 segments/tour × 12 niveaux/pas
4. **Plugin packagé en .rbz**, installable proprement dans SU 2021+
5. **UI via `UI::HtmlDialog`** (HTML/JS), pas via WebDialog déprécié
6. **Métrique et FDM** dans le même plugin, pas de séparation
7. **Tige + Boulon hex (DIN 933) + Écrou hex (DIN 934)** comme formes de base
8. **Profil ISO 60°** par défaut pour Métrique, **trapézoïdal 30°** par défaut pour FDM

## 5. Questions ouvertes (à clarifier au démarrage de la prochaine session)

1. **Forme de la tête de boulon** : DIN 933 hex confirmé ? Ou aussi proposer Allen / Torx / fente cruciforme ?
2. **Hauteur de tête** : standard DIN 933 (0,7 × D) ou paramétrable ?
3. **Hauteur de l'écrou** : standard DIN 934 (0,8 × D) ou paramétrable ?
4. **Pas par défaut FDM** : table §3.2 confirmée ?
5. **Variantes de profil** : juste trapézoïdal 30° pour FDM, ou aussi sawtooth ?
6. **Sortie** : groupe SketchUp (par défaut) ou aussi composant (`ComponentDefinition`) pour réutilisation ?
7. **Filet à droite uniquement** ou aussi filet à gauche en option ?
8. **Internationalisation UI** : français uniquement, ou bilingue FR/EN ?

## 6. Plan de livraison proposé

**Étape 1** — Skill `sketchup-filets-mecaniques` (~30 min)
- SKILL.md complet avec les bonnes pratiques + snippet `radius_at`
- Validation : pouvoir réutiliser le snippet pour reproduire la vis M10 sans re-débugger

**Étape 2** — Plugin v0.1 : tige filetée seule (~1 h)
- Loader + extension SketchUp + menu
- UI HtmlDialog minimale (Métrique ISO seulement, tige seulement)
- Géométrie via `radius_at` + scale-trick
- Polycount réduit (16 × 12)

**Étape 3** — Plugin v0.2 : ajout FDM (~30 min)
- Bascule Métrique / FDM dans l'UI
- Table de pas FDM intégrée
- Profil trapézoïdal 30°
- Jeu radial paramétrable

**Étape 4** — Plugin v0.3 : ajout boulon + écrou (~1 h)
- Tête hex DIN 933 (boulon)
- Corps hex DIN 934 (écrou)
- Booléenne d'unification du filetage et de la tête/du corps

**Étape 5** — Packaging .rbz + tests (~30 min)
- Compression du dossier en .rbz
- Test d'installation propre dans SU 2021
- Test de génération de chaque type
- Documentation utilisateur

**Total estimé** : ~3 h 30 de travail.

## 7. État final actuel — ce qui est déjà fait

- [x] Génération STL paramétrique fonctionnelle (vis M10×1,5 L=50 brut)
- [x] Script Ruby SketchUp 2021 fonctionnel avec scale-trick
- [x] Validation maillage watertight
- [x] Validation syntaxe Ruby
- [x] Identification du bug de tolérance et solution scale-trick
- [x] Documentation README + JOURNAL + FSD du livrable initial
- [x] Spécifications du futur plugin (ce document)
- [ ] Validation visuelle finale du rendu Ruby dans SketchUp 2021 — *à confirmer par l'utilisateur*

## 8. Reprise — pour la prochaine session

Pour reprendre le travail, dans une nouvelle conversation Claude / Cowork :

1. **Pointer Claude vers ce dossier** : `P:\develop\print3d\2026-3D\claude-tige-filetee`
2. **Faire lire à Claude en priorité** :
   - Ce fichier (`FUTURE_PROJECT.md`) — vue d'ensemble et décisions
   - `vis_M10_sketchup2021.rb` — code de référence à réutiliser
   - `FSD.md` — pour la rigueur des specs
3. **Répondre aux questions ouvertes §5**
4. **Choisir l'étape de démarrage** parmi le plan §6 (recommandé : étape 1 = skill, puis étape 2 = plugin v0.1)

Démarrage type pour la nouvelle session :

> *« Reprends le projet plugin SketchUp filets décrit dans `FUTURE_PROJECT.md`. Lis d'abord ce fichier, puis on commence par l'étape 1 : créer le skill `sketchup-filets-mecaniques`. »*
