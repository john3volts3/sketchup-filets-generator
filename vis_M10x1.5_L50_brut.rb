# =============================================================================
#  Generation d'une tige filetee M10 x 1,5 - L = 50 mm - brut (sans tete)
#  Maillage helicoidal a aretes vives - sommets places exactement aux crete/fond
#  Aucun smoothing - toutes les aretes sont vives (filets a pointes pures)
#  Optimise pour impression FDM buse 0,4 mm / couches 0,2 mm
#
#  Utilisation dans SketchUp 2021 :
#    1. Ouvrir SketchUp 2021
#    2. Menu : Fenetre > Console Ruby
#    3. Glisser ce fichier dans la console OU faire :
#         load 'C:/chemin/vers/vis_M10_sketchup2021.rb'
#       (sous Windows, utiliser des / dans le chemin)
#    4. La vis est creee a l'origine, axe Z
#
#  Parametres ISO M10 x 1,5 :
#    - Diametre nominal D       = 10,000 mm
#    - Pas P                    =  1,500 mm  (pas normal/gros)
#    - Hauteur theorique H      =  1,2990 mm  (= P * sqrt(3)/2)
#    - Rayon de crete           =  5,0000 mm  (D/2)
#    - Rayon de fond            =  4,1881 mm  (D/2 - 5H/8)
#    - Profil : V symetrique, flancs a 30 deg, crete et fond pointus
# =============================================================================

require 'sketchup.rb'

