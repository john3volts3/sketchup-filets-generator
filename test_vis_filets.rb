# test_vis_filets.rb — Script de test interactif vis_filets_generator v1.9.1
# HtmlDialog NON-MODALE : la fenetre reste ouverte pendant que tu inspectes le modele.
#
# Charge dans la console Ruby SketchUp :
#   load 'P:/develop/2026/claude/sketchup-filets/test_vis_filets.rb'

require 'json'

module VFGTest

  LOG_FILE = 'P:/develop/2026/claude/sketchup-filets/TEST_LOG.md'

  HTML = <<'HTML'
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
      <div class="lbl">Action to perform</div>
      <div class="txt" id="action"></div>
    </div>
    <div class="card">
      <div class="lbl">Expected result</div>
      <div class="txt" id="expected"></div>
    </div>
    <div class="btns">
      <button class="b-ok"   onclick="send('pass','')">&#x2705; Pass</button>
      <button class="b-nok"  onclick="showA()">&#x274C; Anomaly</button>
      <button class="b-skip" onclick="send('skip','')">&#x23ED; Skip</button>
    </div>
    <div class="abox" id="abox">
      <textarea id="atxt" placeholder="Describe the anomaly observed..."></textarea>
      <button class="b-send" onclick="sendA()">Save anomaly &#x2192;</button>
    </div>
    <script>
    function g(id){return document.getElementById(id)}
    function showA(){g('abox').style.display='block';g('atxt').focus()}
    function sendA(){send('fail', g('atxt').value.trim()||'(not specified)')}
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
    window.onload=function(){
      if(typeof sketchup!=='undefined') sketchup.ready();
    }
    </script></body></html>
