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

    # DEBUG : mettre true pour voir le sablier sans faire le subtract
    DEBUG_CHAMFER_NUT = false

    # =========================================================================
    # Point d'entree
    # =========================================================================
    def self.generate(params, model)
      d     = params['d'].to_f
      gap   = params['gap'].to_f
      pitch = params['pitch'].to_f
      nth   = params['n_theta'].to_i
      uf    = unit_factor
      tige_group   = nil
      ecrou_group  = nil
      taraud_group = nil

      x_off_ecrou = (params['create_tige'] && params['create_ecrou']) ? (d * 2.5 + gap) : 0.0

      model.start_operation('Vis & Filets', true)
      begin
        tige_group   = generate_tige(params, model, 0.0)          if params['create_tige']
        ecrou_group  = generate_ecrou(params, model, x_off_ecrou)  if params['create_ecrou']
        taraud_group = generate_taraud(params, model)              if params['create_taraud']
        model.commit_operation
      rescue => e
        model.abort_operation
        UI.messagebox(
          "Erreur de generation :\n#{e.message}\n\n#{e.backtrace.first(3).join("\n")}",
          MB_OK
        )
        return
      end

      max_angle      = params.fetch('max_overhang_angle', 45.0).to_f
      min_core_ratio = params.fetch('min_core_pct', 70.0).to_f / 100.0
      lc             = params.fetch('chamfer_height', pitch).to_f

      if tige_group
        length_tige  = params.fetch('length_tige', params.fetch('length', 50.0)).to_f
        tige_profile = make_profile(params['profile_type'], d / 2.0, pitch, max_angle, min_core_ratio)

        if params['chamfer']
          tige_group = apply_chamfer_rod(model, tige_group, tige_profile.r_major, tige_profile.r_minor,
                                         lc, length_tige, 0.0, nth, uf)
        end
      end

      if ecrou_group
        length_ecrou  = params.fetch('length_ecrou', params.fetch('length', 8.0)).to_f
        ecrou_profile = make_profile(params['profile_type'], d / 2.0, pitch, max_angle, min_core_ratio)

        if params['chamfer']
          r_bore_min  = ecrou_profile.r_minor + gap
          ecrou_group = apply_chamfer_nut(model, ecrou_group, r_bore_min, lc, length_ecrou,
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
    # profile_override : passer un profil precalcule (utilise pour le bore rod de l'ecrou)
    # length_override  : longueur en unites modele (remplace length_tige du params)
    def self.generate_tige(params, model, x_off = 0.0, profile_override = nil, length_override = nil)
      pitch  = params['pitch'].to_f
      length = length_override || params.fetch('length_tige', params.fetch('length', 50.0)).to_f
      nth    = params['n_theta'].to_i

      uf      = unit_factor
      sc      = compute_scale(pitch, nth, uf)
      profile = profile_override || begin
        d              = params['d'].to_f
        max_angle      = params.fetch('max_overhang_angle', 45.0).to_f
        min_core_ratio = params.fetch('min_core_pct', 70.0).to_f / 100.0
        make_profile(params['profile_type'], d / 2.0, pitch, max_angle, min_core_ratio)
      end
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
    # Ecrou hexagonal — nouvelle strategie : hex plein − bore rod (boolean)
    #
    # 1. Prisme hexagonal plein (generate_hex_prism) — solide simple, sans defaut
    # 2. Bore rod : tige avec le profil de l'alesage, longueur = L + 2*ext
    #    (ext = 0.5 unites modele pour depasser les faces top/bottom)
    # 3. Boolean subtract bore_rod du hex → nut propre, faces parfaites
    # =========================================================================
    def self.generate_ecrou(params, model, x_off = 0.0)
      d      = params['d'].to_f
      pitch  = params['pitch'].to_f
      length = params.fetch('length_ecrou', params.fetch('length', 8.0)).to_f
      gap    = params['gap'].to_f

      # Dimensions hex :
      #   ISO preset connu  → table DIN 934
      #   FDM (m_size=custom, profil plastic) → 2 × D (solidite suffisante en plastique)
      #   Autre custom ISO  → formule approchee 1.75 × D
      m_size = params['m_size'].to_s
      s_flat = if Presets::ISO_PRESETS.key?(m_size)
        Presets::ISO_PRESETS[m_size][:s_nut]
      elsif params['profile_type'] == 'plastic'
        # Ecrou ISO de taille superieure ou egale la plus proche → son s_nut
        sorted = Presets::ISO_PRESETS.values.sort_by { |p| p[:d] }
        match  = sorted.find { |p| p[:d] >= d }
        match ? match[:s_nut] : 2.0 * d   # > M32 : 2 x D
      else
        Presets.s_nut_for(d)
      end
      hex_r  = s_flat / Math.sqrt(3.0)

      max_angle      = params.fetch('max_overhang_angle', 45.0).to_f
      min_core_ratio = params.fetch('min_core_pct', 70.0).to_f / 100.0
      ext_prof       = make_profile(params['profile_type'], d / 2.0, pitch, max_angle, min_core_ratio)
      r_bore_max     = ext_prof.r_major + gap
      r_bore_min     = ext_prof.r_minor + gap
      bore_prof      = make_profile_custom(params['profile_type'], r_bore_max, r_bore_min, pitch, max_angle)

      uf       = unit_factor
      sc       = compute_scale(pitch, params['n_theta'].to_i, uf)
      ext_bot  = 0.01  # minuscule — evite la coplanarité boolean sans dephacer le filet
      ext_top  = 0.5   # assure une coupe propre sur la face haute

      # 1. Prisme hexagonal plein
      hex_group = generate_hex_prism(model, x_off, hex_r, length, uf, sc)

      # 2. Bore rod (s'etend de -ext_bot a length+ext_top)
      bore_rod = generate_tige(params, model, x_off, bore_prof, length + ext_bot + ext_top)
      bore_rod.transform!(Geom::Transformation.translation(
        Geom::Vector3d.new(0, 0, -ext_bot * uf)
      ))

      # 3. Boolean subtract : hex − bore_rod = nut
      model.start_operation('Ecrou boolean', true)
      result = solid_subtract(model, hex_group, bore_rod)
      if result.nil?
        bore_rod.erase! if bore_rod.valid?
        model.abort_operation
        UI.messagebox('Écrou : soustraction booléenne échouée — écrou sans alésage.', MB_OK)
        return hex_group
      end
      model.commit_operation
      result.name = "Ecrou #{format_name(params)}"
      result
    end

    # =========================================================================
    # Taraud — bore rod fileteé + cylindre plein + prisme carré
    #
    # Geometrie (bas → haut) :
    #   z = 0          .. length_taraud  : bore rod (filet interne, profil ecrou)
    #   z = length_taraud .. +D          : cylindre plein (rayon D/2)
    #   z = length_taraud+D .. +0.45*D  : prisme carre (cote 0.72*D)
    #
    # Les trois parties sont unies par boolean. Si l'union echoue (Pro/Eneroth
    # requis), les 3 groupes sont conserves separes avec des noms explicites.
    # =========================================================================
    def self.generate_taraud(params, model, x_off = 0.0)
      d      = params['d'].to_f
      pitch  = params['pitch'].to_f
      length = params.fetch('length_taraud', 20.0).to_f
      gap    = params['gap'].to_f

      max_angle      = params.fetch('max_overhang_angle', 45.0).to_f
      min_core_ratio = params.fetch('min_core_pct', 70.0).to_f / 100.0
      ext_prof  = make_profile(params['profile_type'], d / 2.0, pitch, max_angle, min_core_ratio)
      r_bore_max = ext_prof.r_major + gap
      r_bore_min = ext_prof.r_minor + gap
      bore_prof  = make_profile_custom(params['profile_type'], r_bore_max, r_bore_min, pitch, max_angle)

      uf    = unit_factor
      nth   = params['n_theta'].to_i
      # Cylindre de degagement : legerement plus petit que le diametre interieur du filet
      r_cyl = ext_prof.r_minor * 0.95
      h_cyl = d
      sq_hs = (r_cyl / Math.sqrt(2.0)) * 0.9   # inscrit dans le cylindre, 10% marge
      h_sq  = d * 0.45

      label = format_name_tap(params)

      # 1. Bore rod fileté — allongé pour compenser le cône de pointe (lc = r_bore_max)
      length_rod = length + r_bore_max * 1.1
      bore_rod = generate_tige(params, model, x_off, bore_prof, length_rod)

      # 2. Chanfrein d'entree en bas — meme technique que apply_chamfer_rod mais a z=0
      bore_rod = apply_chamfer_tap_bottom(model, bore_rod, r_bore_max, r_bore_min, pitch, x_off, nth, uf)

      # 3. Cylindre de degagement
      cyl = generate_plain_cylinder(model, x_off, r_cyl, length, h_cyl, nth, uf)

      # 4. Prisme carre avec croix d'alignement
      sq = generate_square_prism(model, x_off, sq_hs, length + h_cyl, h_sq, uf)

      # 5. Union booléenne : bore_rod + cyl + sq
      model.start_operation('Tap union', true)
      merged = solid_union(model, bore_rod, cyl)
      if merged
        merged2 = solid_union(model, merged, sq)
        if merged2
          model.commit_operation
          merged2.name = "Tap #{label}"
          apply_tap_color(model, merged2, params)
          return merged2
        end
      end
      model.abort_operation

      # Fallback : 3 groupes separes
      bore_rod.name = "Tap #{label} — Thread"  if bore_rod.valid?
      cyl.name      = "Tap #{label} — Shank"   if cyl.valid?
      sq.name       = "Tap #{label} — Square"  if sq.valid?
      apply_tap_color(model, bore_rod, params) if bore_rod.valid?
      apply_tap_color(model, cyl,      params) if cyl.valid?
      apply_tap_color(model, sq,       params) if sq.valid?
      UI.messagebox(
        "Tap: boolean union failed (SketchUp Pro or Eneroth Solid Tools required).\n" \
        "3 separate groups created — use the Thread group as subtraction tool.",
        MB_OK
      )
      bore_rod
    end

    # Assigne la couleur du tap depuis params['tap_color'] (hex '#RRGGBB').
    # Chaine vide ou absente = pas de couleur assignée.
    def self.apply_tap_color(model, group, params)
      hex = params['tap_color'].to_s
      return unless hex =~ /\A#[0-9a-fA-F]{6}\z/
      mat = model.materials['Tap'] || model.materials.add('Tap')
      mat.color = Sketchup::Color.new(hex[1,2].to_i(16), hex[3,2].to_i(16), hex[5,2].to_i(16))
      group.material = mat
    rescue; end


    # Cylindre plein, de z_bot à z_bot+height, rayon r, centré en (x_off, 0).
    def self.generate_plain_cylinder(model, x_off, r, z_bot, height, nth, uf)
      mesh = Geom::PolygonMesh.new(2 * nth + 2, 4 * nth)
      b_idx = Array.new(nth)
      t_idx = Array.new(nth)
      nth.times do |i|
        theta = 2.0 * Math::PI * i / nth
        ct = Math.cos(theta); st = Math.sin(theta)
        b_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r*ct)*uf, r*st*uf,          z_bot         *uf))
        t_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r*ct)*uf, r*st*uf, (z_bot + height)*uf))
      end
      c_bot = mesh.add_point(Geom::Point3d.new(x_off*uf, 0,          z_bot         *uf))
      c_top = mesh.add_point(Geom::Point3d.new(x_off*uf, 0, (z_bot + height)*uf))
      nth.times do |i|
        i2 = (i + 1) % nth
        mesh.add_polygon(c_bot, b_idx[i2], b_idx[i])       # fond   -Z
        mesh.add_polygon(b_idx[i], b_idx[i2], t_idx[i2])   # paroi
        mesh.add_polygon(b_idx[i], t_idx[i2], t_idx[i])
        mesh.add_polygon(c_top, t_idx[i],  t_idx[i2])      # dessus +Z
      end
      group = model.entities.add_group
      group.entities.fill_from_mesh(mesh, true, 0)
      group
    end

    # Prisme a section carree, de z_bot a z_bot+height, demi-cote half_s, centre en (x_off, 0).
    # Coins (sens anti-horaire depuis le dessus) : NE, NO, SO, SE.
    def self.generate_square_prism(model, x_off, half_s, z_bot, height, uf)
      s  = half_s * uf
      xc = x_off  * uf
      zb = z_bot  * uf
      zt = (z_bot + height) * uf
      b = [Geom::Point3d.new(xc+s,  s, zb), Geom::Point3d.new(xc-s,  s, zb),
           Geom::Point3d.new(xc-s, -s, zb), Geom::Point3d.new(xc+s, -s, zb)]
      t = [Geom::Point3d.new(xc+s,  s, zt), Geom::Point3d.new(xc-s,  s, zt),
           Geom::Point3d.new(xc-s, -s, zt), Geom::Point3d.new(xc+s, -s, zt)]
      mesh = Geom::PolygonMesh.new(8, 12)
      bi = b.map { |p| mesh.add_point(p) }
      ti = t.map { |p| mesh.add_point(p) }
      mesh.add_polygon(bi[0], bi[3], bi[2]); mesh.add_polygon(bi[0], bi[2], bi[1])  # fond -Z
      mesh.add_polygon(ti[0], ti[1], ti[2]); mesh.add_polygon(ti[0], ti[2], ti[3])  # dessus +Z
      4.times do |i|
        i2 = (i + 1) % 4
        mesh.add_polygon(bi[i], bi[i2], ti[i2])
        mesh.add_polygon(bi[i], ti[i2], ti[i])
      end
      group = model.entities.add_group
      group.entities.fill_from_mesh(mesh, true, 0)
      group
    end

    # Union booléenne portable Pro / Eneroth.
    # Retourne le groupe résultant (a, modifié, b consommé), ou nil si échec.
    def self.solid_union(model, a, b)
      if a.respond_to?(:union)
        result = a.union(b)
        (result == false || result.nil?) ? nil : result
      else
        begin
          require 'Eneroth Solid Tools/eneroth_solid_tools'
          Eneroth::SolidTools.union(a, b)
        rescue LoadError
          b.erase! if b.valid?
          nil
        end
      end
    end

    def self.format_name_tap(params)
      d     = params['d'].to_f
      pitch = params['pitch'].to_f
      len   = params.fetch('length_taraud', 20.0).to_f
      type  = params['profile_type'] == 'iso' ? 'ISO' : 'FDM'
      d_str = d == d.to_i ? d.to_i.to_s : d.to_s
      "M#{d_str}x#{pitch} L#{len.to_i} #{type}"
    end

    # Chanfrein d'entree conique en bas du tap.
    # Outil : cone plein — apex au centre (r=0, z=0), base a z=lc avec ring D(r_bore_max)
    # entouree d'un cylindre externe r_outer jusqu'en bas.
    # lc = r_bore_max → cone 45° exact qui coupe jusqu'au centre en z=0.
    # Geometrie (nth triangles fans depuis l'apex + cylindre ext + dessus) :
    #   apex(0,0)  B(r_outer,0)  C(r_outer,lc)  D(r_bore_max,lc)
    def self.apply_chamfer_tap_bottom(model, group, r_bore_max, r_bore_min, pitch, x_off, nth, uf)
      lc      = r_bore_max       # hauteur = rayon → cone 45°, coupe jusqu'au centre en z=0
      r_outer = r_bore_max * 1.5

      b_idx = Array.new(nth)
      c_idx = Array.new(nth)
      d_idx = Array.new(nth)

      mesh   = Geom::PolygonMesh.new(nth * 3 + 1, nth * 6)
      apex_i = mesh.add_point(Geom::Point3d.new(x_off * uf, 0, 0))

      nth.times do |i|
        theta    = 2.0 * Math::PI * i / nth
        ct = Math.cos(theta); st = Math.sin(theta)
        b_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r_outer    * ct) * uf, r_outer    * st * uf, 0))
        c_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r_outer    * ct) * uf, r_outer    * st * uf, lc * uf))
        d_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + r_bore_max * ct) * uf, r_bore_max * st * uf, lc * uf))
      end

      nth.times do |i|
        i2 = (i + 1) % nth
        mesh.add_polygon(apex_i, b_idx[i2], b_idx[i])     # fond disk  -Z (z=0)
        mesh.add_polygon(b_idx[i], b_idx[i2], c_idx[i2])  # paroi ext  +R
        mesh.add_polygon(b_idx[i], c_idx[i2], c_idx[i])
        mesh.add_polygon(c_idx[i], c_idx[i2], d_idx[i2])  # dessus     +Z (z=lc)
        mesh.add_polygon(c_idx[i], d_idx[i2], d_idx[i])
        mesh.add_polygon(apex_i, d_idx[i], d_idx[i2])     # cone 45°  (inward normal)
      end

      model.start_operation('Tap chamfer', true)
      tool = model.entities.add_group
      tool.entities.fill_from_mesh(mesh, true, 0)
      result = solid_subtract(model, group, tool)
      if result.nil?
        tool.erase! if tool.valid?
        model.abort_operation
        return group
      end
      model.commit_operation
      result
    end

    # Prisme hexagonal plein (6 sommets/ring, aucun thread).
    # Utilise le meme sc que le bore rod pour etre compatible avec le boolean.
    def self.generate_hex_prism(model, x_off, hex_r, length, uf, sc)
      mesh = Geom::PolygonMesh.new(14, 18)

      top_idx = []; bot_idx = []
      6.times do |k|
        angle = 2.0 * Math::PI * k / 6.0
        hx = (x_off + hex_r * Math.cos(angle)) * sc * uf
        hy = hex_r * Math.sin(angle) * sc * uf
        top_idx << mesh.add_point(Geom::Point3d.new(hx, hy, length * sc * uf))
        bot_idx << mesh.add_point(Geom::Point3d.new(hx, hy, 0))
      end
      ct = mesh.add_point(Geom::Point3d.new(x_off * sc * uf, 0, length * sc * uf))
      cb = mesh.add_point(Geom::Point3d.new(x_off * sc * uf, 0, 0))

      # Face haute +Z : centre → k → k+1
      6.times { |k| mesh.add_polygon(ct, top_idx[k], top_idx[(k+1)%6]) }
      # Face basse -Z : centre → k+1 → k
      6.times { |k| mesh.add_polygon(cb, bot_idx[(k+1)%6], bot_idx[k]) }
      # Parois (normale vers l'exterieur)
      6.times do |k|
        k2 = (k+1) % 6
        mesh.add_polygon(bot_idx[k], bot_idx[k2], top_idx[k2])
        mesh.add_polygon(bot_idx[k], top_idx[k2], top_idx[k])
      end

      group = model.entities.add_group
      group.entities.fill_from_mesh(mesh, true, 0)
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
    # Chanfrein par boolean subtract — outil "sablier" unique pour l'ecrou
    #
    # Un seul PolygonMesh connecte applique les deux chanfreins en un boolean :
    #   A (r_wide+e, z=-e)      : fond large sous l'ecrou
    #   B (r_narrow-e, z=lc+e) : etranglement bas (dans l'alesage, ne coupe rien)
    #   C (r_narrow-e, z=L-lc-e): etranglement haut (idem)
    #   D (r_wide+e, z=L+e)    : dessus large au-dessus de l'ecrou
    # Le cylindre B-C (r < r_bore_min) traverse l'alesage sans toucher le filet.
    # Un seul boolean → pas de chainage → fiable sur tous les M.
    # =========================================================================
    def self.apply_chamfer_nut(model, group, r_bore_min, lc, length, x_off, nth, uf)
      eps  = 0.1   # tolerance supplementaire (mm)
      # ext : le cone depasse les faces z=0 et z=L d'un pitch complet.
      # A 45 deg, chaque mm de z supplementaire = 1 mm de r supplementaire.
      # La surface chanfrein dans le nut (z=0→lc, r=r_bore_min+lc→r_bore_min)
      # est strictement identique — seule la partie hors du nut est plus grande.
      ext  = lc
      ra   = r_bore_min + lc + ext + eps   # rayon large (entree/sortie)
      rb   = r_bore_min - eps              # rayon etroit (cylindre central)
      za   = -(ext + eps)      # 1 pitch sous la face basse du nut
      zb   = lc + eps
      zc   = length - lc - eps
      zd   = length + ext + eps  # 1 pitch au-dessus de la face haute du nut

      if zb >= zc
        UI.messagebox(
          "Chanfrein écrou : hauteur chanfrein (#{lc.round(2)} mm) trop grande pour cet écrou (#{length.round(2)} mm). Ignoré.",
          MB_OK
        )
        return group
      end

      a_idx = Array.new(nth); b_idx = Array.new(nth)
      c_idx = Array.new(nth); d_idx = Array.new(nth)

      mesh = Geom::PolygonMesh.new(nth * 4 + 2, nth * 8)

      nth.times do |i|
        theta = 2.0 * Math::PI * i / nth
        ct = Math.cos(theta); st = Math.sin(theta)
        a_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + ra*ct)*uf, ra*st*uf, za*uf))
        b_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + rb*ct)*uf, rb*st*uf, zb*uf))
        c_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + rb*ct)*uf, rb*st*uf, zc*uf))
        d_idx[i] = mesh.add_point(Geom::Point3d.new((x_off + ra*ct)*uf, ra*st*uf, zd*uf))
      end
      cbot = mesh.add_point(Geom::Point3d.new(x_off*uf, 0, za*uf))
      ctop = mesh.add_point(Geom::Point3d.new(x_off*uf, 0, zd*uf))

      nth.times do |i|
        i2 = (i + 1) % nth
        mesh.add_polygon(cbot,    a_idx[i2], a_idx[i])        # cap bas   -Z
        mesh.add_polygon(a_idx[i], a_idx[i2], b_idx[i2])      # cone bas  +R+Z
        mesh.add_polygon(a_idx[i], b_idx[i2], b_idx[i])
        mesh.add_polygon(b_idx[i], b_idx[i2], c_idx[i2])      # cylindre  +R
        mesh.add_polygon(b_idx[i], c_idx[i2], c_idx[i])
        mesh.add_polygon(c_idx[i], c_idx[i2], d_idx[i2])      # cone haut +R-Z
        mesh.add_polygon(c_idx[i], d_idx[i2], d_idx[i])
        mesh.add_polygon(ctop,    d_idx[i],   d_idx[i2])      # cap haut  +Z
      end

      model.start_operation('Chanfrein ecrou', true)
      tool = model.entities.add_group
      tool.entities.fill_from_mesh(mesh, true, 0)
      tool.name = 'DEBUG_sablier_ecrou'

      if DEBUG_CHAMFER_NUT
        # Mode debug : sablier laisse visible, pas de subtract
        model.commit_operation
        puts '[VFG DEBUG] Sablier ecrou construit et laisse visible (DEBUG_CHAMFER_NUT=true)'
        return group
      end

      result = solid_subtract(model, group, tool)
      if result.nil?
        tool.erase! if tool.valid?
        model.abort_operation
        UI.messagebox('Chanfrein écrou : opération booléenne échouée.', MB_OK)
        return group
      end
      model.commit_operation
      result
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

    # Masque les aretes entre faces coplanaires (smooth+soft+hidden).
    # N'efface pas les aretes pour eviter la perte de faces sur certaines geometries (M5, M12).
    def self.cleanup_coplanar_edges(entities)
      entities.grep(Sketchup::Edge).each do |e|
        next unless e.faces.length == 2
        next unless e.faces[0].normal.parallel?(e.faces[1].normal)
        e.smooth = true
        e.soft   = true
        e.hidden = true
      end
    end


    private_class_method :unit_factor, :compute_scale,
                         :make_profile, :make_profile_custom,
                         :build_columns, :apply_chamfer_rod, :apply_chamfer_nut,
                         :solid_subtract, :solid_union, :cleanup_coplanar_edges,
                         :generate_hex_prism, :generate_plain_cylinder,
                         :generate_square_prism, :apply_chamfer_tap_bottom,
                         :apply_tap_color, :format_name_tap,
                         :pad_columns!, :build_verts, :add_center_lines_scaled, :format_name

  end
end
