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
    menu.add_item('Generer...') { DialogManager.show }

  end
end
