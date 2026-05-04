# vis_filets_generator/main.rb
# Point d'entree : menu Extensions, guard de chargement unique

module VisFiletsGenerator
  unless @loaded
    @loaded = true

    require File.join(PLUGIN_DIR, 'vis_filets_generator', 'presets')
    require File.join(PLUGIN_DIR, 'vis_filets_generator', 'profiles')
    require File.join(PLUGIN_DIR, 'vis_filets_generator', 'geometry')
    require File.join(PLUGIN_DIR, 'vis_filets_generator', 'dialog')

    menu = UI.menu('Extensions').add_submenu('Vis & Filets')
    menu.add_item('Generate…') { DialogManager.show }

    # Toolbar
    icons_dir = File.join(PLUGIN_DIR, 'vis_filets_generator', 'icons')
    cmd = UI::Command.new('Vis & Filets') { DialogManager.show }
    cmd.small_icon      = File.join(icons_dir, 'vfg_16.png')
    cmd.large_icon      = File.join(icons_dir, 'vfg_24.png')
    cmd.tooltip         = 'Vis & Filets — Generate thread parts'
    cmd.status_bar_text = 'Generate threaded rod, hex nut or tap'

    toolbar = UI::Toolbar.new('Vis & Filets')
    toolbar.add_item(cmd)
    toolbar.restore

  end
end