HTML

  # ── Default params ───────────────────────────────────────────────────────────

  def self.base(ov = {})
    { 'profile_type'     => 'iso',
      'm_size'           => 'M10',
      'd'                => 10.0,
      'pitch'            => 1.5,
      'length_tige'      => 50.0,
      'length_ecrou'     => 8.0,
      'length_taraud'    => 20.0,
      'create_tige'      => false,
      'create_ecrou'     => false,
      'create_taraud'    => false,
      'gap'              => 0.3,
      'chamfer'          => false,
      'chamfer_height'   => 1.5,
      'n_theta'          => 24,
      'max_overhang_angle' => 60.0,
      'min_core_pct'     => 70.0,
      'tap_color'        => ''
    }.merge(ov)
  end

  # ── Test definitions ─────────────────────────────────────────────────────────

  TESTS_DEF = [

    # ── 1. Dialog / UI (manual) ────────────────────────────────────────────────

    { id:'1.1', manual:true,
      desc:'Dialog — size and card order',
      action:"Open the dialog (Extensions → Vis & Filets → Generate…)",
      expected:"Window opens.\nOrder: Thread type → Parts to create → Dimensions → Options.\nButton reads 'Generate' (English)." },

    { id:'1.2', manual:true,
      desc:'Dialog — ISO persistence',
      action:"Select M8, close the dialog, reopen it.",
      expected:"M8 remembered (D=8, P=1.25)." },

    { id:'1.3', manual:true,
      desc:'Dialog — ISO ↔ FDM switch',
      action:"1. Switch to FDM, set angle=50°.\n2. Switch back to ISO.\n3. Switch to FDM again.",
      expected:"Back to ISO: ISO params restored.\nBack to FDM: angle=50° restored." },

    { id:'1.4', manual:true,
      desc:'Dialog — Parts to create layout',
      action:"Look at the 'Parts to create' card.",
      expected:"Each row: checkbox + label (fixed width) + 'height' + input field aligned.\n" \
               "Threaded rod / Hex nut / Tap all on one line each.\n" \
               "Height fields aligned vertically." },

    { id:'1.5', manual:true,
      desc:'Dialog — Gap enabled only for Nut/Tap',
      action:"1. Check only Threaded rod → check Gap state.\n" \
             "2. Check Hex nut → check Gap state.\n" \
             "3. Uncheck Hex nut, check Tap → check Gap state.",
      expected:"Gap greyed (disabled) when neither Nut nor Tap is checked.\n" \
               "Gap enabled as soon as Nut OR Tap is checked." },

    { id:'1.6', manual:true,
      desc:'Toolbar — button and icon visible',
      action:"Check the Vis & Filets toolbar in SketchUp.",
      expected:"Toolbar visible with the thread symbol icon (Y + alternating teeth).\n" \
               "Tooltip: 'Vis & Filets — Generate thread parts'.\n" \
               "Click opens the dialog." },

    # ── 2. Threaded rod ISO ───────────────────────────────────────────────────

    { id:'2.1', desc:'Rod ISO M10×1.5 L=50 no chamfer',
      expected:"Rod solid. Center lines visible on top and bottom faces.\nGroup name: 'Rod M10x1.5 L50 ISO'.",
      params: base('create_tige'=>true,'d'=>10.0,'pitch'=>1.5,'length_tige'=>50.0) },

    { id:'2.2', desc:'Rod ISO M3×0.5 L=10 no chamfer — small size',
      expected:"Rod solid. Correct geometry at small size (scale trick active).",
      params: base('create_tige'=>true,'m_size'=>'M3','d'=>3.0,'pitch'=>0.5,'length_tige'=>10.0) },

    { id:'2.3', desc:'Rod ISO M20×2.5 L=80 no chamfer — large size',
      expected:"Rod solid. Correct geometry at large size.",
      params: base('create_tige'=>true,'m_size'=>'M20','d'=>20.0,'pitch'=>2.5,'length_tige'=>80.0) },

    { id:'2.4', desc:'Rod ISO M32×3.5 L=60 no chamfer — max size',
      expected:"Rod solid. No error at M32.",
      params: base('create_tige'=>true,'m_size'=>'M32','d'=>32.0,'pitch'=>3.5,'length_tige'=>60.0) },

    # ── 3. Rod with chamfer ───────────────────────────────────────────────────

    { id:'3.1', desc:'Rod ISO M10×1.5 L=50 with chamfer=1.5mm',
      expected:"Rod solid. Conical chamfer visible at top. Center lines present.",
      params: base('create_tige'=>true,'d'=>10.0,'pitch'=>1.5,'length_tige'=>50.0,
                   'chamfer'=>true,'chamfer_height'=>1.5) },

    { id:'3.2', desc:'Rod ISO M5×0.8 L=30 with chamfer=0.8mm',
      expected:"Rod solid. Chamfer visible. No boolean error.",
      params: base('create_tige'=>true,'m_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'chamfer'=>true,'chamfer_height'=>0.8) },

    { id:'3.3', desc:'Rod ISO M3×0.5 L=10 with chamfer=0.5mm',
      expected:"Rod solid. Chamfer visible.",
      params: base('create_tige'=>true,'m_size'=>'M3','d'=>3.0,'pitch'=>0.5,
                   'length_tige'=>10.0,'chamfer'=>true,'chamfer_height'=>0.5) },

    # ── 4. Hex nut ISO ────────────────────────────────────────────────────────

    { id:'4.1', desc:'Nut ISO M10×1.5 H=8 no chamfer',
      expected:"Nut solid. Hex top/bottom faces clean (no triangulation visible).\nGroup name: 'Nut M10x1.5 L8 ISO'.",
      params: base('create_ecrou'=>true,'d'=>10.0,'pitch'=>1.5,'length_ecrou'=>8.0) },

    { id:'4.2', desc:'Nut ISO M5×0.8 H=10 no chamfer — regression',
      expected:"Nut solid. Top/bottom faces PRESENT (previous bug: disappeared).",
      params: base('create_ecrou'=>true,'m_size'=>'M5','d'=>5.0,'pitch'=>0.8,'length_ecrou'=>10.0) },

    { id:'4.3', desc:'Nut ISO M12×1.75 H=10 no chamfer — regression',
      expected:"Nut solid. Top/bottom faces PRESENT.",
      params: base('create_ecrou'=>true,'m_size'=>'M12','d'=>12.0,'pitch'=>1.75,'length_ecrou'=>10.0) },

    { id:'4.4', desc:'Nut ISO M3×0.5 H=5 no chamfer — small size',
      expected:"Nut solid. No error at M3.",
      params: base('create_ecrou'=>true,'m_size'=>'M3','d'=>3.0,'pitch'=>0.5,'length_ecrou'=>5.0) },

    # ── 5. Nut with chamfer ───────────────────────────────────────────────────

    { id:'5.1', desc:'Nut ISO M10×1.5 H=8 with chamfer=1.5mm',
      expected:"Nut solid. Chamfers on BOTH faces. No boolean error.",
      params: base('create_ecrou'=>true,'d'=>10.0,'pitch'=>1.5,'length_ecrou'=>8.0,
                   'chamfer'=>true,'chamfer_height'=>1.5) },

    { id:'5.2', desc:'Nut ISO M5×0.8 H=10 with chamfer — critical regression',
      expected:"Nut solid. Chamfers present. NO 'boolean operation failed' error.",
      params: base('create_ecrou'=>true,'m_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_ecrou'=>10.0,'chamfer'=>true,'chamfer_height'=>0.8) },

    { id:'5.3', desc:'Nut ISO M4×0.7 H=8 with chamfer=0.7mm',
      expected:"Nut solid. Chamfers present. No error.",
      params: base('create_ecrou'=>true,'m_size'=>'M4','d'=>4.0,'pitch'=>0.7,
                   'length_ecrou'=>8.0,'chamfer'=>true,'chamfer_height'=>0.7) },

    { id:'5.4', desc:'Nut ISO M3×0.5 H=5 with chamfer=0.5mm',
      expected:"Nut solid. Chamfers present. No error.",
      params: base('create_ecrou'=>true,'m_size'=>'M3','d'=>3.0,'pitch'=>0.5,
                   'length_ecrou'=>5.0,'chamfer'=>true,'chamfer_height'=>0.5) },

    # ── 6. Rod + Nut combined ─────────────────────────────────────────────────

    { id:'6.1', desc:'Rod + Nut M10 no chamfer',
      expected:"Rod and Nut both at origin (x=0). Both solids. No error.",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'd'=>10.0,'pitch'=>1.5,'length_tige'=>50.0,'length_ecrou'=>8.0) },

    { id:'6.2', desc:'Rod + Nut M10 with chamfer',
      expected:"Both chamfered. No error. Both at x=0.",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'd'=>10.0,'pitch'=>1.5,'length_tige'=>50.0,'length_ecrou'=>8.0,
                   'chamfer'=>true,'chamfer_height'=>1.5) },

    { id:'6.3', desc:'Rod + Nut M5 with chamfer — critical regression',
      expected:"No error. Rod and Nut M5 both chamfered correctly.",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'm_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'length_ecrou'=>10.0,
                   'chamfer'=>true,'chamfer_height'=>0.8) },

    { id:'6.4a', desc:'Rod + Nut M5 chamfer — repeat 1/3 (intermittency check)',
      expected:"Correct result (no boolean error).",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'm_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'length_ecrou'=>10.0,
                   'chamfer'=>true,'chamfer_height'=>0.8) },

    { id:'6.4b', desc:'Rod + Nut M5 chamfer — repeat 2/3',
      expected:"Same result as 6.4a (no intermittency).",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'm_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'length_ecrou'=>10.0,
                   'chamfer'=>true,'chamfer_height'=>0.8) },

    { id:'6.4c', desc:'Rod + Nut M5 chamfer — repeat 3/3',
      expected:"Same result. No intermittency over 3 runs.",
      params: base('create_tige'=>true,'create_ecrou'=>true,
                   'm_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'length_ecrou'=>10.0,
                   'chamfer'=>true,'chamfer_height'=>0.8) },

    # ── 7. FDM plastic profile ────────────────────────────────────────────────

    { id:'7.1', desc:'Rod FDM D=10 P=2.5 angle=45° — flat root',
      expected:"FDM rod. Flat thread root visible (clamped by min_core).",
      params: base('profile_type'=>'plastic','create_tige'=>true,
                   'd'=>10.0,'pitch'=>2.5,'length_tige'=>50.0,
                   'max_overhang_angle'=>45.0,'min_core_pct'=>70.0) },

    { id:'7.2', desc:'Rod + Nut FDM D=10 angle=45° — nut flank = rod flank',
      expected:"Nut flank angle = 45° same as rod. No parasitic flat root.",
      params: base('profile_type'=>'plastic','create_tige'=>true,'create_ecrou'=>true,
                   'd'=>10.0,'pitch'=>2.5,'length_tige'=>50.0,'length_ecrou'=>8.0,
                   'max_overhang_angle'=>45.0,'min_core_pct'=>70.0,'gap'=>0.4) },

    { id:'7.3', desc:'Rod FDM D=10 P=1.0 angle=60° — pure V profile',
      expected:"FDM rod, pure V profile (no flat root). Correct depth.",
      params: base('profile_type'=>'plastic','create_tige'=>true,
                   'd'=>10.0,'pitch'=>1.0,'length_tige'=>50.0,
                   'max_overhang_angle'=>60.0,'min_core_pct'=>70.0) },

    # ── 8. Tap ISO ────────────────────────────────────────────────────────────

    { id:'8.1', desc:'Tap ISO M10×1.5 L=20 no chamfer',
      expected:"Tap solid (union: bore rod + shank + square).\n" \
               "45° entry cone at bottom (pointed tip).\n" \
               "Shank cylinder Ø < thread minor diameter.\n" \
               "Square inscribed in shank cylinder.\n" \
               "Group name: 'Tap M10x1.5 L20 ISO'.",
      params: base('create_taraud'=>true,'d'=>10.0,'pitch'=>1.5,'length_taraud'=>20.0) },

    { id:'8.2', desc:'Tap ISO M5×0.8 L=15 no chamfer — small size',
      expected:"Tap solid. Entry cone visible. Correct proportions for M5.",
      params: base('create_taraud'=>true,'m_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_taraud'=>15.0) },

    { id:'8.3', desc:'Tap ISO M3×0.5 L=10 no chamfer — smallest size',
      expected:"Tap solid. No error at M3 (scale trick active).",
      params: base('create_taraud'=>true,'m_size'=>'M3','d'=>3.0,'pitch'=>0.5,
                   'length_taraud'=>10.0) },

    { id:'8.4', desc:'Tap ISO M12×1.75 L=25 no chamfer',
      expected:"Tap solid. Square correctly inscribed in shank cylinder.",
      params: base('create_taraud'=>true,'m_size'=>'M12','d'=>12.0,'pitch'=>1.75,
                   'length_taraud'=>25.0) },

    { id:'8.5', desc:'Tap ISO M20×2.5 L=30 no chamfer — large size',
      expected:"Tap solid. No error at M20.",
      params: base('create_taraud'=>true,'m_size'=>'M20','d'=>20.0,'pitch'=>2.5,
                   'length_taraud'=>30.0) },

    { id:'8.6', desc:'Tap ISO M10 L=20 — thread length compensation',
      expected:"Effective threaded length ≈ 20mm (cone does NOT shorten usable thread).\n" \
               "Bore rod is longer than 20mm internally to compensate.",
      params: base('create_taraud'=>true,'d'=>10.0,'pitch'=>1.5,'length_taraud'=>20.0) },

    # ── 9. Tap with chamfer ───────────────────────────────────────────────────

    { id:'9.1', desc:'Tap ISO M10×1.5 L=20 with thread lead-in chamfer',
      expected:"Tap solid with rod chamfer applied.\nEntry cone + chamfer both visible.",
      params: base('create_taraud'=>true,'d'=>10.0,'pitch'=>1.5,'length_taraud'=>20.0,
                   'chamfer'=>true,'chamfer_height'=>1.5) },

    { id:'9.2', desc:'Tap ISO M5×0.8 L=15 with chamfer — regression',
      expected:"Tap solid. No boolean error. Chamfer visible.",
      params: base('create_taraud'=>true,'m_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_taraud'=>15.0,'chamfer'=>true,'chamfer_height'=>0.8) },

    # ── 10. Tap FDM ───────────────────────────────────────────────────────────

    { id:'10.1', desc:'Tap FDM D=10 P=2.5 L=20 angle=60°',
      expected:"Tap FDM solid. FDM thread profile (angle-limited V) on bore rod section.",
      params: base('profile_type'=>'plastic','create_taraud'=>true,
                   'd'=>10.0,'pitch'=>2.5,'length_taraud'=>20.0,
                   'max_overhang_angle'=>60.0,'min_core_pct'=>70.0,'gap'=>0.4) },

    # ── 11. Combined parts ────────────────────────────────────────────────────

    { id:'11.1', desc:'Rod + Nut + Tap M10 all together',
      expected:"3 solids generated. All at origin (x=0). No error.\n" \
               "Groups: 'Rod M10x1.5 L50 ISO', 'Nut M10x1.5 L8 ISO', 'Tap M10x1.5 L20 ISO'.",
      params: base('create_tige'=>true,'create_ecrou'=>true,'create_taraud'=>true,
                   'd'=>10.0,'pitch'=>1.5,
                   'length_tige'=>50.0,'length_ecrou'=>8.0,'length_taraud'=>20.0) },

    { id:'11.2', desc:'Rod + Tap M10 with chamfer',
      expected:"Rod and Tap both solid and chamfered. No error.",
      params: base('create_tige'=>true,'create_taraud'=>true,
                   'd'=>10.0,'pitch'=>1.5,'length_tige'=>50.0,'length_taraud'=>20.0,
                   'chamfer'=>true,'chamfer_height'=>1.5) },

    { id:'11.3', desc:'Nut + Tap M10 no chamfer',
      expected:"Nut and Tap both solid at origin. No error.",
      params: base('create_ecrou'=>true,'create_taraud'=>true,
                   'd'=>10.0,'pitch'=>1.5,'length_ecrou'=>8.0,'length_taraud'=>20.0) },

    { id:'11.4', desc:'Rod + Nut + Tap M5 with chamfer — full stress test',
      expected:"All 3 solids correct for M5. No boolean error on any of them.",
      params: base('create_tige'=>true,'create_ecrou'=>true,'create_taraud'=>true,
                   'm_size'=>'M5','d'=>5.0,'pitch'=>0.8,
                   'length_tige'=>30.0,'length_ecrou'=>10.0,'length_taraud'=>15.0,
                   'chamfer'=>true,'chamfer_height'=>0.8) },

    # ── 12. UI / English / Behavior (manual) ──────────────────────────────────

    { id:'12.1', manual:true,
      desc:'UI — All text in English',
      action:"Open the dialog. Read all labels, button, title.",
      expected:"Title: 'Vis & Filets — Generator'\n" \
               "Button: 'Generate'\n" \
               "All labels in English (no French terms visible)." },

    { id:'12.2', manual:true,
      desc:'UI — Group names in English',
      action:"Generate Rod + Nut + Tap M10. Check group names in Outliner.",
      expected:"Groups named:\n" \
               "  'Rod M10x1.5 L50 ISO'\n" \
               "  'Nut M10x1.5 L8 ISO'\n" \
               "  'Tap M10x1.5 L20 ISO'" },

    { id:'12.3', manual:true,
      desc:'Status bar — progress messages during generation',
      action:"Generate Rod + Nut + Tap M10 and watch the status bar (bottom-left of SketchUp).",
      expected:"Status bar shows each step:\n" \
               "  'Vis & Filets — Threaded rod: building columns…'\n" \
               "  'Vis & Filets — Hex nut: hex prism…'\n" \
               "  'Vis & Filets — Tap: bore rod…' etc.\n" \
               "Cleared (empty) when generation completes." },

    { id:'12.4', manual:true,
      desc:'Tap color — from selected object',
      action:"1. Create a colored solid (any color).\n" \
             "2. Select it.\n" \
             "3. Generate a Tap.\n" \
             "4. Check tap color in Entity Info.",
      expected:"Tap inherits the selected object's material color.\n" \
               "If nothing selected (or no material): tap has no color (SketchUp default)." },

    { id:'12.5', manual:true,
      desc:'Gap — immediate save without Generate',
      action:"1. Open dialog. Check Hex nut.\n" \
             "2. Set Gap = 0.15.\n" \
             "3. Close dialog WITHOUT clicking Generate.\n" \
             "4. Reopen dialog.",
      expected:"Gap = 0.15 is remembered (immediate save on change)." },

    { id:'12.6', manual:true,
      desc:'Undo — operation names in English',
      action:"Generate any part, then check Edit > Undo.",
      expected:"Undo history shows English operation names:\n" \
               "'Thread Generator', 'Nut boolean', 'Rod chamfer', 'Nut chamfer', etc.\n" \
               "No French names in undo history." },

  ]

  # ── Helpers ──────────────────────────────────────────────────────────────────

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
      puts "[VFGTest] EXCEPTION on #{test[:id]}: #{e.message}"
    end
  end

  def self.ui_data(test, idx, total)
    { id: test[:id], idx: idx, total: total,
      desc: test[:desc], expected: test[:expected],
      manual: test[:manual] || false,
      action: test[:action] || nil }
  end

  # ── Runner ───────────────────────────────────────────────────────────────────

  def self.run
    model   = Sketchup.active_model
    tests   = TESTS_DEF
    total   = tests.length
    idx     = 0
    log     = ["# TEST LOG — vis_filets_generator v1.9.1",
               "Date: #{Time.now.strftime('%Y-%m-%d %H:%M')}", "---", ""]
    passed  = 0; failed = 0; skipped = 0

    dlg = UI::HtmlDialog.new(
      dialog_title:    'VFG — Tests v1.9.1',
      preferences_key: 'VFGTestDialog',
      width: 400, height: 520,
      min_width: 300, min_height: 300,
      style: UI::HtmlDialog::STYLE_DIALOG
    )
    dlg.set_html(HTML)

    advance = lambda do
      if idx >= total
        clear_model(model)
        log += ["", "---", "## Summary",
                "- ✅ Passed  : #{passed}",
                "- ❌ Failed  : #{failed}",
                "- ⏭  Skipped : #{skipped}",
                "- Total    : #{total}"]
        File.write(LOG_FILE, log.join("\n"), encoding: 'UTF-8')
        dlg.execute_script("done('&#x2705; #{passed} passed &nbsp; &#x274C; #{failed} failed &nbsp; &#x23ED; #{skipped} skipped<br><br>Log: #{LOG_FILE.gsub('/','\\\\')}')") rescue nil
        puts "[VFGTest] Done. Log: #{LOG_FILE}"
        return
      end
      test = tests[idx]
      generate_test(test, model)
      dlg.execute_script("update(#{ui_data(test, idx + 1, total).to_json})")
    end

    dlg.add_action_callback('ready') { |_,_| advance.call }

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
        log << "   Anomaly: #{anomaly}"
        if test[:params]
          p = test[:params]
          log << "   Params : profile=#{p['profile_type']} d=#{p['d']} P=#{p['pitch']}" \
                 " chamfer=#{p['chamfer']} rod=#{p['create_tige']}" \
                 " nut=#{p['create_ecrou']} tap=#{p['create_taraud']}"
        end
        failed += 1
      when 'skip'
        log << "⏭  #{test[:id]} — Skipped"
        skipped += 1
      end
      idx += 1
      advance.call
    end

    dlg.show
    # advance.call est déclenché par sketchup.ready() depuis window.onload
  end

end

VFGTest.run
