# vis_filets_generator/geometry.rb
# Generation de tiges filetees et ecrous hexagonaux par PolygonMesh
#
# Scale-trick adaptatif :
#   En mm/cm, l'espacement minimum entre vertices (~P/N) peut approcher la
#   tolerance interne SketchUp (~0,001"). On construit a SCALE x la taille
#   reelle puis on applique group.transform!(1/SCALE) a la fin.
#   En metres, la geometrie est deja grande : SCALE=1 (pas de trick necessaire).
#   compute_scale() choisit automatiquement SCALE=100 ou SCALE=1.
#
# Chanfrein correct :
#   apply_chamfer() utilise r_minor comme reference — la surface exterieure
#   taper de r_minor (diametre noyau) a r_major (diametre crete) sur 1 pas.

module VisFiletsGenerator
  module Geometry

    # =========================================================================
    # Point d'entree
    # =========================================================================
    def self.generate(params, model)
      model.start_operation('Vis & Filets', true)
      begin
        d   = params['d'].to_f
        gap = params['gap'].to_f

        generate_tige(params, model, 0.0) if params['create_tige']

        if params['create_ecrou']
          x_off = params['create_tige'] ? (d * 2.5 + gap) : 0.0
          generate_ecrou(params, model, x_off)
        end

        model.commit_operation
      rescue => e
        model.abort_operation
        UI.messagebox(
          "Erreur de generation :\n#{e.message}\n\n#{e.backtrace.first(3).join("\n")}",
          MB_OK
        )
      end
    end

    # =========================================================================
    # Tige filetee (filet externe, diametre D)
    # =========================================================================
    def self.generate_tige(params, model, x_off = 0.0)
      d      = params['d'].to_f
      pitch  = params['pitch'].to_f
      length = params.fetch('length_tige', params.fetch('length', 50.0)).to_f
      nth    = params['n_theta'].to_i
      chamf  = params['chamfer']

      uf = unit_factor
      sc = compute_scale(pitch, nth, uf)

      max_angle = params.fetch('max_overhang_angle', 45.0).to_f
      profile   = make_profile(params['profile_type'], d / 2.0, pitch, max_angle)
      cols      = build_columns(nth, pitch, length, profile, chamf)
      pad_columns!(cols)
      nz = cols.first.length

      verts  = build_verts(nth, nz, cols, x_off, uf, sc)
      n_pts  = nz * nth + 2
      n_poly = (nz - 1) * nth * 2 + 2 * nth
      mesh   = Geom::PolygonMesh.new(n_pts, n_poly)

      idx = Array.new(nz) { Array.new(nth) }
      nz.times { |j| nth.times { |i| idx[j][i] = mesh.add_point(verts[j][i]) } }

      cx    = x_off  * sc * uf
      z_top = length * sc * uf
      idx_bot = mesh.add_point(Geom::Point3d.new(cx, 0, 0))
      idx_top = mesh.add_point(Geom::Point3d.new(cx, 0, z_top))

      # Couvercle bas (normale -Z)
      nth.times do |i|
        i2 = (i + 1) % nth
        mesh.add_polygon(idx_bot, idx[0][i2], idx[0][i])
      end

      # Faces laterales (normale +R, exterieures)
      # dup_i/dup_i2 : ignore les rangees dupliquees par pad_columns! (z=L repete)
      # tip : ignore les triangles degeneres quand les deux colonnes sont a la pointe du cone
      (nz - 1).times do |j|
        nth.times do |i|
          i2     = (i + 1) % nth
          dup_i  = (cols[i][j][0]  - cols[i][j+1][0]).abs  < 1e-9
          dup_i2 = (cols[i2][j][0] - cols[i2][j+1][0]).abs < 1e-9
          tip    = cols[i][j][1] < 1e-9 && cols[i2][j][1]  < 1e-9
          a, b, c, dv = idx[j][i], idx[j][i2], idx[j+1][i2], idx[j+1][i]
          mesh.add_polygon(a, b, c)  unless dup_i2 || tip
          mesh.add_polygon(a, c, dv) unless dup_i
        end
      end

      # Couvercle haut (normale +Z)
      nth.times do |i|
        i2 = (i + 1) % nth
        mesh.add_polygon(idx_top, idx[nz-1][i], idx[nz-1][i2])
      end

      group = model.entities.add_group
      group.entities.fill_from_mesh(mesh, true, 0)
      group.name = "Tige #{format_name(params)}"
      group.transform!(Geom::Transformation.scaling(ORIGIN, 1.0 / sc))
      group
    end

    # =========================================================================
    # Ecrou hexagonal (filet interne, alesage D+gap, forme hex exterieure)
    # Tout dans un seul PolygonMesh => solide garanti, zero booleen
    # =========================================================================
    def self.generate_ecrou(params, model, x_off = 0.0)
      d      = params['d'].to_f
      pitch  = params['pitch'].to_f
      length = params.fetch('length_ecrou', params.fetch('length', 8.0)).to_f
      nth    = params['n_theta'].to_i
      gap    = params['gap'].to_f
      chamf  = params['chamfer']

      n6 = nth / 6

      # Dimensions hex (DIN 934 ou formule approchee)
      m_size = params['m_size'].to_s
      s_flat = if Presets::ISO_PRESETS.key?(m_size)
        Presets::ISO_PRESETS[m_size][:s_nut]
      else
        Presets.s_nut_for(d)
      end
      hex_r = s_flat / Math.sqrt(3.0)

      # Profil de l'alesage : l'ecrou est decale de gap/2 radialement par rapport a la tige
      # r_bore_min = crete ecrou (s'engage dans le creux de la tige) = r_minor_tige + gap/2
      # r_bore_max = fond ecrou  (recoit la crete de la tige)        = r_major_tige + gap/2
      max_angle  = params.fetch('max_overhang_angle', 45.0).to_f
      ext_prof   = make_profile(params['profile_type'], d / 2.0, pitch, max_angle)
      r_bore_min = ext_prof.r_minor + gap   # gap applique au rayon
      r_bore_max = ext_prof.r_major + gap
      bore_prof  = make_profile_custom(params['profile_type'], r_bore_max, r_bore_min, pitch)

      uf = unit_factor
      sc = compute_scale(pitch, nth, uf)

      cols = build_columns(nth, pitch, length, bore_prof, chamf, true)
      pad_columns!(cols)
      nz = cols.first.length

      bore_verts = build_verts(nth, nz, cols, x_off, uf, sc)

      # Sommets hex haut et bas
      hex_top_pts = []
      hex_bot_pts = []
      6.times do |k|
        angle = 2.0 * Math::PI * k / 6.0
        hx = (x_off + hex_r * Math.cos(angle)) * sc * uf
        hy = hex_r * Math.sin(angle) * sc * uf
        hex_top_pts << Geom::Point3d.new(hx, hy, length * sc * uf)
        hex_bot_pts << Geom::Point3d.new(hx, hy, 0)
      end

      n_bore_wall = (nz - 1) * nth * 2
      n_annular   = 2 * 6 * (n6 + 1)
      n_hex_walls = 12
      mesh = Geom::PolygonMesh.new(nz * nth + 14, n_bore_wall + n_annular + n_hex_walls)

      b_idx  = Array.new(nz) { Array.new(nth) }
      nz.times { |j| nth.times { |i| b_idx[j][i] = mesh.add_point(bore_verts[j][i]) } }

      ht_idx = hex_top_pts.map { |pt| mesh.add_point(pt) }
      hb_idx = hex_bot_pts.map { |pt| mesh.add_point(pt) }

      # Filet interne (winding inverse => normales vers l'axe de l'alesage)
      (nz - 1).times do |j|
        nth.times do |i|
          i2     = (i + 1) % nth
          dup_i  = (cols[i][j][0]  - cols[i][j+1][0]).abs  < 1e-9
          dup_i2 = (cols[i2][j][0] - cols[i2][j+1][0]).abs < 1e-9
          tip    = cols[i][j][1] < 1e-9 && cols[i2][j][1]  < 1e-9
          a, b, c, dv = b_idx[j][i], b_idx[j][i2], b_idx[j+1][i2], b_idx[j+1][i]
          mesh.add_polygon(c, b, a)  unless dup_i2 || tip
          mesh.add_polygon(dv, c, a) unless dup_i
        end
      end

      # Face annulaire haute (normale +Z)
      6.times do |k|
        n6.times do |j|
          ca = b_idx[nz-1][(k * n6 + j)     % nth]
          cb = b_idx[nz-1][(k * n6 + j + 1) % nth]
          mesh.add_polygon(ht_idx[k], cb, ca)
        end
        mesh.add_polygon(ht_idx[k], ht_idx[(k+1)%6], b_idx[nz-1][(k+1)*n6 % nth])
      end

      # Face annulaire basse (normale -Z)
      6.times do |k|
        n6.times do |j|
          ca = b_idx[0][(k * n6 + j)     % nth]
          cb = b_idx[0][(k * n6 + j + 1) % nth]
          mesh.add_polygon(hb_idx[k], ca, cb)
        end
        mesh.add_polygon(hb_idx[k], b_idx[0][(k+1)*n6 % nth], hb_idx[(k+1)%6])
      end

      # Parois hex exterieures (normales vers l'exterieur)
      6.times do |k|
        k2 = (k + 1) % 6
        mesh.add_polygon(ht_idx[k], hb_idx[k],  hb_idx[k2])
        mesh.add_polygon(ht_idx[k], hb_idx[k2], ht_idx[k2])
      end

      group = model.entities.add_group
      group.entities.fill_from_mesh(mesh, true, 0)
      group.name = "Ecrou #{format_name(params)}"
      group.transform!(Geom::Transformation.scaling(ORIGIN, 1.0 / sc))
      group
    end

    # =========================================================================
    # Helpers prives
    # =========================================================================

    # Facteur de conversion : 1 unite du modele courant => pouces SketchUp
    def self.unit_factor
      case Sketchup.active_model.options['UnitsOptions']['LengthUnit']
      when 4 then 1.0.m
      when 3 then 1.0.cm
      when 2 then 1.0.mm
      when 1 then 1.0.feet
      else        1.0
      end
    end

    # Scale trick adaptatif : SCALE=100 si la geometrie risque d'etre trop petite
    # pour la tolerance interne SketchUp (~0,001"), sinon SCALE=1.
    # Critere : espacement min de l'helice (pitch/n_theta) en pouces < 0,1"
    def self.compute_scale(pitch, n_theta, uf)
      (pitch.to_f / n_theta) * uf < 0.1 ? 100.0 : 1.0
    end

    def self.make_profile(type, r_major, pitch, max_angle = 45.0)
      type == 'iso' ? Profiles::IsoProfile.new(r_major, pitch)
                    : Profiles::PlasticProfile.new(r_major, pitch, nil, max_angle)
    end

    def self.make_profile_custom(type, r_major, r_minor, pitch)
      type == 'iso' ? Profiles::IsoProfile.new(r_major, pitch, r_minor)
                    : Profiles::PlasticProfile.new(r_major, pitch, r_minor)
    end

    # Colonnes de (z, r) placees exactement aux transitions de profil
    # bore=true : applique apply_bore_chamfer (alesage) au lieu de apply_chamfer (tige)
    def self.build_columns(nth, pitch, length, profile, chamfer, bore = false)
      columns = []
      nth.times do |i|
        theta        = 2.0 * Math::PI * i / nth
        theta_offset = i.to_f * pitch / nth

        features = []
        profile.feature_phases.each do |phase_f, _|
          k_min = -(length / pitch + 2).ceil
          k_max =  (length / pitch + 2).ceil
          (k_min..k_max).each do |k|
            z = theta_offset + phase_f * pitch + k * pitch
            next if z < -1e-9 || z > length + 1e-9
            z = [[z, 0.0].max, length].min
            r = profile.radius_at(theta, z)
            if chamfer
              r = bore ? apply_bore_chamfer(r, z, length, profile.r_minor, pitch)
                       : apply_chamfer(r, z, length, profile.r_major, profile.r_minor, pitch)
            end
            features << [z, r]
          end
        end

        features.sort_by! { |e| e[0] }
        features.uniq!    { |e| (e[0] * 1_000_000).round }

        # Cap z=0
        # Pour le bore : force r=r_minor a z=0 (remplace le rayon du profil si necessaire)
        # => b_idx[0] aura un rayon constant => face annulaire basse parfaitement plane.
        r_cap_bot = bore ? profile.r_minor : profile.radius_at(theta, 0.0)
        if chamfer
          r_cap_bot = bore ? apply_bore_chamfer(r_cap_bot, 0.0, length, profile.r_minor, pitch)
                           : apply_chamfer(r_cap_bot, 0.0, length, profile.r_major, profile.r_minor, pitch)
        end
        if features.empty? || features.first[0] > 1e-9
          features.unshift([0.0, r_cap_bot])
        elsif bore
          features.first[1] = r_cap_bot  # ecrase le rayon existant
        end

        # Cap z=L (meme logique)
        r_cap_top = bore ? profile.r_minor : profile.radius_at(theta, length)
        if chamfer
          r_cap_top = bore ? apply_bore_chamfer(r_cap_top, length, length, profile.r_minor, pitch)
                           : apply_chamfer(r_cap_top, length, length, profile.r_major, profile.r_minor, pitch)
        end
        if features.empty? || features.last[0] < length - 1e-9
          features.push([length, r_cap_top])
        elsif bore
          features.last[1] = r_cap_top
        end

        columns << features
      end
      columns
    end

    # Chanfrein d'entree de filet (haut uniquement, 45 deg) :
    # Lc = pitch (1 pas axial — assez long pour etre visible).
    # effective_r = min(profile_r, cone_r) => le cone ne fait QUE soustraire de la matiere.
    # Cretes clippees des le debut. Creux preserves jusqu'a ce que le cone les atteigne,
    # puis manges progressivement (min => jamais de saut brutal, pas de raccord).
    def self.apply_chamfer(r, z, length, r_major, r_minor, pitch)
      lc = pitch.to_f
      return r if z < length - lc
      cone_r = [r_major - (z - (length - lc)), 0.0].max
      [r.to_f, cone_r].min
    end

    # Chanfrein de l'alesage (ecrou) — miroir exact du chanfrein de la tige.
    # Tige : min(r, cone_r)       => cone soustrait de la matiere (crete vers axe)
    # Ecrou : max(r, r_chamfer)   => cone soustrait de la matiere (alésage s'ouvre)
    # Les fonds du filet (r_bore_max) sont preserves jusqu'a ce que le cone les atteigne,
    # puis manges progressivement — pas de saut brutal, symétrie parfaite.
    def self.apply_bore_chamfer(r, z, length, r_bore_min, pitch)
      lc = pitch.to_f
      if z <= lc
        [r.to_f, r_bore_min + (lc - z)].max
      elsif z >= length - lc
        [r.to_f, r_bore_min + (z - (length - lc))].max
      else
        r
      end
    end

    def self.pad_columns!(columns)
      max_len = columns.map(&:length).max
      columns.each do |col|
        pad = col.last
        (max_len - col.length).times { col << pad }
      end
    end

    def self.build_verts(nth, nz, columns, x_off, uf, sc)
      verts = Array.new(nz) { Array.new(nth) }
      nz.times do |j|
        nth.times do |i|
          theta = 2.0 * Math::PI * i / nth
          z, r  = columns[i][j]
          x = (x_off + r * Math.cos(theta)) * sc
          y = r * Math.sin(theta) * sc
          verts[j][i] = Geom::Point3d.new(x * uf, y * uf, z * sc * uf)
        end
      end
      verts
    end

    def self.add_center_lines_scaled(entities, r, length, x_off, uf, sc)
      r_s = r      * sc * uf
      cx  = x_off  * sc * uf
      zt  = length * sc * uf

      [0.0, zt].each do |z|
        entities.add_line(Geom::Point3d.new(cx - r_s, 0,    z),
                          Geom::Point3d.new(cx + r_s, 0,    z))
        entities.add_line(Geom::Point3d.new(cx,       -r_s, z),
                          Geom::Point3d.new(cx,        r_s, z))
      end
    end

    def self.format_name(params)
      d     = params['d'].to_f
      pitch = params['pitch'].to_f
      len   = params['length'].to_f
      type  = params['profile_type'] == 'iso' ? 'ISO' : 'FDM'
      d_str = d == d.to_i ? d.to_i.to_s : d.to_s
      "M#{d_str}x#{pitch} L#{len.to_i} #{type}"
    end

    private_class_method :unit_factor, :compute_scale,
                         :make_profile, :make_profile_custom,
                         :build_columns, :apply_chamfer, :apply_bore_chamfer,
                         :pad_columns!, :build_verts, :add_center_lines_scaled, :format_name

  end
end
