# vis_filets_generator/dialog.rb
# Interface utilisateur WebDialog (SU 2014+) avec upgrade HtmlDialog si SU 2017+

require 'json'
require 'cgi'

module VisFiletsGenerator
  module DialogManager

    DIALOG_TITLE = 'Vis & Filets — Generateur'.freeze

    HTML = <<~'HTML'
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
        select,input[type=number]{border:1px solid #bbb;border-radius:2px;padding:2px 4px;
          background:#fafafa;font-size:12px}
        select{width:130px}
        input[type=number]{width:80px}
        .check-row{margin:4px 0}
        .hint{color:#777;font-size:10px;margin-top:3px;font-style:italic}
        .adj{color:#2a7;font-size:10px;margin-left:4px}
        #btn{width:100%;padding:7px;background:#0066cc;color:#fff;border:none;
             border-radius:3px;cursor:pointer;font-size:13px;font-weight:bold;margin-top:2px}
        #btn:hover{background:#0052a3}
        .err{color:#c00;font-size:11px;margin-top:4px;min-height:14px}
      </style>
      </head>
      <body>

      <div class="card">
        <h3>Type de filet</h3>
        <div class="row">
          <div class="lbl">Profil</div>
          <select id="profile_type" onchange="onProfileChange()">
            <option value="iso">ISO metrique</option>
            <option value="plastic">Optimise plastique FDM</option>
          </select>
        </div>
      </div>

      <div class="card">
        <h3>Dimensions</h3>
        <div class="row" id="iso_preset_row">
          <div class="lbl">Taille M</div>
          <select id="m_size" onchange="onMSize()">
            <option value="M3">M3</option><option value="M4">M4</option>
            <option value="M5">M5</option><option value="M6">M6</option>
            <option value="M8">M8</option><option value="M10" selected>M10</option>
            <option value="M12">M12</option><option value="M16">M16</option>
            <option value="M20">M20</option><option value="custom">Personnalise</option>
          </select>
        </div>
        <div class="row">
          <div class="lbl">D (mm)</div>
          <input type="number" id="d" value="10" min="1" step="0.1" onchange="onDChange()">
        </div>
        <div class="row">
          <div class="lbl">Pas P (mm)</div>
          <input type="number" id="pitch" value="1.5" min="0.1" step="0.01">
        </div>
        <div class="row">
          <div class="lbl">Hauteur (mm)</div>
          <input type="number" id="length" value="50" min="0.1" step="1">
        </div>
        <div class="hint" id="eng_hint"></div>
      </div>

      <div class="card">
        <h3>Pieces a creer</h3>
        <div class="check-row"><label><input type="checkbox" id="create_tige" checked> Tige filetee &nbsp;(&#216; D)</label></div>
        <div class="check-row"><label><input type="checkbox" id="create_ecrou"> Ecrou hexagonal &nbsp;(alesage D + gap)</label></div>
      </div>

      <div class="card">
        <h3>Options</h3>
        <div class="row">
          <div class="lbl">Gap (mm)</div>
          <input type="number" id="gap" value="0.3" min="0" step="0.05">
        </div>
        <div class="check-row"><label><input type="checkbox" id="chamfer"> Chanfrein aux extremites</label></div>
        <div class="row">
          <div class="lbl">Segments / tour</div>
          <input type="number" id="n_theta" value="24" min="6" max="120" step="6" onchange="onNTheta()">
          <span class="adj" id="nth_hint"></span>
        </div>
      </div>

      <button id="btn" onclick="doGenerate()">Generer</button>
      <div class="err" id="err"></div>

      <script>
      var ISO={M3:{d:3,p:0.5},M4:{d:4,p:0.7},M5:{d:5,p:0.8},M6:{d:6,p:1.0},
               M8:{d:8,p:1.25},M10:{d:10,p:1.5},M12:{d:12,p:1.75},
               M16:{d:16,p:2.0},M20:{d:20,p:2.5}};

      function g(id){return document.getElementById(id);}
      function fv(id){return parseFloat(g(id).value)||0;}
      function iv(id){return parseInt(g(id).value)||0;}

      function onProfileChange(){
        var t=g('profile_type').value;
        g('iso_preset_row').style.display=(t==='iso')?'flex':'none';
        if(t==='plastic'){
          var d=fv('d')||10;
          g('pitch').value=(0.25*d).toFixed(2);
          g('gap').value='0.40';
          g('m_size').value='custom';
        } else {
          g('gap').value='0.30';
          onMSize();
        }
        updateHint();
      }

      function onMSize(){
        var m=g('m_size').value;
        if(!ISO[m])return;
        g('d').value=ISO[m].d;
        g('pitch').value=ISO[m].p;
        updateHint();
      }

      function onDChange(){
        if(g('profile_type').value==='plastic'){
          var d=fv('d')||10;
          g('pitch').value=(0.25*d).toFixed(2);
        } else {
          g('m_size').value='custom';
        }
        updateHint();
      }

      function updateHint(){
        var d=fv('d')||10;
        g('eng_hint').textContent='Engagement recommande : >= '+(2*d).toFixed(0)+
          ' mm  (ideal '+(3*d).toFixed(0)+' – '+(4*d).toFixed(0)+' mm)';
      }

      function onNTheta(){
        var n=iv('n_theta');
        var adj=Math.round(n/6)*6;
        if(adj<6)adj=6;
        if(adj>120)adj=120;
        g('n_theta').value=adj;
        g('nth_hint').textContent=(adj!==n)?('(ajuste a '+adj+')'):' ';
      }

      function doGenerate(){
        g('err').textContent='';
        onNTheta();
        var tige=g('create_tige').checked, ecrou=g('create_ecrou').checked;
        if(!tige&&!ecrou){g('err').textContent='Cochez au moins une piece.';return;}
        var d=fv('d'),pitch=fv('pitch'),len=fv('length'),gap=fv('gap'),nth=iv('n_theta');
        if(d<=0){g('err').textContent='D invalide.';return;}
        if(pitch<=0){g('err').textContent='Pas P invalide.';return;}
        if(len<=0){g('err').textContent='Hauteur invalide.';return;}
        if(gap<0){g('err').textContent='Gap invalide.';return;}
        var p={
          profile_type:g('profile_type').value,
          m_size:g('m_size').value,
          d:d, pitch:pitch, length:len,
          create_tige:tige, create_ecrou:ecrou,
          gap:gap,
          chamfer:g('chamfer').checked,
          n_theta:nth
        };
        var j=JSON.stringify(p);
        if(typeof sketchup!=='undefined'){
          sketchup.generate(j);
        } else {
          window.location='skp:generate@'+encodeURIComponent(j);
        }
      }

      updateHint();
      </script>
      </body>
      </html>
    HTML

    def self.show
      if defined?(UI::HtmlDialog)
        show_html_dialog
      else
        show_web_dialog
      end
    end

    def self.show_html_dialog
      dlg = UI::HtmlDialog.new(
        dialog_title:    DIALOG_TITLE,
        preferences_key: 'VFGDialog',
        width:  340,
        height: 580,
        min_width:  300,
        min_height: 400,
        style: UI::HtmlDialog::STYLE_DIALOG
      )
      dlg.set_html(HTML)
      dlg.add_action_callback('generate') do |_ctx, json_str|
        handle_generate(json_str)
      end
      dlg.show
    end

    def self.show_web_dialog
      dlg = UI::WebDialog.new(DIALOG_TITLE, false, 'VFGDialog', 340, 580, 100, 100, true)
      dlg.set_html(HTML)
      dlg.add_action_callback('generate') do |_dlg, encoded|
        begin
          json_str = CGI.unescape(encoded.to_s)
          handle_generate(json_str)
        rescue => e
          UI.messagebox("Erreur decodage : #{e.message}", MB_OK)
        end
      end
      dlg.show
    end

    def self.handle_generate(json_str)
      params = JSON.parse(json_str)
      Geometry.generate(params, Sketchup.active_model)
    rescue JSON::ParserError => e
      UI.messagebox("Erreur JSON : #{e.message}", MB_OK)
    end

    private_class_method :show_html_dialog, :show_web_dialog, :handle_generate

  end
end
