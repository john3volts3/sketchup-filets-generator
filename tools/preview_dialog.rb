# Browser preview of the Vis & Filets parameter dialog, without SketchUp.
#
# Loads vis_filets_generator/dialog.rb with a minimal stub of the SketchUp API,
# captures the HTML given to UI::HtmlDialog#set_html, adds a fake `sketchup`
# object (callbacks only print a message) and opens the page in the default browser.
#
# Usage (from the project root):
#   ruby tools/preview_dialog.rb [iso|fdm] [--all] [--no-open]
#   --all: every part and the lead-in chamfer checked
# Output: <system temp dir>/vfg_preview.html (reload with F5 after a re-run).

require 'tmpdir'

MODE      = ARGV.include?('fdm') ? 'plastic' : 'iso'
OPEN      = !ARGV.include?('--no-open')
ALL       = ARGV.include?('--all')
OUTPUT    = File.join(Dir.tmpdir, 'vfg_preview.html')
DIALOG_RB = File.expand_path('../vis_filets_generator/dialog.rb', __dir__)

# --- Minimal SketchUp API stub -------------------------------------------------
module Sketchup
  # Default values everywhere, except the profile chosen on the command line.
  def self.read_default(_section, key, default)
    return MODE if key == 'profile_type'
    return true if ALL && %w[create_tige create_ecrou create_taraud chamfer].include?(key)
    default
  end

  def self.write_default(*); end
  def self.active_model; Object.new; end
end

module UI
  class Stub
    def initialize(*); end
    def method_missing(*) self end
    def respond_to_missing?(*) true end
  end

  class HtmlDialog < Stub
    STYLE_DIALOG = 0
    def set_html(html)
      $captured_html = html
    end
  end
end

# --- Render ----------------------------------------------------------------------
load DIALOG_RB
VisFiletsGenerator::DialogManager.show
abort '[preview] no HTML captured' unless $captured_html

fake = '<script>window.sketchup={' \
       'generate:function(j){console.log(j);document.getElementById("err").textContent="Preview: generate OK (JSON in console)";},' \
       'save_gap:function(j){console.log("save_gap",j);},' \
       'pick_tap_color:function(){var c=["#3C8DDA","#D9534F",null,"#5CB85C"][(window.__pk=(window.__pk||0)+1)%4];' \
       'if(c)onTapColorPicked(c);else onTapColorNoSelection();},' \
       'log_size:function(s){console.log("size",s);},' \
       'close_dialog:function(){document.getElementById("err").textContent="Preview: close";}};</script></head>'
banner = '<body><div style="font:11px Segoe UI,Arial;color:#888;margin-bottom:6px">' \
         'PREVIEW - callbacks inactive</div>'
html = $captured_html.sub('</head>') { fake }.sub(/<body>/) { banner }
File.write(OUTPUT, html)
puts "[preview] #{OUTPUT}"

if OPEN
  # .html files may be associated with Edge even when Firefox is the default
  # web browser: use Firefox explicitly when it is installed.
  firefox = [ENV['ProgramFiles'], ENV['ProgramFiles(x86)']].compact
                                                           .map { |d| File.join(d, 'Mozilla Firefox', 'firefox.exe') }
                                                           .find { |f| File.exist?(f) }
  if Gem.win_platform? && firefox
    system(firefox, OUTPUT)
  elsif Gem.win_platform?
    system('cmd', '/c', 'start', '', OUTPUT)
  elsif RUBY_PLATFORM.include?('darwin')
    system('open', OUTPUT)
  else
    system('xdg-open', OUTPUT)
  end
end
