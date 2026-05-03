# test_vis_filets.rb — Script de test interactif vis_filets_generator v1.7.0
# HtmlDialog NON-MODALE : la fenetre reste ouverte pendant que tu inspectes le modele.
#
# Charge dans la console Ruby SketchUp :
#   load 'P:/develop/2026/claude/sketchup-filets/test_vis_filets.rb'

require 'json'

module VFGTest

  LOG_FILE = 'P:/develop/2026/claude/sketchup-filets/TEST_LOG.md'

  HTML = <<~'HTML'
    <!DOCTYPE html><html><head><meta charset="utf-8"><style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:Arial,sans-serif;font-size:13px;background:#f4f4f4;padding:10px}
    .progress{color:#888;font-size:11px;text-align:right;margin-bottom:6px}
    .badge{display:inline-block;padding:2px 8px;border-radius:3px;font-size:11px;
           font-weight:bold;color:white;background:#0066cc;margin-bottom:6px}
    .badge.manual{background:#e65100}
    h2{font-size:14px;color:#222;margin-bottom:8px;line-height:1.3}
    .card{background:white;border:1px solid #ccc;border-radius:4px;padding:8px 10px;margin-bottom:8px}
    .lbl{font-size:10px;font-weight:bold;color:#888;text-transform:uppercase;margin-bottom:3px}
    .txt{color:#222;white-space:pre-wrap;line-height:1.4}
    .action-card{background:#fff8e1;border-color:#f0c000}
    .btns{display:flex;gap:8px;margin-top:10px}
    button{flex:1;padding:9px 4px;border:none;border-radius:4px;cursor:pointer;
           font-size:13px;font-weight:bold;color:white}
    .b-ok  {background:#2e7d32}.b-ok:hover  {background:#1b5e20}
    .b-nok {background:#c62828}.b-nok:hover {background:#b71c1c}
    .b-skip{background:#777}  .b-skip:hover {background:#555}
    .abox{display:none;margin-top:8px}
    .abox textarea{width:100%;height:56px;padding:4px;font-size:12px;
                   border:1px solid #ccc;border-radius:3px;resize:vertical}
    .b-send{width:100%;margin-top:4px;padding:7px;background:#c62828;color:white;
            border:none;border-radius:4px;cursor:pointer;font-weight:bold;font-size:13px}
    .done{text-align:center;padding:20px;color:#2e7d32;font-size:15px;font-weight:bold}
    </style></head><body>
    <div class="progress" id="prog"></div>
    <span class="badge" id="badge"></span>
    <h2 id="desc"></h2>
    <div class="card action-card" id="acard" style="display:none">
      <div class="lbl">Action à effectuer</div>
      <div class="txt" id="action"></div>
    </div>
    <div class="card">
      <div class="lbl">Résultat attendu</div>
      <div class="txt" id="expected"></div>
    </div>
    <div class="btns">
      <button class="b-ok"   onclick="send('pass','')">✅ Correct</button>
      <button class="b-nok"  onclick="showA()">❌ Anomalie</button>
      <button class="b-skip" onclick="send('skip','')">⏭ Passer</button>
    </div>
    <div class="abox" id="abox">
      <textarea id="atxt" placeholder="Décris l'anomalie observée…"></textarea>
      <button class="b-send" onclick="sendA()">Enregistrer l'anomalie →</button>
    </div>
    <script>
    function g(id){return document.getElementById(id)}
    function showA(){g('abox').style.display='block';g('atxt').focus()}
    function sendA(){send('fail', g('atxt').value.trim()||'(non précisée)')}
    function send(r,a){
      g('abox').style.display='none'; g('atxt').value='';
      if(typeof sketchup!=='undefined') sketchup.result(JSON.stringify({r:r,a:a}));
    }
    function update(d){
      g('prog').textContent='Test '+d.idx+' / '+d.total;
      g('badge').textContent=d.id;
      g('badge').className='badge'+(d.manual?' manual':'');
      g('desc').textContent=d.desc;
      g('expected').textContent=d.expected;
      if(d.action){g('acard').style.display='block';g('action').textContent=d.action}
      else g('acard').style.display='none';
    }
    function done(summary){
      document.body.innerHTML='<div class="done">'+summary+'</div>';
    }
    </script></body></html>
  HTML

  # ── Definition des tests ────────────────────────────────────────────────────

  def self.base(ov = {})
    { 'profile_type'=>'iso','m_size'=>'M10','d'=>10.0,'pitch'=>1.5,
      'length_tige'=>50.0,'length_ecrou'=>8.0,
      'create_tige'=>false,'create_ecrou'=>false,
      'gap'=>0.3,'chamfer'=>false,'chamfer_height'=>1.5,
      'n_theta'=>24,'max_overhang_angle'=>60.0,'min_core_pct'=>70.0 }.merge(ov)
  end

  TESTS_DEF = [
    { id:'1.1', manual:true,
      desc:'Dialog — taille et ordre des cards',
      action:"Ouvrir le dialog (Extensions → Vis & Filets → Generate…)",
      expected:"Fenêtre ~360×620.\nOrdre : Thread type → Parts to create → Dimensions → Options." },

    { id:'1.2', manual:true,
      desc:'Dialog — persistence ISO',
      action:"Sélectionner M8, fermer le dialog, le rouvrir.",
      expected:"M8 mémorisé (D=8, P=1.25)." },

    { id:'1.3', manual:true,
      desc:'Dialog — switch ISO ↔ FDM',
      action:"1. Passer en FDM, régler angle=50°.\n2. Revenir en ISO.\n3. Repasser en FDM.",
      expected:"Retour ISO : paramètres ISO restaurés.\nRetour FDM : angle=50° restauré." },

    { id:'2.1', desc:'Rod ISO M10×1.5 L=50 sans chanfrein',
      expected:"Rod solide.\nRayons visibles sur face bas ET haut.\nFaces plates nettes.",
      params: base('create_tige'=>true,'d'=>10.0,'pitch'=>1.5,'length_tige'=>50.0) },

    { id:'2.2', desc:'Rod ISO M3×0.5 L=10 sans chanfrein',
      expected:"Rod solide. Géométrie correcte en petite taille.",
      params: base('create_tige'=>true,'m_size'=>'M3','d'=>3.0,'pitch'=>0.5,'length_tige'=>10.0) },

    { id:'2.3', desc:'Rod ISO M20×2.5 L=80 sans chanfrein',
      expected:"Rod solide. Grande taille correcte.",
      params: base('create_tige'=>true,'m_size'=>'M20','d'=>20.0,'pitch'=>2.5,'length_tige'=>80.0) },

    { id:'3.1', desc:'Rod ISO M10×1.5 L=50 avec chanfrein=1.5mm',
      expected:"Rod solide. Chanfrein conique visible en haut. Rayons présents.",
      params: base('create_tige'=>true,'d'=>10.0,'pitch'=>1.5,'length_tige'=>50.0,
                   'chamfer'=>true,'chamfer_height'=>1.5) },

    { id:'3.2', desc:'Rod ISO M5×0.8 L=30 avec chanfrein=0.8mm',
      expected:"Rod solide. Chanfrein visible.",
      params: base('create_tige'=>true,'m_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'chamfer'=>true,'chamfer_height'=>0.8) },

    { id:'3.3', desc:'Rod ISO M3×0.5 L=10 avec chanfrein=0.5mm',
      expected:"Rod solide. Chanfrein visible.",
      params: base('create_tige'=>true,'m_size'=>'M3','d'=>3.0,'pitch'=>0.5,
                   'length_tige'=>10.0,'chamfer'=>true,'chamfer_height'=>0.5) },

    { id:'4.1', desc:'Nut ISO M10×1.5 H=8 sans chanfrein',
      expected:"Nut solide. Faces hex top/bottom nettes (pas de triangulation visible).",
      params: base('create_ecrou'=>true,'d'=>10.0,'pitch'=>1.5,'length_ecrou'=>8.0) },

    { id:'4.2', desc:'Nut ISO M5×0.8 H=10 sans chanfrein  ← régression',
      expected:"Nut solide.\nFaces top/bottom PRÉSENTES (bug précédent : disparaissaient).",
      params: base('create_ecrou'=>true,'m_size'=>'M5','d'=>5.0,'pitch'=>0.8,'length_ecrou'=>10.0) },

    { id:'4.3', desc:'Nut ISO M12×1.75 H=10 sans chanfrein  ← régression',
      expected:"Nut solide.\nFaces top/bottom PRÉSENTES.",
      params: base('create_ecrou'=>true,'m_size'=>'M12','d'=>12.0,'pitch'=>1.75,'length_ecrou'=>10.0) },

    { id:'5.1', desc:'Nut ISO M10×1.5 H=8 avec chanfrein=1.5mm',
      expected:"Nut solide. Chanfreins sur les deux faces. Pas d'erreur booléenne.",
      params: base('create_ecrou'=>true,'d'=>10.0,'pitch'=>1.5,'length_ecrou'=>8.0,
                   'chamfer'=>true,'chamfer_height'=>1.5) },

    { id:'5.2', desc:'Nut ISO M5×0.8 H=10 avec chanfrein  ← régression critique',
      expected:"Nut solide. Chanfreins présents. PAS d'erreur \"opération booléenne échouée\".",
      params: base('create_ecrou'=>true,'m_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_ecrou'=>10.0,'chamfer'=>true,'chamfer_height'=>0.8) },

    { id:'5.3', desc:'Nut ISO M4×0.7 H=8 avec chanfrein=0.7mm',
      expected:"Nut solide. Chanfreins présents. Pas d'erreur.",
      params: base('create_ecrou'=>true,'m_size'=>'M4','d'=>4.0,'pitch'=>0.7,
                   'length_ecrou'=>8.0,'chamfer'=>true,'chamfer_height'=>0.7) },

    { id:'5.4', desc:'Nut ISO M6×1.0 H=8 avec chanfrein=1.0mm',
      expected:"Nut solide. Chanfreins présents. Pas d'erreur.",
      params: base('create_ecrou'=>true,'m_size'=>'M6','d'=>6.0,'pitch'=>1.0,
                   'length_ecrou'=>8.0,'chamfer'=>true,'chamfer_height'=>1.0) },

    { id:'5.5', desc:'Nut ISO M12×1.75 H=10 avec chanfrein=1.75mm',
      expected:"Nut solide. Chanfreins présents. Pas d'erreur.",
      params: base('create_ecrou'=>true,'m_size'=>'M12','d'=>12.0,'pitch'=>1.75,
                   'length_ecrou'=>10.0,'chamfer'=>true,'chamfer_height'=>1.75) },

    { id:'5.6', desc:'Nut ISO M3×0.5 H=5 avec chanfrein=0.5mm',
      expected:"Nut solide. Chanfreins présents. Pas d'erreur.",
      params: base('create_ecrou'=>true,'m_size'=>'M3','d'=>3.0,'pitch'=>0.5,
                   'length_ecrou'=>5.0,'chamfer'=>true,'chamfer_height'=>0.5) },

    { id:'6.1', desc:'Rod+Nut M10 sans chanfrein',
      expected:"Rod et nut à l'origine (x=0), superposés. Les deux solides.",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'd'=>10.0,'pitch'=>1.5,'length_tige'=>50.0,'length_ecrou'=>8.0) },

    { id:'6.2', desc:'Rod+Nut M10 avec chanfrein',
      expected:"Rod et nut chanfreinés. Pas d'erreur. Les deux à x=0.",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'd'=>10.0,'pitch'=>1.5,'length_tige'=>50.0,'length_ecrou'=>8.0,
                   'chamfer'=>true,'chamfer_height'=>1.5) },

    { id:'6.3', desc:'Rod+Nut M5 avec chanfrein  ← régression critique',
      expected:"Pas d'erreur. Rod et nut M5 chanfreinés correctement.",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'm_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'length_ecrou'=>10.0,
                   'chamfer'=>true,'chamfer_height'=>0.8) },

    # Test 6.4 : 3 repetitions → expanse en 3 entrees
    { id:'6.4a', desc:'Rod+Nut M5 chanfrein — répétition 1/3 (test intermittence)',
      expected:"Résultat correct (pas d'erreur booléenne).",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'm_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'length_ecrou'=>10.0,
                   'chamfer'=>true,'chamfer_height'=>0.8) },

    { id:'6.4b', desc:'Rod+Nut M5 chanfrein — répétition 2/3',
      expected:"Résultat identique à 6.4a (pas d'intermittence).",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'm_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'length_ecrou'=>10.0,
                   'chamfer'=>true,'chamfer_height'=>0.8) },

    { id:'6.4c', desc:'Rod+Nut M5 chanfrein — répétition 3/3',
      expected:"Résultat identique. Pas d'intermittence sur 3 essais.",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'm_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'length_ecrou'=>10.0,
                   'chamfer'=>true,'chamfer_height'=>0.8) },

    { id:'7.1', desc:'Rod FDM D=10 P=2.5 angle=45° — fond plat',
      expected:"Rod FDM. Fond de filet plat visible (angle clampé par min_core).",
      params: base('profile_type'=>'plastic','create_tige'=>true,
                   'd'=>10.0,'pitch'=>2.5,'length_tige'=>50.0,
                   'max_overhang_angle'=>45.0,'min_core_pct'=>70.0) },

    { id:'7.2', desc:'Rod+Nut FDM D=10 P=2.5 angle=45° — angle nut = rod',
      expected:"Angle des flancs nut = 45° identique au rod. Pas de fond plat parasite.",
      params: base('profile_type'=>'plastic','create_tige'=>true,'create_ecrou'=>true,
                   'd'=>10.0,'pitch'=>2.5,'length_tige'=>50.0,'length_ecrou'=>8.0,
                   'max_overhang_angle'=>45.0,'min_core_pct'=>70.0,'gap'=>0.4) },

    { id:'7.3', desc:'Rod FDM D=10 P=1.0 angle=60° — profil V pur',
      expected:"Rod FDM profil en V pur (pas de fond plat). Profondeur correcte.",
      params: base('profile_type'=>'plastic','create_tige'=>true,
                   'd'=>10.0,'pitch'=>1.0,'length_tige'=>50.0,
                   'max_overhang_angle'=>60.0,'min_core_pct'=>70.0) },
  ]

  # ── Helpers ─────────────────────────────────────────────────────────────────

  def self.clear_model(model)
    grps = model.entities.grep(Sketchup::Group).to_a
    model.entities.erase_entities(grps) unless grps.empty?
  end

  def self.generate_test(test, model)
    return if test[:manual]
    clear_model(model)
    begin
      VisFiletsGenerator::Geometry.generate(test[:params], model)
      model.active_view.zoom_extents
    rescue => e
      puts "[VFGTest] EXCEPTION sur #{test[:id]} : #{e.message}"
    end
  end

  def self.ui_data(test, idx, total)
    { id: test[:id], idx: idx, total: total,
      desc: test[:desc], expected: test[:expected],
      manual: test[:manual] || false,
      action: test[:action] || nil }
  end

  # ── Runner principal ─────────────────────────────────────────────────────────

  def self.run
    model   = Sketchup.active_model
    tests   = TESTS_DEF
    total   = tests.length
    idx     = 0
    log     = ["# TEST LOG — vis_filets_generator v1.7.0",
               "Date : #{Time.now.strftime('%Y-%m-%d %H:%M')}", "---", ""]
    passed  = 0; failed = 0; skipped = 0

    dlg = UI::HtmlDialog.new(
      dialog_title:    'VFG — Tests',
      preferences_key: 'VFGTestDialog',
      width: 380, height: 480,
      min_width: 300, min_height: 300,
      style: UI::HtmlDialog::STYLE_DIALOG
    )
    dlg.set_html(HTML)

    advance = lambda do
      if idx >= total
        clear_model(model)
        log += ["", "---", "## Résumé",
                "- ✅ Passés  : #{passed}",
                "- ❌ Échoués : #{failed}",
                "- ⏭  Sautés  : #{skipped}",
                "- Total   : #{total}"]
        File.write(LOG_FILE, log.join("\n"), encoding: 'UTF-8')
        dlg.execute_script("done('✅ #{passed} passés &nbsp; ❌ #{failed} échoués &nbsp; ⏭ #{skipped} sautés<br><br>Log : #{LOG_FILE.gsub('/','\\\\')}')") rescue nil
        puts "[VFGTest] Terminé. Log : #{LOG_FILE}"
        return
      end
      test = tests[idx]
      generate_test(test, model)
      dlg.execute_script("update(#{ui_data(test, idx + 1, total).to_json})")
    end

    dlg.add_action_callback('result') do |_, json|
      data = JSON.parse(json)
      test = tests[idx]
      case data['r']
      when 'pass'
        log << "✅ #{test[:id]} — #{test[:desc]}"
        passed += 1
      when 'fail'
        anomaly = data['a']
        log << "❌ #{test[:id]} — #{test[:desc]}"
        log << "   Anomalie : #{anomaly}"
        if test[:params]
          p = test[:params]
          log << "   Params   : profile=#{p['profile_type']} d=#{p['d']} P=#{p['pitch']}" \
                 " chamfer=#{p['chamfer']} rod=#{p['create_tige']} nut=#{p['create_ecrou']}"
        end
        failed += 1
      when 'skip'
        log << "⏭  #{test[:id]} — Sauté"
        skipped += 1
      end
      idx += 1
      advance.call
    end

    dlg.show
    advance.call   # charge le premier test
  end

end

VFGTest.run
