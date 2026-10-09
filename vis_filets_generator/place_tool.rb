# vis_filets_generator/place_tool.rb
# Placement of the freshly generated parts (created at the model origin).
#
# PlaceTool: an orange box the size of the parts follows the mouse (SketchUp
# inference on points, edges and faces); a click moves the parts there in one
# undo step. The real parts only move on the click, so the inference never
# snaps onto the parts being placed. Esc, right-click or another tool cancels:
# the generation is undone, as if the button had never been clicked.

module VisFiletsGenerator
  class PlaceTool

    STATUS = 'Vis & Filets — Click to place the parts. Esc or right-click: cancel.'.freeze

    # Placement in progress? (Tools#active_tool only exists since SU 2019)
    def self.active?
      @active == true
    end

    def self.active=(value)
      @active = value
    end

    # Selects the parts and zooms on them, so they are never "lost" off-screen.
    def self.select_and_zoom(groups)
      groups = groups.select(&:valid?)
      return if groups.empty?
      model = Sketchup.active_model
      model.selection.clear
      model.selection.add(groups)
      model.active_view.zoom(groups)
    end

    # on_done: optional proc called once when the placement is over (click or cancel)
    def initialize(groups, &on_done)
      @on_done = on_done
      @groups = groups.select(&:valid?)
      @ip     = Sketchup::InputPoint.new
      @done   = false
      bb = Geom::BoundingBox.new
      @groups.each { |g| bb.add(g.bounds) }
      # Box corners relative to the origin (= base point of the parts)
      @corners = (0..7).map { |i| bb.corner(i) - ORIGIN }
    end

    def activate
      PlaceTool.active = true
      Sketchup.status_text = STATUS
    end

    def deactivate(view)
      PlaceTool.active = false
      # Tool changed without a click (Esc, right-click, other tool): cancel
      cancel_generation unless @done
      view.invalidate
    end

    def resume(_view)
      Sketchup.status_text = STATUS
    end

    def onMouseMove(_flags, x, y, view)
      @ip.pick(view, x, y)
      view.tooltip = @ip.tooltip if @ip.valid?
      view.invalidate
    end

    def onLButtonDown(_flags, x, y, view)
      @ip.pick(view, x, y)
      return unless @ip.valid?
      vec   = @ip.position - ORIGIN
      model = Sketchup.active_model
      # Transparent: merged with the generation, one Ctrl+Z removes the parts
      model.start_operation('Place Thread Parts', true, false, true)
      @groups.each { |g| g.transform!(Geom::Transformation.translation(vec)) if g.valid? }
      model.commit_operation
      @done = true
      model.selection.clear
      model.selection.add(@groups.select(&:valid?))
      Sketchup.status_text = ''
      @on_done.call if @on_done
      model.select_tool(nil)
    end

    # Right-click = cancel (the keyboard focus is often still in the dialog)
    def onRButtonDown(_flags, _x, _y, _view)
      Sketchup.active_model.select_tool(nil)
    end

    def onCancel(_reason, _view)
      Sketchup.active_model.select_tool(nil)
    end

    def draw(view)
      @ip.draw(view) if @ip.display?
      return unless @ip.valid?
      pts = box_points(@ip.position)
      view.drawing_color = 'orange'
      view.line_width    = 2
      view.draw(GL_LINES, BOX_EDGES.flatten.map { |i| pts[i] })
    end

    def getExtents
      bb = Sketchup.active_model.bounds
      box_points(@ip.position).each { |p| bb.add(p) } if @ip.valid?
      bb
    end

    private

    # Corner index pairs of the 12 box edges (BoundingBox#corner numbering)
    BOX_EDGES = [[0, 1], [1, 3], [3, 2], [2, 0], [4, 5], [5, 7], [7, 6], [6, 4],
                 [0, 4], [1, 5], [2, 6], [3, 7]].freeze

    def box_points(base)
      @corners.map { |v| base + v }
    end

    # Removes the generated parts by undoing the generation (one single undo
    # operation, see Geometry.generate): the undo stack stays clean. Deferred
    # so the undo does not run inside a tool callback.
    def cancel_generation
      return if @done
      @done = true
      Sketchup.status_text = ''
      groups = @groups
      UI.start_timer(0, false) do
        Sketchup.undo if groups.any?(&:valid?)
      end
      @on_done.call if @on_done
    end

  end
end