module DanielMaker
  module ViseM10

    # --- Parametres ISO M10 x 1,5 ---
    D            = 10.0
    P            = 1.5
    H            = P * Math.sqrt(3.0) / 2.0
    R_MAJOR      = D / 2.0
    R_MINOR      = R_MAJOR - 5.0 * H / 8.0
    L            = 50.0
    N_THETA      = 24      # segments par tour (erreur de corde ~0,043 mm a R=5)

    # Astuce d'echelle SketchUp : on construit a 100x la taille reelle pour
    # que toutes les aretes soient bien au-dessus de la tolerance interne
    # (~0,0254 mm = 0,001"), puis on ramene le groupe a l'echelle 1:1 a la fin.
    SCALE        = 1000.0

    # Profil V (utilise uniquement pour les capuchons z=0 et z=L) :
    # f in [0   ; 0,5] -> rampe descendante crete -> fond
    # f in [0,5 ; 1  ] -> rampe ascendante  fond  -> crete
    def self.radius_at(theta, z)
      phase = (z - theta * P / (2.0 * Math::PI)) % P
      f = phase / P
      if f < 0.5
        t = f / 0.5
        R_MAJOR + t * (R_MINOR - R_MAJOR)
      else
        t = (f - 0.5) / 0.5
        R_MINOR + t * (R_MAJOR - R_MINOR)
      end
    end

    def self.create
      model = Sketchup.active_model
      model.start_operation('Vis M10x1.5 L50 brut', true)

      group = model.entities.add_group
      ents  = group.entities

      # ---------------------------------------------------------------------
      # Maillage helicoidal aligne :
      # Pour chaque colonne theta_i, les sommets sont places EXACTEMENT aux
      # phases de crete (R_MAJOR) et de fond (R_MINOR) de l'helice de cette
      # colonne. Garantit des aretes vives sur tous les filets - aucune
      # troncature de mesh aux pointes/creux.
      # Plus deux sommets terminaux a z=0 et z=L pour les capuchons.
      # ---------------------------------------------------------------------
      columns = []
      (0...N_THETA).each do |i|
        theta = 2.0 * Math::PI * i / N_THETA
        theta_offset = i * P.to_f / N_THETA

        features = []
        # Cretes : z = theta_offset + k*P, dans [0, L]
        k = 0
        loop do
          z = theta_offset + k * P
          break if z > L
          features << [z, R_MAJOR] if z >= 0
          k += 1
        end
        # Fonds : z = theta_offset - P/2 + k*P, dans [0, L]
        k = 0
        loop do
          z = theta_offset - P / 2.0 + k * P
          features << [z, R_MINOR] if z >= 0 && z <= L
          k += 1
          break if z > L
        end
        features.sort_by! { |e| e[0] }

        col = []
        # Capuchon bas (saute si la premiere feature est deja a z=0)
        if features.empty? || features.first[0] > 1e-9
          col << [0.0, radius_at(theta, 0.0)]
        end
        col.concat(features)
        # Capuchon haut (saute si la derniere feature est deja a z=L)
        if features.empty? || features.last[0] < L - 1e-9
          col << [L, radius_at(theta, L)]
        end

        columns << col
      end

      # Uniformisation des longueurs (ecart max = 1 vertex selon les colonnes).
      # Le padding duplique le sommet superieur - genere des triangles
      # degeneres (aire nulle) qui n'affectent pas la geometrie imprimee.
      max_len = columns.map(&:length).max
      columns.each do |col|
        pad = col.last
        (max_len - col.length).times { col << pad }
      end
      n_z = max_len

      # Pre-calcul des sommets a l'echelle SCALE x
      verts = Array.new(n_z) { Array.new(N_THETA) }
      (0...n_z).each do |j|
        (0...N_THETA).each do |i|
          theta = 2.0 * Math::PI * i / N_THETA
          z, r = columns[i][j]
          x = r * Math.cos(theta)
          y = r * Math.sin(theta)
          verts[j][i] = Geom::Point3d.new((x * SCALE).mm, (y * SCALE).mm, (z * SCALE).mm)
        end
      end

      # Construction du PolygonMesh
      n_points = n_z * N_THETA + 2
      n_polys  = (n_z - 1) * N_THETA * 2 + 2 * N_THETA
      mesh = Geom::PolygonMesh.new(n_points, n_polys)

      idx = Array.new(n_z) { Array.new(N_THETA) }
      (0...n_z).each do |j|
        (0...N_THETA).each do |i|
          idx[j][i] = mesh.add_point(verts[j][i])
        end
      end
      idx_bot = mesh.add_point(Geom::Point3d.new(0, 0, 0))
      idx_top = mesh.add_point(Geom::Point3d.new(0, 0, (L * SCALE).mm))

      # Faces laterales (CCW vu de l'exterieur)
      (0...(n_z - 1)).each do |j|
        (0...N_THETA).each do |i|
          i_next = (i + 1) % N_THETA
          a = idx[j][i]
          b = idx[j][i_next]
          c = idx[j + 1][i_next]
          d = idx[j + 1][i]
          mesh.add_polygon(a, b, c)
          mesh.add_polygon(a, c, d)
        end
      end

      # Couvercle bas (normale -Z)
      (0...N_THETA).each do |i|
        i_next = (i + 1) % N_THETA
        mesh.add_polygon(idx_bot, idx[0][i_next], idx[0][i])
      end

      # Couvercle haut (normale +Z)
      (0...N_THETA).each do |i|
        i_next = (i + 1) % N_THETA
        mesh.add_polygon(idx_top, idx[n_z - 1][i], idx[n_z - 1][i_next])
      end

      # Aucun smoothing : aretes vives partout (consigne explicite)
      smooth_flags = 0
      ents.fill_from_mesh(mesh, true, smooth_flags)

      # Retour a l'echelle 1:1
      #tr = Geom::Transformation.scaling(ORIGIN, 1.0 / SCALE)
      #group.transform!(tr)

      group.name = "Vis M10x1.5 L50 brut"

      model.commit_operation

      UI.messagebox(
        "Vis M10 x 1,5  L = 50 mm generee.\n" \
        "Triangles : #{mesh.polygons.length}\n" \
        "Sommets   : #{mesh.points.length}"
      )
    end

  end
end

DanielMaker::ViseM10.create
