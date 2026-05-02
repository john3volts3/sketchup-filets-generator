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
# Chanfrein :
#   apply_chamfer_rod/nut() — boolean subtract apres generation du filet.
#   Tige : ring frustum (cone interne + cylindre externe).
#   Ecrou : deux frustums solides (un par face).

module VisFiletsGenerator
  module Geometry

    # =========================================================================
    # Point d'entree
    # =========================================================================
    def self.generate(params, model)
      d   = params['d'].to_f
      gap = params['gap'].to_f
      uf  = unit_factor
      tige_group  = nil
      ecrou_group = nil

      # L'ecrou est genere en dehors du rod (x_off) pour eviter la superposition
      # pendant les operations boolennes de chanfrein. Il sera ramene a x=0 ensuite.
      x_off_ecrou = (params['create_tige'] && params['create_ecrou']) ? (d * 2.5 + gap) : 0.0

      model.start_operation('Vis & Filets', true)
      begin
        tige_group  = generate_tige(params, model, 0.0)         if params['create_tige']
        ecrou_group = generate_ecrou(params, model, x_off_ecrou) if params['create_ecrou']
        model.commit_operation
      rescue => e
        model.abort_operation
        UI.messagebox(
          "Erreur de generation :\n#{e.message}\n\n#{e.backtrace.first(3).join("\n")}",
          MB_OK
        )
        return
      end

      if params['chamfer']
        pitch = params['pitch'].to_f
        lc    = params.fetch('chamfer_height', pitch).to_f
        nth   = params['n_theta'].to_i

        if tige_group
          length         = params.fetch('length_tige', params.fetch('length', 50.0)).to_f
          max_angle      = params.fetch('max_overhang_angle', 45.0).to_f
          min_core_ratio = params.fetch('min_core_pct', 70.0).to_f / 100.0
          profile        = make_profile(params['profile_type'], d / 2.0, pitch, max_angle, min_core_ratio)
          tige_group     = apply_chamfer_rod(model, tige_group, profile.r_major, profile.r_minor,
                                             lc, length, 0.0, nth, uf)
        end

        if ecrou_group
          length         = params.fetch('length_ecrou', params.fetch('length', 8.0)).to_f
          max_angle      = params.fetch('max_overhang_angle', 45.0).to_f
          min_core_ratio = params.fetch('min_core_pct', 70.0).to_f / 100.0
          profile        = make_profile(params['profile_type'], d / 2.0, pitch, max_angle, min_core_ratio)
          r_bore_min     = profile.r_minor + gap
          ecrou_group    = apply_chamfer_nut(model, ecrou_group, r_bore_min, lc, length,
                                             x_off_ecrou, nth, uf)
        end
      end

      # Ramener l'ecrou a l'origine apres chanfrein
      if ecrou_group&.valid? && x_off_ecrou != 0.0
        model.start_operation('Deplacer ecrou', true)
        ecrou_group.transform!(Geom::Transformation.translation(
          Geom::Vector3d.new(-x_off_ecrou * uf, 0, 0)
        ))
        model.commit_operation
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

      uf             = unit_factor
      sc             = compute_scale(pitch, nth, uf)
      max_angle      = params.fetch('max_overhang_angle', 45.0).to_f
      min_core_ratio = params.fetch('min_core_pct', 70.0).to_f / 100.0
      profile        = make_profile(params['profile_type'], d / 2.0, pitch, max_angle, min_core_ratio)
      cols           = build_columns(nth, pitch, length, profile)
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

      n6 = nth / 6

      # Dimensions hex (DIN 934 ou formule approchee)
      m_size = params['m_size'].to_s
      s_flat = if Presets::ISO_PRESETS.key?(m_size)
        Presets::ISO_PRESETS[m_size][:s_nut]
      else
        Presets.s_nut_for(d)
      end
      hex_r = s_flat / Math.sqrt(3.0)

      max_angle      = params.fetch('max_overhang_angle', 45.0).to_f
      min_core_ratio = params.fetch('min_core_pct', 70.0).to_f / 100.0
      ext_prof       = make_profile(params['profile_type'], d / 2.0, pitch, max_angle, min_core_ratio)
      r_bore_min = ext_prof.r_minor + gap   # gap applique au rayon
      r_bore_max = ext_prof.r_major + gap
      bore_prof  = make_profile_custom(params['profile_type'], r_bore_max, r_bore_min, pitch, max_angle)

      uf = unit_factor
      sc = compute_scale(pitch, nth, uf)

      cols = build_columns(nth, pitch, length, bore_prof)
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

    def self.make_profile(type, r_major, pitch, max_angle = 45.0, min_core_ratio = 0.70)
      type == 'iso' ? Profiles::IsoProfile.new(r_major, pitch)
                    : Profiles::PlasticProfile.new(r_major, pitch, nil, max_angle, min_core_ratio)
    end

    def self.make_profile_custom(type, r_major, r_minor, pitch, max_overhang_deg = 60.0)
      type == 'iso' ? Profiles::IsoProfile.new(r_major, pitch, r_minor)
                    : Profiles::PlasticProfile.new(r_major, pitch, r_minor, max_overhang_deg)
    end

    # Colonnes de (z, r) placees exactement aux transitions de profil
    def self.build_columns(nth, pitch, length, profile)
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
            features << [z, r]
          end
        end

        features.sort_by! { |e| e[0] }
        features.uniq!    { |e| (e[0] * 1_000_000).round }

        if features.empty? || features.first[0] > 1e-9
          r0 = profile.radius_at(theta, 0.0)
          features.unshift([0.0, r0])
        end
        if features.empty? || features.last[0] < length - 1e-9
          rl = profile.radius_at(theta, length)
          features.push([length, rl])
        end

        columns << features
      end
      columns
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

    # =========================================================================
    # Chanfrein par boolean subtract — ring frustum pour la tige
    #
    # Outil : tore tronconique de 4 anneaux :
    #   A (r_major, z=L-lc)  B (r_outer, z=L-lc)
    #   C (r_outer, z=L)     D (r_minor, z=L)
    # Faces normales outward calculees analytiquement (verified manifold).
    # =========================================================================
    def self.apply_chamfer_rod(model, group, r_major, r_minor, lc, length, x_off, nth, uf)
      r_outer = r_major * 1.5
      z_bot   = length - lc
      z_top   = length

      a_idx = Array.new(nth)
      b_idx = Array.new(nth)
      c_idx = Array.new(nth)
      d_idx = Array.new(nth)

      mesh = Geom::PolygonMesh.new(nth * 4, nth * 8)
      nth.times do |i|
        theta = 2.0 * Math::PI * i / nth
        ct    = Math.cos(theta)
        st    = Math.sin(theta)
        a_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r_major * ct) * uf, r_major * st * uf, z_bot * uf))
        b_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r_outer * ct) * uf, r_outer * st * uf, z_bot * uf))
        c_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r_outer * ct) * uf, r_outer * st * uf, z_top * uf))
        d_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r_minor * ct) * uf, r_minor * st * uf, z_top * uf))
      end

      nth.times do |i|
        i2 = (i + 1) % nth
        mesh.add_polygon(a_idx[i], a_idx[i2], b_idx[i2])  # fond -Z
        mesh.add_polygon(a_idx[i], b_idx[i2], b_idx[i])
        mesh.add_polygon(b_idx[i], b_idx[i2], c_idx[i2])  # cylindre ext +R
        mesh.add_polygon(b_idx[i], c_idx[i2], c_idx[i])
        mesh.add_polygon(c_idx[i], c_idx[i2], d_idx[i2])  # dessus +Z
        mesh.add_polygon(c_idx[i], d_idx[i2], d_idx[i])
        mesh.add_polygon(a_idx[i], d_idx[i],  d_idx[i2])  # cone interne (inward)
        mesh.add_polygon(a_idx[i], d_idx[i2], a_idx[i2])
      end

      model.start_operation('Chanfrein tige', true)
      tool = model.entities.add_group
      tool.entities.fill_from_mesh(mesh, true, 0)
      result = solid_subtract(model, group, tool)
      if result.nil?
        tool.erase! if tool.valid?
        model.abort_operation
        UI.messagebox('Chanfrein tige : opération booléenne échouée.', MB_OK)
        return group
      end
      model.commit_operation
      result
    end

    # =========================================================================
    # Chanfrein par boolean subtract — deux frustums (cones tronques) pour l'ecrou
    #
    # Entree (z=0)  : anneau large r_bore_min+lc -> anneau etroit r_bore_min a z=lc
    # Sortie (z=L)  : anneau etroit r_bore_min a z=L-lc -> anneau large r_bore_min+lc
    # Chaque frustum = 2 capuchons en eventail + surface laterale.
    # =========================================================================
    def self.apply_chamfer_nut(model, group, r_bore_min, lc, length, x_off, nth, uf)
      r_wide   = r_bore_min + lc
      r_narrow = r_bore_min

      # eps : depasse legerement les faces de l'ecrou pour eviter faces coplanaires / tangentes
      eps = [lc * 0.1, 0.1].max

      # idx=0 → face z=0 : etendu de -eps a lc+eps, rayons ajustes pour garder l'angle
      # idx=1 → face z=L : etendu de L-lc-eps a L+eps, meme principe
      [
        [-eps,            lc + eps,      r_wide + eps, r_narrow - eps],
        [length - lc - eps, length + eps, r_narrow - eps, r_wide  + eps]
      ].each do |z_bot, z_top, r_bot, r_top|
        bot_idx = Array.new(nth)
        top_idx = Array.new(nth)
        mesh    = Geom::PolygonMesh.new(nth * 2 + 2, nth * 4)

        nth.times do |i|
          theta = 2.0 * Math::PI * i / nth
          ct    = Math.cos(theta)
          st    = Math.sin(theta)
          bot_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r_bot * ct) * uf, r_bot * st * uf, z_bot * uf))
          top_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r_top * ct) * uf, r_top * st * uf, z_top * uf))
        end
        cb = mesh.add_point(Geom::Point3d.new(x_off * uf, 0, z_bot * uf))
        ct_pt = mesh.add_point(Geom::Point3d.new(x_off * uf, 0, z_top * uf))

        nth.times do |i|
          i2 = (i + 1) % nth
          mesh.add_polygon(cb,    bot_idx[i2], bot_idx[i])   # cap bas -Z
          mesh.add_polygon(ct_pt, top_idx[i],  top_idx[i2])  # cap haut +Z
          mesh.add_polygon(bot_idx[i], bot_idx[i2], top_idx[i2])  # lateral +R
          mesh.add_polygon(bot_idx[i], top_idx[i2], top_idx[i])
        end

        model.start_operation('Chanfrein ecrou', true)
        tool   = model.entities.add_group
        tool.entities.fill_from_mesh(mesh, true, 0)
        result = solid_subtract(model, group, tool)
        if result.nil?
          tool.erase! if tool.valid?
          model.abort_operation
          UI.messagebox("Chanfrein écrou (z=#{z_bot.round}) : opération booléenne échouée.", MB_OK)
        else
          model.commit_operation
          group = result
        end
      end
      group
    end

    # Boolean subtract portable Pro / non-Pro.
    # Native SU (Pro) : receiver=cutter, arg=target → on swap pour obtenir target-tool.
    # Eneroth         : premier arg=target, second=cutter → appel direct.
    def self.solid_subtract(model, target, tool)
      if target.respond_to?(:subtract)
        tool.subtract(target)
      else
        begin
          require 'Eneroth Solid Tools/eneroth_solid_tools'
          Eneroth::SolidTools.subtract(target, tool)
        rescue LoadError
          tool.erase! if tool.valid?
          UI.messagebox(
            "Solid Tools non disponible.\n" \
            "Installez 'Eneroth Solid Tools' ou utilisez SketchUp Pro.",
            MB_OK
          )
          nil
        end
      end
    end

    private_class_method :unit_factor, :compute_scale,
                         :make_profile, :make_profile_custom,
                         :build_columns, :apply_chamfer_rod, :apply_chamfer_nut,
                         :solid_subtract,
                         :pad_columns!, :build_verts, :add_center_lines_scaled, :format_name

  end
end
