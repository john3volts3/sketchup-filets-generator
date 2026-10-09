# vis_filets_generator/dialog.rb
# Interface utilisateur WebDialog (SU 2014+) avec upgrade HtmlDialog si SU 2017+
# Parametres persistes entre sessions via Sketchup.write_default / read_default
#
# Dialog layout (v1.10.0): a cross-section drawing (fixed 440 x 300 px SVG) carries
# the dimension fields as absolutely positioned HTML inputs; options without a
# dimension sit below it. A single HTML page serves both HtmlDialog (Chromium) and
# WebDialog (IE engine, forced to IE=edge): ES5 only, no flex / grid, no classList
# on SVG elements.

require 'json'
require 'cgi'

module VisFiletsGenerator
  module DialogManager

    DIALOG_TITLE = 'Vis & Filets — Generator'.freeze
    PREF_KEY     = 'VisFiletsGenerator'.freeze
    # Window size/position memory. Changed once (v1.10.0) to seed the new default
    # size; do not change again or users lose their own window size.
    DLG_PREF_KEY = 'VFGDialog_v2'.freeze
    DLG_WIDTH    = 490
    DLG_HEIGHT   = 600

    HTML_TEMPLATE = <<'HTML'
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta charset="utf-8">
<style>
 body{font-family:'Segoe UI',Arial,sans-serif;font-size:12px;margin:12px;color:#222;background:#fff;width:440px}
 .tabs{height:26px;line-height:26px;margin-bottom:6px;white-space:nowrap}
 .tabs button{padding:3px 12px;margin:0 2px;border:1px solid #aaa;background:#f2f2f2;border-radius:3px;cursor:pointer;font-size:12px}
 .tabs button.sel{background:#2e8b57;color:#fff;border-color:#1d6b3f}
 .tabs select{font-size:12px}
 .stage{position:relative;width:440px;height:300px;background:#fafafa;border:1px solid #ddd;border-radius:3px}
 .stage svg{position:absolute;left:0;top:0;width:440px;height:300px}
 .stage input.f{position:absolute;width:40px;height:18px;box-sizing:border-box;padding:0 3px;font-size:11px;
   border:1px solid #9aa;border-radius:2px;background:#fff;text-align:center}
 .stage input.f:focus{outline:none;border-color:#e8590c;box-shadow:0 0 0 2px rgba(232,89,12,.25)}
 .stage input.f[disabled]{background:#eee;color:#999}
 .stage .part{position:absolute;font-size:11px;white-space:nowrap;cursor:pointer;color:#333}
 .stage .part input{margin:0 3px 0 0;vertical-align:-2px}
 .stage .adj{position:absolute;font-size:10px}
 input.bad{border-color:#c00 !important;background:#fde8e8 !important}
 svg text{font-size:10px;fill:#666}
 .dim line,.dim path.d{stroke:#888;stroke-width:1;fill:none}
 .on line,.on path,.on polyline{stroke:#e8590c !important;stroke-width:2 !important}
 .on text{fill:#e8590c;font-weight:bold}
 table.opts{margin-top:8px;border-collapse:collapse}
 table.opts td{padding:2px 6px 2px 0;white-space:nowrap}
 table.opts input[type=text]{width:46px;padding:1px 3px;font-size:12px;border:1px solid #bbb;border-radius:2px}
 .color-swatch{width:44px;height:20px;border:1px solid #bbb;border-radius:2px;cursor:pointer;display:inline-block;vertical-align:middle}
 .color-none{background:repeating-linear-gradient(45deg,#ddd,#ddd 3px,#fff 3px,#fff 7px)}
 .adj{color:#2a7;font-size:10px}
 .clr-btn{cursor:pointer;color:#999;font-size:13px;margin-left:4px;vertical-align:middle}
 .clr-btn:hover{color:#c00}
 .hint{height:48px;line-height:16px;overflow:hidden;font-size:11px;color:#555;margin:8px 0 4px}
 .err{color:#c00;min-height:16px;font-weight:bold}
 .btns{text-align:center;margin-top:4px}
 .btns button{padding:5px 14px;margin:0 4px;cursor:pointer;font-size:12px}
 .primary{background:#2e8b57;color:#fff;border:1px solid #1d6b3f;border-radius:3px}
</style>
</head>
<body>
<div class="tabs" data-k="profile_type">Thread:
 <button id="b-iso">ISO metric</button><button id="b-fdm">FDM plastic</button>
 <span id="m_row" data-k="m_size">&nbsp;&nbsp;Size
  <select id="m_size">
   <option value="M3">M3</option><option value="M4">M4</option>
   <option value="M5">M5</option><option value="M6">M6</option>
   <option value="M8">M8</option><option value="M10" selected>M10</option>
   <option value="M12">M12</option><option value="M16">M16</option>
   <option value="M20">M20</option><option value="M22">M22</option>
   <option value="M24">M24</option><option value="M27">M27</option>
   <option value="M30">M30</option><option value="M32">M32</option>
   <option value="custom">Custom</option>
  </select>
 </span>
</div>
<div class="stage">
__SVG__
 <label class="part" style="left:40px;top:4px" data-k="create_tige"><input type="checkbox" id="create_tige" checked>Threaded rod</label>
 <label class="part" style="left:205px;top:96px" data-k="create_ecrou"><input type="checkbox" id="create_ecrou">Hex nut</label>
 <label class="part" style="left:372px;top:34px" data-k="create_taraud"><input type="checkbox" id="create_taraud">Tap</label>
 <input type="text" class="f" id="d"                  style="left:14px;top:31px"  value="10">
 <input type="text" class="f" id="length_tige"        style="left:4px;top:143px"  value="50">
 <input type="text" class="f" id="chamfer_height"     style="left:124px;top:47px" value="1.5">
 <input type="text" class="f" id="max_overhang_angle" style="left:124px;top:112px" value="60">
 <input type="text" class="f" id="pitch"              style="left:124px;top:157px" value="1.5">
 <input type="text" class="f" id="min_core_pct"       style="left:108px;top:257px" value="70">
 <input type="text" class="f" id="gap"                style="left:215px;top:149px;width:36px" value="0.3">
 <input type="text" class="f" id="length_ecrou"       style="left:306px;top:153px" value="8">
 <span class="adj" id="nut_height_hint"               style="left:306px;top:174px">&nbsp;</span>
 <input type="text" class="f" id="length_taraud"      style="left:392px;top:266px" value="20">
</div>
<table class="opts"><tr>
 <td data-k="n_theta">Segments / turn</td>
 <td><input type="text" id="n_theta" value="24"> <span class="adj" id="nth_hint"></span></td>
 <td data-k="tap_color">&nbsp;&nbsp;Tap color</td>
 <td id="tap_color_row"><div id="tap_color_swatch" class="color-swatch"></div><span class="clr-btn" id="tap_color_clr" title="No color">&#10005;</span><input type="hidden" id="tap_color" value=""></td>
</tr><tr>
 <td colspan="4"><label data-k="chamfer"><input type="checkbox" id="chamfer"> Thread lead-in chamfer</label></td>
</tr></table>
<div class="hint" id="hint"></div>
<div class="err" id="err"></div>
<div class="btns">
 <button id="b-close">Close</button>
 <button id="place_with_mouse" class="primary">Place with mouse</button>
 <button id="btn" class="primary">Generate</button>
</div>

<script>
var ISO={M3:{d:3,p:0.5},M4:{d:4,p:0.7},M5:{d:5,p:0.8},M6:{d:6,p:1.0},
         M8:{d:8,p:1.25},M10:{d:10,p:1.5},M12:{d:12,p:1.75},
         M16:{d:16,p:2.0},M20:{d:20,p:2.5},M22:{d:22,p:2.5},
         M24:{d:24,p:3.0},M27:{d:27,p:3.0},M30:{d:30,p:3.5},M32:{d:32,p:3.5}};

var SAVED = __SAVED_JSON__;

// Independent state per mode: params are saved/restored on each switch
var currentMode = 'iso';
var modeStates = {
  iso:     { m_size:'M10', d:10,  pitch:1.5,  gap:0.3, chamfer_height:1.5 },
  plastic: { d:10,         pitch:2.5, gap:0.4, chamfer_height:1.25,
             max_overhang_angle:60, min_core_pct:70 }
};
var focusKey = null;

function g(id){return document.getElementById(id);}
function norm(v){return (v+'').replace(',','.');}
function fv(id){return parseFloat(norm(g(id).value))||0;}
function iv(id){return parseInt(norm(g(id).value),10)||0;}
function num(id){return parseFloat(norm(g(id).value));}      // NaN when empty or invalid
function each(list,fn){for(var i=0;i<list.length;i++)fn(list[i],i);}
// class toggle that also works on SVG elements under IE (no classList there)
function setCls(el,c,on){
  var s=' '+(el.getAttribute('class')||'')+' ';
  s=s.replace(' '+c+' ',' ');
  if(on) s+=c;
  el.setAttribute('class',s.replace(/^\s+|\s+$/g,'').replace(/\s+/g,' '));
}
function showSel(sel,on){each(document.querySelectorAll(sel),function(e){e.style.display=on?'':'none';});}
function send(name,arg){
  if(typeof sketchup!=='undefined') sketchup[name](arg);
  else window.location='skp:'+name+'@'+encodeURIComponent(arg);
}

// ---- Help: field key -> highlighted drawing group (d-<key>) and help text ----
var HINT={
  profile_type:'ISO metric: standard 60° V thread (ISO 261 / 724). FDM plastic: flanks limited to the max overhang angle, flat root when the core limit is reached.',
  m_size:'ISO preset: fills D and pitch P from the ISO coarse-pitch table.',
  d:'Major (outer) diameter D, in model units. ISO: switches Size to Custom. FDM: sets P = 0.25 × D.',
  pitch:'Thread pitch P: axial distance between two crests.',
  length_tige:'Height of the threaded rod.',
  length_ecrou:'Height of the hex nut (FDM: aim for at least 3 × P).',
  length_taraud:'Threaded length of the tap. The tap is a cutting tool: subtract it from a part to make a threaded hole.',
  gap:'Radial clearance added to the nut and tap threads (3D-printing fit). Saved immediately.',
  chamfer:'Lead-in chamfer at the thread start (top of the rod, both ends of the nut).',
  chamfer_height:'Height of the lead-in chamfer (default: P in ISO, P / 2 in FDM).',
  max_overhang_angle:'FDM: max flank angle from the vertical axis, printable without support (10–85°).',
  min_core_pct:'FDM: minimum core diameter, in % of D. If the flanks would go deeper, the root becomes flat.',
  n_theta:'Facets per turn (multiple of 6, 6–120). More = smoother but heavier.',
  create_tige:'Create a threaded rod.',
  create_ecrou:'Create a hex nut (DIN 934 across flats for ISO sizes).',
  create_taraud:'Create a tap: threaded cutting tool to subtract from a part.',
  place_with_mouse:'Closes the dialog and generates, then an orange box follows the mouse: click to place the parts there. On a face, the parts are turned perpendicular to it: rod and nut stand on it, the tap is sunk into it by its threaded length. Esc, right-click or another tool: cancel, nothing is created.',
  btn:'Closes the dialog and generates the parts at the origin, selected and zoomed. The dialog reopens if the generation fails.',
  tap_color:'Tap color: select an object in the model, then click the swatch to take its material color. × = no color.'
};
var MAP={m_size:'d',chamfer:'chamfer_height',tap_color:'create_taraud',profile_type:'',n_theta:''};

function depthReq(){var p=fv('pitch')||1.5,a=fv('max_overhang_angle')||60;return (p/2)*Math.tan(a*Math.PI/180);}
function coreD(){return (fv('d')||10)*(fv('min_core_pct')||70)/100;}
function clamped(){return depthReq()>((fv('d')||10)-coreD())/2;}

function hintText(k){
  var t=HINT[k]||'';
  if(k==='length_ecrou'&&currentMode==='plastic') t+=' Now: '+(fv('length_ecrou')/(fv('pitch')||1)).toFixed(1)+' × P.';
  if(k==='max_overhang_angle') t+=' Theoretical depth: '+depthReq().toFixed(3)+'.';
  if(k==='min_core_pct') t+=' Core Ø: '+coreD().toFixed(2)+(clamped()?' (depth clamped: flat root).':'.');
  return t;
}
function defaultHint(){
  var d=fv('d')||10;
  return 'Hover or edit a value to see what it controls. Recommended engagement: ≥ '+(2*d).toFixed(0)+
         ' (ideal '+(3*d).toFixed(0)+' – '+(4*d).toFixed(0)+').';
}
function show(k){
  each(document.querySelectorAll('.dim'),function(e){setCls(e,'on',false);});
  var key=k?(MAP.hasOwnProperty(k)?MAP[k]:k):'';
  var el=key&&g('d-'+key); if(el) setCls(el,'on',true);
  g('hint').textContent=k?hintText(k):defaultHint();
}
function hover(el,k){
  el.addEventListener('mouseenter',function(){show(k);});
  el.addEventListener('mouseleave',function(){show(focusKey);});
}
function wireHelp(){
  for(var k in HINT){ (function(k){
    var f=(k==='tap_color')?g('tap_color_swatch'):g(k);
    if(f){
      hover(f,k);
      f.addEventListener('focus',function(){focusKey=k;show(k);});
      f.addEventListener('blur',function(){if(focusKey===k){focusKey=null;show(null);}});
    }
    var lab=document.querySelector('[data-k="'+k+'"]'); if(lab) hover(lab,k);
    var gr=g('d-'+k); if(gr) hover(gr,k);
  })(k); }
}
function setTips(){
  for(var k in HINT){
    var t=hintText(k);
    var f=(k==='tap_color')?g('tap_color_swatch'):g(k); if(f) f.title=t;
    var lab=document.querySelector('[data-k="'+k+'"]'); if(lab) lab.title=t;
  }
}

// ---- Live check (red field + message), run while typing ----
var CHECKED=['d','pitch','length_tige','length_ecrou','length_taraud','gap',
             'chamfer_height','max_overhang_angle','min_core_pct','n_theta'];
function check(){
  var bad={}, msg='';
  function req(ok,ids,m){ if(ok)return; each(ids,function(id){bad[id]=1;}); if(!msg)msg=m; }
  var d=num('d'), p=num('pitch');
  var tige=g('create_tige').checked, nut=g('create_ecrou').checked, tap=g('create_taraud').checked;
  req(tige||nut||tap,[],'Check at least one part.');
  req(d>0,['d'],'D must be > 0.');
  req(p>0,['pitch'],'Pitch P must be > 0.');
  if(d>0&&p>0) req(p<d/2,['pitch'],'Pitch P must be < D / 2.');
  if(tige) req(num('length_tige')>0,['length_tige'],'Rod height must be > 0.');
  if(nut)  req(num('length_ecrou')>0,['length_ecrou'],'Nut height must be > 0.');
  if(tap)  req(num('length_taraud')>0,['length_taraud'],'Tap thread length must be > 0.');
  if(nut||tap){
    var gp=num('gap');
    req(gp>=0,['gap'],'Gap must be ≥ 0.');
    if(d>0&&gp>=0) req(gp<d/4,['gap'],'Gap must be < D / 4.');
  }
  if(g('chamfer').checked){
    var ch=num('chamfer_height');
    req(ch>0,['chamfer_height'],'Chamfer height must be > 0.');
    if(tige&&ch>0) req(ch<num('length_tige'),['chamfer_height','length_tige'],'Chamfer height must be < rod height.');
  }
  if(currentMode==='plastic'){
    var a=num('max_overhang_angle'), c=num('min_core_pct');
    req(a>=10&&a<=85,['max_overhang_angle'],'Max overhang angle must be 10–85°.');
    req(c>=10&&c<=99,['min_core_pct'],'Min. core must be 10–99 % of D.');
  }
  var n=num('n_theta');
  req(n>=6&&n<=120,['n_theta'],'Segments / turn must be 6–120.');
  each(CHECKED,function(id){setCls(g(id),'bad',!!bad[id]);});
  g('err').textContent=msg;
  return !msg;
}

// ---- Mode, parts, chamfer ----
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
    // FDM: chamfer height default = P/2
    g('chamfer_height').value=s.chamfer_height||((s.pitch/2).toFixed(2));
    g('m_size').value='custom';
    g('max_overhang_angle').value=s.max_overhang_angle||60;
    g('min_core_pct').value=s.min_core_pct||70;
  }
}

function applyMode(){
  var f=(currentMode==='plastic');
  setCls(g('b-iso'),'sel',!f); setCls(g('b-fdm'),'sel',f);
  showSel('.v-iso',!f); showSel('.v-fdm',f);
  g('max_overhang_angle').style.display=f?'':'none';
  g('min_core_pct').style.display=f?'':'none';
  g('m_row').style.visibility=f?'hidden':'visible';
}

function setMode(m){
  if(m===currentMode) return;
  saveModeState(currentMode);
  currentMode=m;
  applyMode();
  loadModeState(m);
  refresh();
}

function setPart(chk,field,grp){
  var on=g(chk).checked;
  g(field).disabled=!on;
  g(grp).style.opacity=on?'1':'0.3';
  return on;
}

function onCreateChange(){
  setPart('create_tige','length_tige','d-create_tige');
  var nut=setPart('create_ecrou','length_ecrou','d-create_ecrou');
  var tap=setPart('create_taraud','length_taraud','d-create_taraud');
  var needGap=nut||tap;
  g('gap').disabled=!needGap;
  g('d-gap').style.opacity=needGap?'1':'0.3';
  g('tap_color_row').style.opacity=tap?'1':'0.38';
  g('tap_color_row').style.pointerEvents=tap?'auto':'none';
  updateNutHeightHint();
  check();
}

function onChamferChange(){
  var on=g('chamfer').checked;
  showSel('.ch-on',on); showSel('.ch-off',!on);
  g('chamfer_height').style.display=on?'':'none';
  check();
}

function setSwatchColor(hex){
  var sw=g('tap_color_swatch');
  sw.style.background=hex||'';
  sw.className=hex?'color-swatch':'color-swatch color-none';
  g('tap_color').value=hex||'';
  each(document.querySelectorAll('.tapc'),function(e){e.setAttribute('fill',hex||'#eeeeee');});
}

function tapColorClick(){ send('pick_tap_color',''); }

function onTapColorPicked(hex){ setSwatchColor(hex); }

function onTapColorNoSelection(){
  g('err').textContent='Select an object with a material first, then click the swatch.';
}

function onGapChange(){
  modeStates[currentMode].gap = fv('gap');
  send('save_gap', JSON.stringify({iso_gap:modeStates.iso.gap, plastic_gap:modeStates.plastic.gap}));
}

function onPitchChange(){
  if(currentMode==='plastic'){
    var p=fv('pitch')||1.0;
    g('chamfer_height').value=(p/2).toFixed(2);
  }
}

function updateNutHeightHint(){
  var el=g('nut_height_hint');
  var hasNut=g('create_ecrou').checked;
  if(currentMode!=='plastic'||!hasNut){el.innerHTML='&nbsp;';return;}
  var ratio=(fv('length_ecrou')||8)/(fv('pitch')||1.0);
  el.textContent=(ratio<3?'⚠ ':'✓ ')+ratio.toFixed(1)+'×P';
  el.style.color=ratio<3?'#c00':'#2a7';
}

function onMSize(){
  var m=g('m_size').value;
  if(!ISO[m])return;
  g('d').value=ISO[m].d;
  g('pitch').value=ISO[m].p;
  g('chamfer_height').value=ISO[m].p;
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
}

function onNTheta(){
  var n=iv('n_theta');
  var adj=Math.round(n/6)*6;
  if(adj<6)adj=6;
  if(adj>120)adj=120;
  g('n_theta').value=adj;
  g('nth_hint').textContent=(adj!==n)?('(adjusted to '+adj+')'):' ';
}

function refresh(){
  updateNutHeightHint();
  setTips();
  check();
  show(focusKey);
}

function initForm(s){
  if(s){
    // Per-mode states from the saved data
    if(s.iso)     for(var k in s.iso)     modeStates.iso[k]=s.iso[k];
    if(s.plastic) for(var k2 in s.plastic) modeStates.plastic[k2]=s.plastic[k2];
    if(s.profile_type!==undefined) currentMode=(s.profile_type==='plastic')?'plastic':'iso';
    // Mode-independent params
    if(s.create_tige!==undefined)   g('create_tige').checked=s.create_tige;
    if(s.create_ecrou!==undefined)  g('create_ecrou').checked=s.create_ecrou;
    if(s.create_taraud!==undefined) g('create_taraud').checked=s.create_taraud;
    if(s.length_tige!==undefined)   g('length_tige').value=s.length_tige;
    if(s.length_ecrou!==undefined)  g('length_ecrou').value=s.length_ecrou;
    if(s.length_taraud!==undefined) g('length_taraud').value=s.length_taraud;
    if(s.chamfer!==undefined)       g('chamfer').checked=s.chamfer;
    if(s.n_theta!==undefined)       g('n_theta').value=s.n_theta;
  }
  applyMode();
  loadModeState(currentMode);
  setSwatchColor(s?(s.tap_color||''):'');
  onCreateChange();
  onChamferChange();
  refresh();
}

function doGenerate(place){
  onNTheta();
  if(!check()) return;
  var d=fv('d'),pitch=fv('pitch'),gap=fv('gap'),nth=iv('n_theta');
  saveModeState(currentMode);
  var p={
    profile_type:currentMode,
    iso:modeStates.iso,
    plastic:modeStates.plastic,
    m_size:g('m_size').value,
    d:d, pitch:pitch,
    length_tige:fv('length_tige'), length_ecrou:fv('length_ecrou'), length_taraud:fv('length_taraud'),
    create_tige:g('create_tige').checked, create_ecrou:g('create_ecrou').checked,
    create_taraud:g('create_taraud').checked,
    gap:gap,
    chamfer:g('chamfer').checked,
    chamfer_height:fv('chamfer_height')||pitch||1.5,
    n_theta:nth,
    max_overhang_angle:fv('max_overhang_angle')||60,
    min_core_pct:fv('min_core_pct')||70,
    tap_color:g('tap_color').value,
    place_with_mouse:!!place
  };
  // Ruby closes the dialog, then generates (reopens it on failure)
  send('generate', JSON.stringify(p));
}

// ---- Events ----
function on(id,ev,fn){ g(id).addEventListener(ev,fn); }
on('b-iso','click',function(){setMode('iso');});
on('b-fdm','click',function(){setMode('plastic');});
on('m_size','change',function(){onMSize();refresh();});
on('d','change',function(){onDChange();refresh();});
on('pitch','change',function(){onPitchChange();refresh();});
on('n_theta','change',function(){onNTheta();check();});
on('gap','input',onGapChange);
on('gap','change',onGapChange);
each(CHECKED,function(id){ on(id,'input',refresh); });
each(['create_tige','create_ecrou','create_taraud'],function(id){ on(id,'click',function(){onCreateChange();refresh();}); });
on('chamfer','click',onChamferChange);
on('tap_color_swatch','click',tapColorClick);
on('tap_color_clr','click',function(){setSwatchColor('');});
on('b-close','click',function(){send('close_dialog','');});
on('btn','click',function(){doGenerate(false);});
on('place_with_mouse','click',function(){doGenerate(true);});

// Debug resize: prints the content size in the Ruby console
window.addEventListener('resize', function(){ send('log_size', window.innerWidth+'x'+window.innerHeight); });
window.onload = function(){ wireHelp(); initForm(SAVED); };
</script>
</body>
</html>
HTML

    # -------------------------------------------------------------------------
    # Cross-section drawing (fixed 440 x 300 px, not to scale)
    # -------------------------------------------------------------------------
    # Pitch of the drawn threads, in px.
    SVG_P = 16

    # One side of a drawn thread outline, as [x, y] points from ya to yb.
    # xc / xr: x at the crest / at the root; y0: y of a crest (thread phase);
    # fdm: flat-root profile instead of the ISO V.
    def self.thread_side(xc, xr, ya, yb, y0, fdm)
      prof = fdm ? [[0, 0.0], [5, 1.0], [11, 1.0], [16, 0.0]] : [[0, 0.0], [8, 1.0], [16, 0.0]]
      x_at = lambda do |y|
        t = (y - y0) % SVG_P
        r = 0.0
        prof.each_cons(2) do |(a, fa), (b, fb)|
          next unless t >= a && t <= b
          r = fa + (fb - fa) * (t - a) / (b - a).to_f
          break
        end
        (xc + (xr - xc) * r).round(1)
      end
      ys = [ya, yb]
      k = ((ya - y0) / SVG_P.to_f).floor
      while y0 + k * SVG_P <= yb
        prof.each do |o, _|
          y = y0 + k * SVG_P + o
          ys << y if y > ya && y < yb
        end
        k += 1
      end
      ys.uniq.sort.map { |y| [x_at.call(y), y] }
    end

    def self.pts(list)
      list.map { |x, y| "#{x},#{y}" }.join(' L')
    end

    # Rod, nut and tap outlines for one profile (ISO or FDM).
    def self.svg_parts(fdm)
      cut = "fill='#ffe5cc' stroke='#8a6d4f'"
      rod = "M#{pts(thread_side(62, 70, 62, 254, 62, fdm))} L#{pts(thread_side(108, 100, 62, 254, 62, fdm).reverse)}"
      nut_l = "M180,118 L#{pts(thread_side(204, 212, 118, 206, 62, fdm))} L180,206 Z"
      nut_r = "M290,118 L#{pts(thread_side(266, 258, 118, 206, 62, fdm))} L290,206 Z"
      in_l  = pts(thread_side(212, 220, 118, 206, 62, fdm))
      in_r  = pts(thread_side(258, 250, 118, 206, 62, fdm))
      tap   = "M392,56 L408,56 L408,72 L413,72 L413,104 " \
              "L#{pts(thread_side(420, 413, 104, 232, 104, fdm))} L400,250 " \
              "L#{pts(thread_side(380, 387, 104, 232, 104, fdm).reverse)} L387,104 L387,72 L392,72 Z"
      {
        rod: "<path d='#{rod}' #{cut}/>",
        nut: "<path d='#{nut_l}' fill='#efe3d0'/><path d='#{nut_l}' fill='url(#hatch)' stroke='#8a6d4f'/>" \
             "<path d='#{nut_r}' fill='#efe3d0'/><path d='#{nut_r}' fill='url(#hatch)' stroke='#8a6d4f'/>" \
             "<path d='M#{in_l}' fill='none' stroke='#8a6d4f' stroke-dasharray='3 2'/>" \
             "<path d='M#{in_r}' fill='none' stroke='#8a6d4f' stroke-dasharray='3 2'/>",
        tap: "<path class='tapc' d='#{tap}' fill='#eeeeee' stroke='#666'/>"
      }
    end

    # Each <g class="dim"> has the id "d-<key>" and is highlighted (class "on")
    # while the matching field is hovered or edited. Classes v-iso / v-fdm follow
    # the thread type, ch-on / ch-off the lead-in chamfer checkbox.
    def self.schematic_svg
      # vertical dimension with end ticks
      vd = lambda do |x, y1, y2|
        "<line x1='#{x}' y1='#{y1}' x2='#{x}' y2='#{y2}'/>" \
        "<line x1='#{x - 5}' y1='#{y1}' x2='#{x + 5}' y2='#{y1}'/>" \
        "<line x1='#{x - 5}' y1='#{y2}' x2='#{x + 5}' y2='#{y2}'/>"
      end
      # horizontal dimension with end ticks at x1 and x2, line drawn from lx to rx
      hd = lambda do |x1, x2, y, lx = x1, rx = x2|
        "<line x1='#{lx}' y1='#{y}' x2='#{rx}' y2='#{y}'/>" \
        "<line x1='#{x1}' y1='#{y - 5}' x2='#{x1}' y2='#{y + 5}'/>" \
        "<line x1='#{x2}' y1='#{y - 5}' x2='#{x2}' y2='#{y + 5}'/>"
      end
      iso = svg_parts(false)
      fdm = svg_parts(true)
      cut = "fill='#ffe5cc' stroke='#8a6d4f'"
      <<-SVG
<svg viewBox="0 0 440 300" width="440" height="300" xmlns="http://www.w3.org/2000/svg">
 <defs>
  <pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
   <line x1="0" y1="0" x2="0" y2="6" stroke="#c4ae8e" stroke-width="1.2"/>
  </pattern>
 </defs>
 <g class="dim" id="d-create_tige">
  <g class="v-iso">#{iso[:rod]}</g><g class="v-fdm">#{fdm[:rod]}</g>
  <path class="ch-off" d="M62,62 L62,50 L108,50 L108,62" #{cut}/>
  <path class="ch-on" d="M62,62 L70,50 L100,50 L108,62" #{cut}/>
  <g class="dim" id="d-length_tige">#{vd.call(46, 50, 254)}<text x="4" y="138">height</text></g>
 </g>
 <g class="dim" id="d-d">#{hd.call(62, 108, 40, 54, 108)}<text x="11" y="44" text-anchor="end">&#216;</text></g>
 <g class="dim v-fdm" id="d-max_overhang_angle">
  <line x1="108" y1="110" x2="108" y2="130" stroke-dasharray="2 2"/>
  <path class="d" d="M108,122 A12,12 0 0 1 97.8,116.4"/>
  <line x1="104" y1="121" x2="124" y2="121"/><text x="124" y="108">&#945; max (&#176;)</text>
 </g>
 <g class="dim" id="d-pitch">#{vd.call(118, 158, 174)}<line x1="118" y1="166" x2="124" y2="166"/><text x="124" y="154">P</text></g>
 <g class="dim v-fdm" id="d-min_core_pct">
  <line x1="70" y1="254" x2="70" y2="272" stroke-dasharray="2 2"/><line x1="100" y1="254" x2="100" y2="272" stroke-dasharray="2 2"/>
  #{hd.call(70, 100, 266, 70, 108)}<text x="152" y="270">% D core</text>
 </g>
 <g class="dim" id="d-create_ecrou">
  <g class="v-iso">#{iso[:nut]}</g><g class="v-fdm">#{fdm[:nut]}</g>
  <g class="dim" id="d-length_ecrou">#{vd.call(300, 118, 206)}<text x="306" y="149">height</text></g>
 </g>
 <g class="dim ch-on" id="d-chamfer_height">
  #{vd.call(118, 50, 62)}<line x1="118" y1="56" x2="124" y2="56"/><text x="124" y="44">chamfer</text>
  <path d="M196,118 L212,118 L212,134 Z M274,118 L258,118 L258,134 Z M196,206 L212,206 L212,190 Z M274,206 L258,206 L258,190 Z" fill="#fafafa"/>
  <line x1="196" y1="118" x2="212" y2="134"/><line x1="274" y1="118" x2="258" y2="134"/>
  <line x1="196" y1="206" x2="212" y2="190"/><line x1="274" y1="206" x2="258" y2="190"/>
 </g>
 <g class="dim" id="d-gap">#{hd.call(204, 212, 158)}<text x="216" y="145">gap</text></g>
 <g class="dim" id="d-create_taraud">
  <g class="v-iso">#{iso[:tap]}</g><g class="v-fdm">#{fdm[:tap]}</g>
  <g class="dim" id="d-length_taraud">#{vd.call(430, 104, 250)}<line x1="430" y1="250" x2="430" y2="266"/><text x="388" y="279" text-anchor="end">height</text></g>
 </g>
</svg>
      SVG
    end

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
          'chamfer_height'     => Sketchup.read_default(PREF_KEY, 'plastic_chamfer_height',    fdm_pitch / 2.0).to_f,
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
      HTML_TEMPLATE.sub('__SVG__') { schematic_svg }.sub('__SAVED_JSON__') { defs.to_json }
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
        preferences_key: DLG_PREF_KEY,
        width:  DLG_WIDTH,
        height: DLG_HEIGHT,
        min_width:  300,
        min_height: 400,
        style: UI::HtmlDialog::STYLE_DIALOG
      )
      dlg.set_html(build_html(read_defaults))
      dlg.add_action_callback('generate') do |_ctx, json_str|
        handle_generate(json_str, dlg)
      end
      dlg.add_action_callback('save_gap') do |_ctx, json_str|
        begin
          data = JSON.parse(json_str)
          Sketchup.write_default(PREF_KEY, 'iso_gap',     data['iso_gap'].to_f)     if data.key?('iso_gap')
          Sketchup.write_default(PREF_KEY, 'plastic_gap', data['plastic_gap'].to_f) if data.key?('plastic_gap')
        rescue; end
      end
      dlg.add_action_callback('pick_tap_color') do |_ctx, _|
        pick_tap_color(dlg)
      end
      dlg.add_action_callback('log_size') do |_ctx, dims|
        puts "[VFG] Dialog content size: #{dims}"
      end
      dlg.add_action_callback('close_dialog') do |_ctx, _|
        dlg.close
      end
      dlg.show
    end

    def self.show_web_dialog
      dlg = UI::WebDialog.new(DIALOG_TITLE, true, DLG_PREF_KEY, DLG_WIDTH, DLG_HEIGHT, 100, 100, true)
      dlg.set_html(build_html(read_defaults))
      dlg.add_action_callback('generate') do |_dlg, encoded|
        begin
          json_str = CGI.unescape(encoded.to_s)
          handle_generate(json_str, dlg)
        rescue => e
          UI.messagebox("Decode error: #{e.message}", MB_OK)
          show
        end
      end
      dlg.add_action_callback('save_gap') do |_dlg, encoded|
        begin
          data = JSON.parse(CGI.unescape(encoded.to_s))
          Sketchup.write_default(PREF_KEY, 'iso_gap',     data['iso_gap'].to_f)     if data.key?('iso_gap')
          Sketchup.write_default(PREF_KEY, 'plastic_gap', data['plastic_gap'].to_f) if data.key?('plastic_gap')
        rescue; end
      end
      dlg.add_action_callback('pick_tap_color') do |_dlg, _|
        pick_tap_color(dlg)
      end
      dlg.add_action_callback('log_size') do |_dlg, dims|
        puts "[VFG] Dialog content size: #{CGI.unescape(dims.to_s)}"
      end
      dlg.add_action_callback('close_dialog') do |_dlg, _|
        dlg.close
      end
      dlg.show
    end

    # Sends the material color of the first selected entity back to the dialog.
    def self.pick_tap_color(dlg)
      sel = Sketchup.active_model.selection.first
      return dlg.execute_script('onTapColorNoSelection()') unless sel
      if sel.respond_to?(:material) && sel.material
        c = sel.material.color
        hex = '#%02X%02X%02X' % [c.red, c.green, c.blue]
        dlg.execute_script("onTapColorPicked('#{hex}')")
      else
        dlg.execute_script("onTapColorPicked('')")
      end
    end

    # Closes the dialog, then generates behind a small busy window.
    # On failure the dialog reopens with the saved parameters.
    def self.handle_generate(json_str, dlg)
      dlg.close
      with_busy_window { run_generate(json_str) }
    end

    # Content of the busy window. SketchUp is blocked during the generation,
    # so it is static. ready() is sent once the page is painted.
    BUSY_HTML = <<'HTML'
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
html,body{margin:0;height:100%;background:#fff;font:13px Segoe UI,Helvetica,Arial,sans-serif;color:#222;overflow:hidden}
body{display:flex;align-items:center;justify-content:center}
b{color:#2e8b57}
</style></head><body><div>&#9203; <b>Generating…</b> please wait</div>
<script>window.onload=function(){setTimeout(function(){sketchup.ready();},50);};</script>
</body></html>
HTML

    # Shows the busy window, runs the block once the window is painted, then
    # closes it. The window never keeps the focus: SketchUp gets it back at
    # once (Esc goes to the model). Without HtmlDialog (SU < 2017): no window.
    def self.with_busy_window(&block)
      # Stop each timer at once: a messagebox inside a non-repeating timer
      # can make it repeat
      unless defined?(UI::HtmlDialog)
        t0 = UI.start_timer(0.1, false) { UI.stop_timer(t0); block.call }
        return
      end
      busy = UI::HtmlDialog.new(
        dialog_title: DIALOG_TITLE,
        width: 300, height: 100,
        resizable: false, scrollable: false,
        style: UI::HtmlDialog::STYLE_UTILITY
      )
      busy.set_html(BUSY_HTML)
      started = false
      run = lambda do
        next if started
        started = true
        begin
          block.call
        ensure
          busy.close
          Sketchup.focus if Sketchup.respond_to?(:focus)
        end
      end
      busy.add_action_callback('ready') do |_ctx, _|
        t1 = UI.start_timer(0.05, false) { UI.stop_timer(t1); run.call }
      end
      # Safety net: generate anyway if ready() never comes
      t2 = UI.start_timer(1.0, false) { UI.stop_timer(t2); run.call }
      busy.center
      busy.show
      Sketchup.focus if Sketchup.respond_to?(:focus)
    end

    def self.run_generate(json_str)
      show_wait_cursor
      params = JSON.parse(json_str)
      save_defaults(params)
      groups = Geometry.generate(params, Sketchup.active_model)
      if groups.nil? || groups.empty?
        show
      elsif params['place_with_mouse']
        tap_depth = params['create_taraud'] ? params['length_taraud'].to_f * Geometry.unit_factor : 0.0
        Sketchup.active_model.select_tool(PlaceTool.new(groups, tap_depth))
      else
        PlaceTool.select_and_zoom(groups)
      end
    rescue JSON::ParserError => e
      UI.messagebox("JSON error: #{e.message}", MB_OK)
      show
    end

    # Windows only: shows the busy cursor while SketchUp is blocked by the
    # generation (the closed dialog no longer shows it). SketchUp is blocked,
    # so the cursor stays until the end, then SketchUp restores it by itself.
    # No-op on other platforms or on any error.
    IDC_WAIT = 32514
    def self.show_wait_cursor
      return unless Sketchup.platform == :platform_win
      require 'fiddle'
      user32      = Fiddle::Handle.new('user32')
      load_cursor = Fiddle::Function.new(user32['LoadCursorW'],
                                         [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
      set_cursor  = Fiddle::Function.new(user32['SetCursor'],
                                         [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
      set_cursor.call(load_cursor.call(nil, IDC_WAIT))
    rescue StandardError, LoadError
      nil
    end

    private_class_method :read_defaults, :save_defaults, :detect_tap_color, :build_html,
                         :show_html_dialog, :show_web_dialog, :handle_generate,
                         :thread_side, :pts, :svg_parts, :schematic_svg, :pick_tap_color,
                         :run_generate, :show_wait_cursor, :with_busy_window

  end
end
