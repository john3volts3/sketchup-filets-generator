# vis_filets_generator/dialog.rb
# Interface utilisateur WebDialog (SU 2014+) avec upgrade HtmlDialog si SU 2017+
# Parametres persistes entre sessions via Sketchup.write_default / read_default

require 'json'
require 'cgi'

module VisFiletsGenerator
  module DialogManager

    DIALOG_TITLE = 'Vis & Filets — Generator'.freeze
    PREF_KEY     = 'VisFiletsGenerator'.freeze

    HTML_TEMPLATE = <<~'HTML'
      <!DOCTYPE html>
      <html>
      <head>
      <meta charset="utf-8">
      <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{font-family:Arial,sans-serif;font-size:12px;background:#e8e8e8;padding:8px}
        .card{background:#fff;border:1px solid #bbb;border-radius:3px;padding:8px 10px;margin-bottom:7px}
        h3{font-size:11px;font-weight:bold;color:#444;text-transform:uppercase;letter-spacing:.5px;
           border-bottom:1px solid #e0e0e0;padding-bottom:4px;margin-bottom:6px}
        .row{display:flex;align-items:center;margin:4px 0}
        .lbl{width:130px;color:#333;flex-shrink:0}
        select,input[type=text]{border:1px solid #bbb;border-radius:2px;padding:2px 4px;
          background:#fafafa;font-size:12px}
        select{width:130px}
        input[type=text]{width:80px}
        .check-row{margin:4px 0}
        .lbl-i{color:#666;font-size:11px;margin:0 3px}
        .color-swatch{width:44px;height:22px;border:1px solid #bbb;border-radius:2px;
          cursor:pointer;display:inline-block;vertical-align:middle}
        .color-none{background:repeating-linear-gradient(45deg,#ddd,#ddd 3px,#fff 3px,#fff 7px)}
        .clr-btn{cursor:pointer;color:#999;font-size:13px;margin-left:4px;
          line-height:1;vertical-align:middle;user-select:none}
        .clr-btn:hover{color:#c00}
        .hint{color:#777;font-size:10px;margin-top:3px;font-style:italic}
        .adj{color:#2a7;font-size:10px;margin-left:4px}
        #btn{width:100%;padding:7px;background:#0066cc;color:#fff;border:none;
             border-radius:3px;cursor:pointer;font-size:13px;font-weight:bold;margin-top:2px}
        #btn:hover{background:#0052a3}
        .err{color:#c00;font-size:11px;margin-top:4px;min-height:14px}
        .radio-row{margin:4px 0}
        .sub-row{margin:2px 0 2px 16px}
        .dim{opacity:0.38;pointer-events:none}
      </style>
      </head>
      <body>

      <div class="card">
        <h3>Thread type</h3>
        <div class="radio-row">
          <label><input type="radio" name="profile_type" value="iso" checked onclick="onProfileChange()"> ISO metric</label>
          &nbsp;&nbsp;&nbsp;
          <label><input type="radio" name="profile_type" value="plastic" onclick="onProfileChange()"> FDM plastic optimised</label>
        </div>
      </div>

      <div class="card">
        <h3>Parts to create</h3>
        <div class="check-row" style="display:flex;align-items:center">
          <label style="width:110px;flex-shrink:0"><input type="checkbox" id="create_tige" checked onchange="onCreateChange()"> Threaded rod</label>
          <span id="row_length_tige" style="display:flex;align-items:center">
            <span class="lbl-i">height</span><input type="text" id="length_tige" value="50" min="0.1" step="1">
          </span>
        </div>
        <div class="check-row" style="display:flex;align-items:center;margin-top:5px">
          <label style="width:110px;flex-shrink:0"><input type="checkbox" id="create_ecrou" onchange="onCreateChange()"> Hex nut</label>
          <span id="row_length_ecrou" class="dim" style="display:flex;align-items:center">
            <span class="lbl-i">height</span><input type="text" id="length_ecrou" value="8" min="0.1" step="1" onchange="updateNutHeightHint()"><span class="adj" id="nut_height_hint">&nbsp;</span>
          </span>
        </div>
        <div class="check-row" style="display:flex;align-items:center;margin-top:5px">
          <label style="width:110px;flex-shrink:0"><input type="checkbox" id="create_taraud" onchange="onCreateChange()"> Tap</label>
          <span id="row_length_taraud" class="dim" style="display:flex;align-items:center">
            <span class="lbl-i">height</span><input type="text" id="length_taraud" value="20" min="0.1" step="1">
          </span>
        </div>
      </div>

      <div class="card">
        <h3>Dimensions</h3>
        <div class="row" id="iso_preset_row">
          <div class="lbl">M size</div>
          <select id="m_size" onchange="onMSize()">
            <option value="M3">M3</option><option value="M4">M4</option>
            <option value="M5">M5</option><option value="M6">M6</option>
            <option value="M8">M8</option><option value="M10" selected>M10</option>
            <option value="M12">M12</option><option value="M16">M16</option>
            <option value="M20">M20</option><option value="M22">M22</option>
            <option value="M24">M24</option><option value="M27">M27</option>
            <option value="M30">M30</option><option value="M32">M32</option>
            <option value="custom">Custom</option>
          </select>
        </div>
        <div class="row">
          <div class="lbl">D (mm)</div>
          <input type="text" id="d" value="10" min="1" step="0.1" onchange="onDChange()">
        </div>
        <div class="row">
          <div class="lbl">Pitch P (mm)</div>
          <input type="text" id="pitch" value="1.5" min="0.1" step="0.01" onchange="onPitchChange()">
        </div>
        <div class="hint" id="eng_hint"></div>
      </div>

      <div class="card">
        <h3>Options</h3>
        <div class="row" id="gap_row">
          <div class="lbl">Gap (mm)</div>
          <input type="text" id="gap" value="0.3" min="0" step="0.05" oninput="onGapChange()" onchange="onGapChange()">
        </div>
        <div class="row dim" id="tap_color_row">
          <div class="lbl">Tap color</div>
          <div id="tap_color_swatch" class="color-swatch" title="Click: pick color from selected object" onclick="tapColorClick()"></div>
          <input type="hidden" id="tap_color" value="">
        </div>
        <div class="check-row"><label><input type="checkbox" id="chamfer" onchange="onChamferChange()"> Thread lead-in chamfer</label></div>
        <div class="row dim" id="chamfer_height_row">
          <div class="lbl">Chamfer height (mm)</div>
          <input type="text" id="chamfer_height" value="1.5">
        </div>
        <div class="row dim" id="max_angle_row">
          <div class="lbl">Max overhang angle (°)</div>
          <input type="text" id="max_overhang_angle" value="60"
                 onchange="updateAngleHint()">
          <span class="adj" id="angle_hint"></span>
        </div>
        <div class="row dim" id="min_core_row">
          <div class="lbl">Min. core (%D)</div>
          <input type="text" id="min_core_pct" value="70"
                 onchange="updateCoreHint()">
          <span class="adj" id="core_hint"></span>
        </div>
        <div class="row">
          <div class="lbl">Segments / turn</div>
          <input type="text" id="n_theta" value="24" min="6" max="120" step="6" onchange="onNTheta()">
          <span class="adj" id="nth_hint"></span>
        </div>
      </div>

      <button id="btn" onclick="doGenerate()">Generate</button>
      <div class="err" id="err"></div>

      <script>
      var ISO={M3:{d:3,p:0.5},M4:{d:4,p:0.7},M5:{d:5,p:0.8},M6:{d:6,p:1.0},
               M8:{d:8,p:1.25},M10:{d:10,p:1.5},M12:{d:12,p:1.75},
               M16:{d:16,p:2.0},M20:{d:20,p:2.5},M22:{d:22,p:2.5},
               M24:{d:24,p:3.0},M27:{d:27,p:3.0},M30:{d:30,p:3.5},M32:{d:32,p:3.5}};

      var SAVED = __SAVED_JSON__;

      // Etat independant par mode — sauvegarde/restaure les params a chaque switch
      var currentMode = 'iso';
      var modeStates = {
        iso:     { m_size:'M10', d:10,  pitch:1.5,  gap:0.3, chamfer_height:1.5 },
        plastic: { d:10,         pitch:2.5, gap:0.4, chamfer_height:1.25,
                   max_overhang_angle:60, min_core_pct:70 }
      };

      function g(id){return document.getElementById(id);}
      function norm(v){return (v+'').replace(',','.');}
      function fv(id){return parseFloat(norm(g(id).value))||0;}
      function iv(id){return parseInt(norm(g(id).value))||0;}

      function setDim(id, v){
        var el=g(id); if(!el)return;
        el.style.opacity=v?'0.38':'1';
        el.style.pointerEvents=v?'none':'auto';
      }

      function getProfileType(){
        var radios=document.getElementsByName('profile_type');
        for(var i=0;i<radios.length;i++){if(radios[i].checked)return radios[i].value;}
        return 'iso';
      }

      function saveModeState(mode){
        var s=modeStates[mode];
        s.d=fv('d'); s.pitch=fv('pitch'); s.gap=fv('gap');
        s.chamfer_height=fv('chamfer_height')||s.pitch;
        if(mode==='iso'){
          s.m_size=g('m_size').value;
        } else {
          s.max_overhang_angle=fv('max_overhang_angle')||60;
          s.min_core_pct=fv('min_core_pct')||70;
        }
      }

      function loadModeState(mode){
        var s=modeStates[mode];
        g('d').value=s.d; g('pitch').value=s.pitch; g('gap').value=s.gap;
        if(mode==='iso'){
          g('chamfer_height').value=s.chamfer_height||s.pitch;
          g('m_size').value=s.m_size||'M10';
        } else {
          // FDM : chamfer height par defaut = P/2
          g('chamfer_height').value=s.chamfer_height||((s.pitch/2).toFixed(2));
          g('m_size').value='custom';
          g('max_overhang_angle').value=s.max_overhang_angle||60;
          g('min_core_pct').value=s.min_core_pct||70;
        }
      }

      function onCreateChange(){
        setDim('row_length_tige',   !g('create_tige').checked);
        setDim('row_length_ecrou',  !g('create_ecrou').checked);
        setDim('row_length_taraud', !g('create_taraud').checked);
        var needGap = g('create_ecrou').checked || g('create_taraud').checked;
        setDim('gap_row', !needGap);
        setDim('tap_color_row', !g('create_taraud').checked);
        updateNutHeightHint();
      }

      function setSwatchColor(hex){
        var sw=g('tap_color_swatch');
        if(hex){
          sw.style.background=hex;
          sw.className='color-swatch';
        } else {
          sw.style.background='';
          sw.className='color-swatch color-none';
        }
        g('tap_color').value=hex||'';
      }

      function tapColorClick(){
        if(typeof sketchup!=='undefined') sketchup.pick_tap_color('');
        else window.location='skp:pick_tap_color@';
      }

      function tapColorClear(){ setSwatchColor(''); }

      function onTapColorPicked(hex){ setSwatchColor(hex); }

      function onGapChange(){
        modeStates[currentMode].gap = fv('gap');
        var j=JSON.stringify({iso_gap:modeStates.iso.gap, plastic_gap:modeStates.plastic.gap});
        if(typeof sketchup!=='undefined'){
          sketchup.save_gap(j);
        } else {
          window.location='skp:save_gap@'+encodeURIComponent(j);
        }
      }

      function onChamferChange(){
        setDim('chamfer_height_row', !g('chamfer').checked);
      }

      function initForm(s){
        if(!s) return;
        // Initialiser les etats par mode depuis les donnees sauvegardees
        if(s.iso)     for(var k in s.iso)     modeStates.iso[k]=s.iso[k];
        if(s.plastic) for(var k in s.plastic) modeStates.plastic[k]=s.plastic[k];
        // Activer le bon mode
        if(s.profile_type!==undefined){
          var radios=document.getElementsByName('profile_type');
          for(var i=0;i<radios.length;i++) radios[i].checked=(radios[i].value===s.profile_type);
          currentMode=s.profile_type;
        }
        var isPlastic=(currentMode==='plastic');
        setDim('iso_preset_row', isPlastic);
        setDim('max_angle_row',  !isPlastic);
        setDim('min_core_row',   !isPlastic);
        // Charger les params du mode actif
        loadModeState(currentMode);
        // Params independants du mode
        if(s.create_tige!==undefined)   g('create_tige').checked=s.create_tige;
        if(s.create_ecrou!==undefined)  g('create_ecrou').checked=s.create_ecrou;
        if(s.create_taraud!==undefined) g('create_taraud').checked=s.create_taraud;
        if(s.length_tige!==undefined)   g('length_tige').value=s.length_tige;
        if(s.length_ecrou!==undefined)  g('length_ecrou').value=s.length_ecrou;
        if(s.length_taraud!==undefined) g('length_taraud').value=s.length_taraud;
        if(s.chamfer!==undefined)   g('chamfer').checked=s.chamfer;
        if(s.n_theta!==undefined)   g('n_theta').value=s.n_theta;
        setSwatchColor(s.tap_color||'');
        onCreateChange();
        onChamferChange();
        updateHint();
        updateAngleHint();
        updateNutHeightHint();
      }

      function onPitchChange(){
        if(currentMode==='plastic'){
          var p=fv('pitch')||1.0;
          g('chamfer_height').value=(p/2).toFixed(2);
        }
        updateAngleHint();
        updateNutHeightHint();
      }

      function updateNutHeightHint(){
        var el=g('nut_height_hint');
        if(!el) return;
        var isPlastic=(currentMode==='plastic');
        var hasNut=g('create_ecrou')&&g('create_ecrou').checked;
        if(!isPlastic||!hasNut){el.textContent=' ';el.style.opacity='0.3';return;}
        var h=fv('length_ecrou')||8, pitch=fv('pitch')||1.0;
        var ratio=h/pitch;
        if(ratio<3){
          el.textContent='⚠ '+ratio.toFixed(1)+'×P';
          el.style.color='#c00'; el.style.opacity='1';
        } else {
          el.textContent='✓ '+ratio.toFixed(1)+'×P';
          el.style.color='#2a7'; el.style.opacity='1';
        }
      }

      function updateAngleHint(){
        var pitch=fv('pitch')||1.5;
        var angle=fv('max_overhang_angle')||60;
        var d=(pitch/2)*Math.tan(angle*Math.PI/180);
        var isPlastic=(currentMode==='plastic');
        var el=g('angle_hint');
        el.textContent='depth: '+d.toFixed(3)+' mm';
        el.style.opacity=isPlastic?'1':'0.3';
        updateCoreHint();
        updateNutHeightHint();
      }

      function updateCoreHint(){
        var D=fv('d')||10, pct=fv('min_core_pct')||70;
        var r_maj=D/2, r_min=r_maj*pct/100;
        var pitch=fv('pitch')||1.5, angle=fv('max_overhang_angle')||60;
        var depth_req=(pitch/2)*Math.tan(angle*Math.PI/180);
        var clamped=depth_req>(r_maj-r_min);
        var isPlastic=(currentMode==='plastic');
        var el=g('core_hint');
        el.textContent='core: '+(2*r_min).toFixed(2)+'mm'+(clamped?' ⚠ clamped':'');
        el.style.opacity=isPlastic?'1':'0.3';
      }

      function onProfileChange(){
        saveModeState(currentMode);
        currentMode=getProfileType();
        var isPlastic=(currentMode==='plastic');
        setDim('iso_preset_row', isPlastic);
        setDim('max_angle_row',  !isPlastic);
        setDim('min_core_row',   !isPlastic);
        loadModeState(currentMode);
        updateHint();
        updateAngleHint();
      }

      function onMSize(){
        var m=g('m_size').value;
        if(!ISO[m])return;
        g('d').value=ISO[m].d;
        g('pitch').value=ISO[m].p;
        g('chamfer_height').value=ISO[m].p;
        updateHint();
      }

      function onDChange(){
        if(currentMode==='plastic'){
          var d=fv('d')||10;
          var p=parseFloat((0.25*d).toFixed(2));
          g('pitch').value=p;
          g('chamfer_height').value=(p/2).toFixed(2);
        } else {
          g('m_size').value='custom';
        }
        updateHint();
        updateNutHeightHint();
      }

      function updateHint(){
        var d=fv('d')||10;
        g('eng_hint').textContent='Recommended engagement: >= '+(2*d).toFixed(0)+
          ' mm  (ideal '+(3*d).toFixed(0)+' – '+(4*d).toFixed(0)+' mm)';
      }

      function onNTheta(){
        var n=iv('n_theta');
        var adj=Math.round(n/6)*6;
        if(adj<6)adj=6;
        if(adj>120)adj=120;
        g('n_theta').value=adj;
        g('nth_hint').textContent=(adj!==n)?('(adjusted to '+adj+')'):' ';
      }

      function doGenerate(){
        g('err').textContent='';
        onNTheta();
        var tige=g('create_tige').checked, ecrou=g('create_ecrou').checked;
        var taraud=g('create_taraud').checked;
        if(!tige&&!ecrou&&!taraud){g('err').textContent='Check at least one part.';return;}
        var d=fv('d'),pitch=fv('pitch'),gap=fv('gap'),nth=iv('n_theta');
        var lt=fv('length_tige'), le=fv('length_ecrou'), lta=fv('length_taraud');
        if(d<=0){g('err').textContent='Invalid D.';return;}
        if(pitch<=0){g('err').textContent='Invalid pitch P.';return;}
        if(tige&&lt<=0){g('err').textContent='Invalid rod height.';return;}
        if(ecrou&&le<=0){g('err').textContent='Invalid nut height.';return;}
        if(taraud&&lta<=0){g('err').textContent='Invalid tap thread length.';return;}
        if((ecrou||taraud)&&gap<0){g('err').textContent='Invalid gap.';return;}
        saveModeState(currentMode);
        var p={
          profile_type:currentMode,
          iso:modeStates.iso,
          plastic:modeStates.plastic,
          m_size:g('m_size').value,
          d:d, pitch:pitch,
          length_tige:lt, length_ecrou:le, length_taraud:lta,
          create_tige:tige, create_ecrou:ecrou, create_taraud:taraud,
          gap:gap,
          chamfer:g('chamfer').checked,
          chamfer_height:fv('chamfer_height')||pitch||1.5,
          n_theta:nth,
          max_overhang_angle:fv('max_overhang_angle')||60,
          min_core_pct:fv('min_core_pct')||70,
          tap_color:g('tap_color').value
        };
        var j=JSON.stringify(p);
        if(typeof sketchup!=='undefined'){
          sketchup.generate(j);
        } else {
          window.location='skp:generate@'+encodeURIComponent(j);
        }
      }

      // Debug resize — affiche la taille dans la console Ruby
      window.addEventListener('resize', function(){
        var s=window.innerWidth+'x'+window.innerHeight;
        if(typeof sketchup!=='undefined') sketchup.log_size(s);
        else window.location='skp:log_size@'+s;
      });
      window.onload = function(){ initForm(SAVED); };
      </script>
      </body>
      </html>
    HTML

    # -------------------------------------------------------------------------
    # Persistance des parametres (registre SketchUp)
    # -------------------------------------------------------------------------
    def self.read_defaults
      iso_pitch = Sketchup.read_default(PREF_KEY, 'iso_pitch', 1.5).to_f
      fdm_pitch = Sketchup.read_default(PREF_KEY, 'plastic_pitch', 2.5).to_f
      {
        'profile_type' => Sketchup.read_default(PREF_KEY, 'profile_type', 'iso'),
        'create_tige'   => Sketchup.read_default(PREF_KEY, 'create_tige',   true),
        'create_ecrou'  => Sketchup.read_default(PREF_KEY, 'create_ecrou',  false),
        'create_taraud' => Sketchup.read_default(PREF_KEY, 'create_taraud', false),
        'length_tige'   => Sketchup.read_default(PREF_KEY, 'length_tige',   50.0).to_f,
        'length_ecrou'  => Sketchup.read_default(PREF_KEY, 'length_ecrou',  8.0).to_f,
        'length_taraud' => Sketchup.read_default(PREF_KEY, 'length_taraud', 20.0).to_f,
        'chamfer'       => Sketchup.read_default(PREF_KEY, 'chamfer',       false),
        'n_theta'       => Sketchup.read_default(PREF_KEY, 'n_theta',       24).to_i,
        'tap_color'     => Sketchup.read_default(PREF_KEY, 'tap_color',     nil) || detect_tap_color,
        'iso' => {
          'm_size'         => Sketchup.read_default(PREF_KEY, 'iso_m_size',         'M10'),
          'd'              => Sketchup.read_default(PREF_KEY, 'iso_d',              10.0).to_f,
          'pitch'          => iso_pitch,
          'gap'            => Sketchup.read_default(PREF_KEY, 'iso_gap',            0.3).to_f,
          'chamfer_height' => Sketchup.read_default(PREF_KEY, 'iso_chamfer_height', iso_pitch).to_f,
        },
        'plastic' => {
          'd'                  => Sketchup.read_default(PREF_KEY, 'plastic_d',                  10.0).to_f,
          'pitch'              => fdm_pitch,
          'gap'                => Sketchup.read_default(PREF_KEY, 'plastic_gap',               0.4).to_f,
          'chamfer_height'     => Sketchup.read_default(PREF_KEY, 'plastic_chamfer_height',    fdm_pitch).to_f,
          'max_overhang_angle' => Sketchup.read_default(PREF_KEY, 'plastic_max_overhang_angle',60.0).to_f,
          'min_core_pct'       => Sketchup.read_default(PREF_KEY, 'plastic_min_core_pct',      70.0).to_f,
        },
      }
    end

    def self.save_defaults(params)
      %w[profile_type create_tige create_ecrou create_taraud
         length_tige length_ecrou length_taraud
         chamfer n_theta tap_color].each do |k|
        Sketchup.write_default(PREF_KEY, k, params[k]) if params.key?(k)
      end
      if params['iso'].is_a?(Hash)
        params['iso'].each { |k, v| Sketchup.write_default(PREF_KEY, "iso_#{k}", v) }
      end
      if params['plastic'].is_a?(Hash)
        params['plastic'].each { |k, v| Sketchup.write_default(PREF_KEY, "plastic_#{k}", v) }
      end
    end

    def self.detect_tap_color
      begin
        color = if defined?(SolidBatch) && SolidBatch.respond_to?(:subtract_color)
          SolidBatch.subtract_color
        else
          r = Sketchup.read_default('SolidBatch', 'subtract_color_r', nil)
          r ? Sketchup::Color.new(r.to_i,
                Sketchup.read_default('SolidBatch', 'subtract_color_g', 0).to_i,
                Sketchup.read_default('SolidBatch', 'subtract_color_b', 0).to_i)
            : nil
        end
        color ? '#%02X%02X%02X' % [color.red, color.green, color.blue] : '#FFE5CC'
      rescue
        '#FFE5CC'
      end
    end

    def self.build_html(defs)
      HTML_TEMPLATE.sub('__SAVED_JSON__', defs.to_json)
    end

    # -------------------------------------------------------------------------
    # Affichage du dialog
    # -------------------------------------------------------------------------
    def self.show
      defined?(UI::HtmlDialog) ? show_html_dialog : show_web_dialog
    end

    def self.show_html_dialog
      dlg = UI::HtmlDialog.new(
        dialog_title:    DIALOG_TITLE,
        preferences_key: 'VFGDialog',
        width:  384,
        height: 640,
        min_width:  300,
        min_height: 400,
        style: UI::HtmlDialog::STYLE_DIALOG
      )
      dlg.set_html(build_html(read_defaults))
      dlg.add_action_callback('generate') do |_ctx, json_str|
        handle_generate(json_str)
      end
      dlg.add_action_callback('save_gap') do |_ctx, json_str|
        begin
          data = JSON.parse(json_str)
          Sketchup.write_default(PREF_KEY, 'iso_gap',     data['iso_gap'].to_f)     if data.key?('iso_gap')
          Sketchup.write_default(PREF_KEY, 'plastic_gap', data['plastic_gap'].to_f) if data.key?('plastic_gap')
        rescue; end
      end
      dlg.add_action_callback('pick_tap_color') do |_ctx, _|
        sel = Sketchup.active_model.selection.first
        if sel
          if sel.respond_to?(:material) && sel.material
            c = sel.material.color
            hex = '#%02X%02X%02X' % [c.red, c.green, c.blue]
            dlg.execute_script("onTapColorPicked('#{hex}')")
          else
            dlg.execute_script("onTapColorPicked('')")
          end
        end
      end
      dlg.add_action_callback('log_size') do |_ctx, dims|
        puts "[VFG] Dialog content size: #{dims}"
      end
      dlg.show
    end

    def self.show_web_dialog
      dlg = UI::WebDialog.new(DIALOG_TITLE, false, 'VFGDialog', 360, 620, 100, 100, true)
      dlg.set_html(build_html(read_defaults))
      dlg.add_action_callback('generate') do |_dlg, encoded|
        begin
          json_str = CGI.unescape(encoded.to_s)
          handle_generate(json_str)
        rescue => e
          UI.messagebox("Decode error: #{e.message}", MB_OK)
        end
      end
      dlg.add_action_callback('save_gap') do |_dlg, encoded|
        begin
          data = JSON.parse(CGI.unescape(encoded.to_s))
          Sketchup.write_default(PREF_KEY, 'iso_gap',     data['iso_gap'].to_f)     if data.key?('iso_gap')
          Sketchup.write_default(PREF_KEY, 'plastic_gap', data['plastic_gap'].to_f) if data.key?('plastic_gap')
        rescue; end
      end
      dlg.show
    end

    def self.handle_generate(json_str)
      params = JSON.parse(json_str)
      save_defaults(params)
      Geometry.generate(params, Sketchup.active_model)
    rescue JSON::ParserError => e
      UI.messagebox("JSON error: #{e.message}", MB_OK)
    end

    private_class_method :read_defaults, :save_defaults, :detect_tap_color, :build_html,
                         :show_html_dialog, :show_web_dialog, :handle_generate

  end
end
