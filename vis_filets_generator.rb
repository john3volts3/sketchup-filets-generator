# vis_filets_generator.rb
# Loader principal — enregistre l'extension SketchUp
# Compatible SketchUp 2014+ (Ruby 2.0+)

require 'sketchup.rb'
require 'extensions.rb'

module VisFiletsGenerator
  VERSION    = '1.9.2'.freeze
  PLUGIN_DIR = File.dirname(__FILE__).freeze

  extension = SketchupExtension.new(
    'Vis & Filets',
    File.join(PLUGIN_DIR, 'vis_filets_generator', 'main')
  )
  extension.version     = VERSION
  extension.copyright   = '2026'
  extension.description = 'Parametric generator for threaded rods, hex nuts and taps. ' \
                          'ISO metric and FDM 3D-printing optimised profiles.'
  Sketchup.register_extension(extension, true)
end
