# test_vis_filets.rb — Script de test interactif vis_filets_generator v1.7.0
#
# Charge dans la console Ruby SketchUp :
#   load 'P:/develop/2026/claude/sketchup-filets/test_vis_filets.rb'

module VFGTest

  LOG_FILE = 'P:/develop/2026/claude/sketchup-filets/TEST_LOG.md'

  # Parametres par defaut — on merge par-dessus pour chaque test
  def self.base(overrides = {})
    {
      'profile_type' => 'iso', 'm_size' => 'M10',
      'd' => 10.0, 'pitch' => 1.5,
      'length_tige' => 50.0, 'length_ecrou' => 8.0,
      'create_tige' => false, 'create_ecrou' => false,
      'gap' => 0.3, 'chamfer' => false, 'chamfer_height' => 1.5,
      'n_theta' => 24, 'max_overhang_angle' => 60.0, 'min_core_pct' => 70.0
    }.merge(overrides)
  end

  TESTS = [

    # ── Dialog (tests manuels) ────────────────────────────────────────────────
    { id: '1.1', manual: true,
      desc: 'Dialog — taille et ordre des cards',
      action: 'Ouvrir le dialog (Extensions → Vis & Filets → Generate…)',
      expected: "Fenêtre ~360×620.\nOrdre : Thread type → Parts to create → Dimensions → Options." },

    { id: '1.2', manual: true,
      desc: 'Dialog — persistence ISO',
      action: 'Sélectionner M8, fermer le dialog, le rouvrir.',
      expected: "M8 mémorisé (D=8, P=1.25)." },

    { id: '1.3', manual: true,
      desc: 'Dialog — switch de mode ISO ↔ FDM',
      action: "1. Passer en FDM, régler angle=50°.\n2. Revenir en ISO.\n3. Repasser en FDM.",
      expected: "Retour ISO : paramètres ISO restaurés.\nRetour FDM : angle=50° restauré." },

    # ── Rod ISO sans chanfrein ────────────────────────────────────────────────
    { id: '2.1',
      desc: 'Rod ISO M10×1.5 L=50 sans chanfrein',
      expected: "Rod solide.\nRayons visibles sur face bas ET haut.\nFaces plates nettes (pas de triangulation).",
      params: base('create_tige' => true, 'd' => 10.0, 'pitch' => 1.5, 'length_tige' => 50.0) },

    { id: '2.2',
      desc: 'Rod ISO M3×0.5 L=10 sans chanfrein',
      expected: "Rod solide. Géométrie correcte en petite taille.",
      params: base('create_tige' => true, 'm_size' => 'M3', 'd' => 3.0, 'pitch' => 0.5, 'length_tige' => 10.0) },

    { id: '2.3',
      desc: 'Rod ISO M20×2.5 L=80 sans chanfrein',
      expected: "Rod solide. Grande taille correcte.",
      params: base('create_tige' => true, 'm_size' => 'M20', 'd' => 20.0, 'pitch' => 2.5, 'length_tige' => 80.0) },

    # ── Rod ISO avec chanfrein ────────────────────────────────────────────────
    { id: '3.1',
      desc: 'Rod ISO M10×1.5 L=50 avec chanfrein=1.5mm',
      expected: "Rod solide.\nChanfrein conique visible en haut.\nRayons toujours présents.",
      params: base('create_tige' => true, 'd' => 10.0, 'pitch' => 1.5, 'length_tige' => 50.0,
                   'chamfer' => true, 'chamfer_height' => 1.5) },

    { id: '3.2',
      desc: 'Rod ISO M5×0.8 L=30 avec chanfrein=0.8mm',
      expected: "Rod solide. Chanfrein visible.",
      params: base('create_tige' => true, 'm_size' => 'M5', 'd' => 5.0, 'pitch' => 0.8,
                   'length_tige' => 30.0, 'chamfer' => true, 'chamfer_height' => 0.8) },

    { id: '3.3',
      desc: 'Rod ISO M3×0.5 L=10 avec chanfrein=0.5mm',
      expected: "Rod solide. Chanfrein visible.",
      params: base('create_tige' => true, 'm_size' => 'M3', 'd' => 3.0, 'pitch' => 0.5,
                   'length_tige' => 10.0, 'chamfer' => true, 'chamfer_height' => 0.5) },

    # ── Nut ISO sans chanfrein ────────────────────────────────────────────────
    { id: '4.1',
      desc: 'Nut ISO M10×1.5 H=8 sans chanfrein',
      expected: "Nut solide.\nFaces hex top/bottom nettes (pas de triangulation visible).",
      params: base('create_ecrou' => true, 'd' => 10.0, 'pitch' => 1.5, 'length_ecrou' => 8.0) },

    { id: '4.2',
      desc: 'Nut ISO M5×0.8 H=10 sans chanfrein  ← régression',
      expected: "Nut solide.\nFaces top/bottom PRÉSENTES (bug précédent : disparaissaient sur M5).",
      params: base('create_ecrou' => true, 'm_size' => 'M5', 'd' => 5.0, 'pitch' => 0.8,
                   'length_ecrou' => 10.0) },

    { id: '4.3',
      desc: 'Nut ISO M12×1.75 H=10 sans chanfrein  ← régression',
      expected: "Nut solide.\nFaces top/bottom PRÉSENTES (bug précédent : disparaissaient sur M12).",
      params: base('create_ecrou' => true, 'm_size' => 'M12', 'd' => 12.0, 'pitch' => 1.75,
                   'length_ecrou' => 10.0) },

    # ── Nut ISO avec chanfrein ────────────────────────────────────────────────
    { id: '5.1',
      desc: 'Nut ISO M10×1.5 H=8 avec chanfrein=1.5mm',
      expected: "Nut solide.\nChanfreins visibles sur les deux faces.\nPas d'erreur booléenne.",
      params: base('create_ecrou' => true, 'd' => 10.0, 'pitch' => 1.5, 'length_ecrou' => 8.0,
                   'chamfer' => true, 'chamfer_height' => 1.5) },

    { id: '5.2',
      desc: 'Nut ISO M5×0.8 H=10 avec chanfrein=0.8mm  ← régression critique',
      expected: "Nut solide.\nChanfreins présents.\nPAS d'erreur \"opération booléenne échouée\".",
      params: base('create_ecrou' => true, 'm_size' => 'M5', 'd' => 5.0, 'pitch' => 0.8,
                   'length_ecrou' => 10.0, 'chamfer' => true, 'chamfer_height' => 0.8) },

    { id: '5.3',
      desc: 'Nut ISO M4×0.7 H=8 avec chanfrein=0.7mm',
      expected: "Nut solide. Chanfreins présents. Pas d'erreur.",
      params: base('create_ecrou' => true, 'm_size' => 'M4', 'd' => 4.0, 'pitch' => 0.7,
                   'length_ecrou' => 8.0, 'chamfer' => true, 'chamfer_height' => 0.7) },

    { id: '5.4',
      desc: 'Nut ISO M6×1.0 H=8 avec chanfrein=1.0mm',
      expected: "Nut solide. Chanfreins présents. Pas d'erreur.",
      params: base('create_ecrou' => true, 'm_size' => 'M6', 'd' => 6.0, 'pitch' => 1.0,
                   'length_ecrou' => 8.0, 'chamfer' => true, 'chamfer_height' => 1.0) },

    { id: '5.5',
      desc: 'Nut ISO M12×1.75 H=10 avec chanfrein=1.75mm',
      expected: "Nut solide. Chanfreins présents. Pas d'erreur.",
      params: base('create_ecrou' => true, 'm_size' => 'M12', 'd' => 12.0, 'pitch' => 1.75,
                   'length_ecrou' => 10.0, 'chamfer' => true, 'chamfer_height' => 1.75) },

    { id: '5.6',
      desc: 'Nut ISO M3×0.5 H=5 avec chanfrein=0.5mm',
      expected: "Nut solide. Chanfreins présents. Pas d'erreur.",
      params: base('create_ecrou' => true, 'm_size' => 'M3', 'd' => 3.0, 'pitch' => 0.5,
                   'length_ecrou' => 5.0, 'chamfer' => true, 'chamfer_height' => 0.5) },

    # ── Rod + Nut simultanés ──────────────────────────────────────────────────
    { id: '6.1',
      desc: 'Rod+Nut M10 sans chanfrein',
      expected: "Rod et nut à l'origine (x=0), superposés. Les deux solides.",
      params: base('create_tige' => true, 'create_ecrou' => true,
                   'd' => 10.0, 'pitch' => 1.5, 'length_tige' => 50.0, 'length_ecrou' => 8.0) },

    { id: '6.2',
      desc: 'Rod+Nut M10 avec chanfrein',
      expected: "Rod et nut chanfreinés. Pas d'erreur. Les deux à x=0.",
      params: base('create_tige' => true, 'create_ecrou' => true,
                   'd' => 10.0, 'pitch' => 1.5, 'length_tige' => 50.0, 'length_ecrou' => 8.0,
                   'chamfer' => true, 'chamfer_height' => 1.5) },

    { id: '6.3',
      desc: 'Rod+Nut M5 avec chanfrein  ← régression critique',
      expected: "Pas d'erreur. Rod et nut M5 chanfreinés correctement.",
      params: base('create_tige' => true, 'create_ecrou' => true,
                   'm_size' => 'M5', 'd' => 5.0, 'pitch' => 0.8,
                   'length_tige' => 30.0, 'length_ecrou' => 10.0,
                   'chamfer' => true, 'chamfer_height' => 0.8) },

    { id: '6.4',
      desc: 'Rod+Nut M5 avec chanfrein × 3 répétitions (test intermittence)',
      expected: "Résultat identique et correct à chaque répétition.",
      repeat: 3,
      params: base('create_tige' => true, 'create_ecrou' => true,
                   'm_size' => 'M5', 'd' => 5.0, 'pitch' => 0.8,
                   'length_tige' => 30.0, 'length_ecrou' => 10.0,
                   'chamfer' => true, 'chamfer_height' => 0.8) },

    # ── Profil FDM plastique ──────────────────────────────────────────────────
    { id: '7.1',
      desc: 'Rod FDM D=10 P=2.5 angle=45° core=70% — fond plat',
      expected: "Rod FDM. Fond de filet plat visible (angle clampé par min_core).",
      params: base('profile_type' => 'plastic', 'create_tige' => true,
                   'd' => 10.0, 'pitch' => 2.5, 'length_tige' => 50.0,
                   'max_overhang_angle' => 45.0, 'min_core_pct' => 70.0) },

    { id: '7.2',
      desc: 'Rod+Nut FDM D=10 P=2.5 angle=45° — angle nut = angle rod',
      expected: "Angle des flancs nut = 45° (identique au rod, pas 60° par défaut).",
      params: base('profile_type' => 'plastic', 'create_tige' => true, 'create_ecrou' => true,
                   'd' => 10.0, 'pitch' => 2.5, 'length_tige' => 50.0, 'length_ecrou' => 8.0,
                   'max_overhang_angle' => 45.0, 'min_core_pct' => 70.0, 'gap' => 0.4) },

    { id: '7.3',
      desc: 'Rod FDM D=10 P=1.0 angle=60° — profil V pur',
      expected: "Rod FDM profil en V pur (pas de fond plat). Profondeur correcte.",
      params: base('profile_type' => 'plastic', 'create_tige' => true,
                   'd' => 10.0, 'pitch' => 1.0, 'length_tige' => 50.0,
                   'max_overhang_angle' => 60.0, 'min_core_pct' => 70.0) },

  ]

  # ── Helpers ────────────────────────────────────────────────────────────────

  def self.clear_model(model)
    grps = model.entities.grep(Sketchup::Group).to_a
    model.entities.erase_entities(grps) unless grps.empty?
  end

  def self.ask(id, desc, expected, rep_label = nil)
    label = rep_label ? "TEST #{id} #{rep_label}" : "TEST #{id}"
    UI.messagebox(
      "#{label}\n#{desc}\n\n" \
      "ATTENDU :\n#{expected}\n\n" \
      "✅ Oui = correct     ❌ Non = anomalie     ⏭ Annuler = passer",
      MB_YESNOCANCEL
    )
  end

  def self.get_anomaly(id)
    inp = UI.inputbox(['Décris l\'anomalie :'], [''], "Anomalie test #{id}")
    inp ? inp[0].strip : '(non précisée)'
  end

  # ── Runner principal ────────────────────────────────────────────────────────

  def self.run
    model  = Sketchup.active_model
    passed = 0; failed = 0; skipped = 0
    log    = [
      "# TEST LOG — vis_filets_generator v1.7.0",
      "Date : #{Time.now.strftime('%Y-%m-%d %H:%M')}",
      "---", ""
    ]

    TESTS.each do |test|
      id       = test[:id]
      desc     = test[:desc]
      expected = test[:expected]

      # ── Test manuel ──────────────────────────────────────────────────────
      if test[:manual]
        UI.messagebox(
          "TEST #{id} (MANUEL)\n#{desc}\n\n" \
          "ACTION :\n#{test[:action]}\n\n" \
          "Effectue l'action puis clique OK pour répondre.",
          MB_OK
        )
        result = ask(id, desc, expected)
        case result
        when IDYES
          log << "✅ #{id} — #{desc}"
          passed += 1
        when IDNO
          log << "❌ #{id} — #{desc}"
          log << "   Anomalie : #{get_anomaly(id)}"
          failed += 1
        else
          log << "⏭  #{id} — Sauté"
          skipped += 1
        end
        next
      end

      # ── Test automatique ─────────────────────────────────────────────────
      reps      = test[:repeat] || 1
      test_ok   = true
      anomaly   = nil
      was_skipped = false

      reps.times do |rep|
        clear_model(model)

        begin
          VisFiletsGenerator::Geometry.generate(test[:params], model)
        rescue => e
          test_ok = false
          anomaly = "EXCEPTION Ruby : #{e.message} (#{e.backtrace.first})"
          break
        end

        model.active_view.zoom_extents
        rep_label = reps > 1 ? "(répétition #{rep + 1}/#{reps})" : nil
        result    = ask(id, desc, expected, rep_label)

        case result
        when IDNO
          test_ok = false
          anomaly = get_anomaly(id)
          break
        when IDCANCEL
          was_skipped = true
          break
        end
      end

      clear_model(model)

      if was_skipped
        log << "⏭  #{id} — Sauté"
        skipped += 1
      elsif test_ok
        log << "✅ #{id} — #{desc}"
        passed += 1
      else
        log << "❌ #{id} — #{desc}"
        log << "   Params   : profile=#{test[:params]['profile_type']} " \
               "d=#{test[:params]['d']} P=#{test[:params]['pitch']} " \
               "chamfer=#{test[:params]['chamfer']} " \
               "rod=#{test[:params]['create_tige']} nut=#{test[:params]['create_ecrou']}"
        log << "   Anomalie : #{anomaly}"
        failed += 1
      end
    end

    # ── Bilan ────────────────────────────────────────────────────────────────
    log += [
      "", "---",
      "## Résumé",
      "- ✅ Passés  : #{passed}",
      "- ❌ Échoués : #{failed}",
      "- ⏭  Sautés  : #{skipped}",
      "- Total   : #{TESTS.length}",
    ]

    File.write(LOG_FILE, log.join("\n"), encoding: 'UTF-8')

    UI.messagebox(
      "Tests terminés !\n\n" \
      "✅ Passés  : #{passed}\n" \
      "❌ Échoués : #{failed}\n" \
      "⏭  Sautés  : #{skipped}\n\n" \
      "Log écrit dans :\n#{LOG_FILE}",
      MB_OK
    )
  end

end

VFGTest.run
