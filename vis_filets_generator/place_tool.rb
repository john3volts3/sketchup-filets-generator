# vis_filets_generator/place_tool.rb
# Placement of the freshly generated parts (created at the model origin).
#
# PlaceTool: an orange box per part follows the mouse (SketchUp inference on
# points, edges and faces); a click moves the parts there in one undo step.
# On a face, the parts are turned perpendicular to it (Z axis = face normal):
# rod and nut stand on the face, the tap is sunk into it by its threaded
# length (subtract it to get a threaded hole). Off a face: vertical, as built. The real parts only move on the click, so the inference never
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

    # tap_depth: threaded length of the tap (model length), the tap is sunk
    # by this depth into the face.
    # on_done: optional proc called once when the placement is over (click or cancel)
    def initialize(groups, tap_depth = 0.0, &on_done)
      @on_done   = on_done
      @groups    = groups.select(&:valid?)
      @tap_depth = tap_depth.to_f
      @ip        = Sketchup::InputPoint.new
      @done      = false
      # Box corners of each part, in the generation frame (origin, world axes)
      @corners = @groups.map { |g| (0..7).map { |i| g.bounds.corner(i) } }
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
      model = Sketchup.active_model
      trans = part_transformations
      # Transparent: merged with the generation, one Ctrl+Z removes the parts
      model.start_operation('Place Thread Parts', true, false, true)
      @groups.each_with_index { |g, i| g.transform!(trans[i]) if g.valid? }
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
      view.drawing_color = 'orange'
      view.line_width    = 2
      boxes_points.each do |pts|
        view.draw(GL_LINES, BOX_EDGES.flatten.map { |i| pts[i] })
      end
    end

    def getExtents
      bb = Sketchup.active_model.bounds
      boxes_points.each { |pts| pts.each { |p| bb.add(p) } } if @ip.valid?
      bb
    end

    private

    # Corner index pairs of the 12 box edges (BoundingBox#corner numbering)
    BOX_EDGES = [[0, 1], [1, 3], [3, 2], [2, 0], [4, 5], [5, 7], [7, 6], [6, 4],
                 [0, 4], [1, 5], [2, 6], [3, 7]].freeze

    # Placement frame at the input point: Z = normal of the face under the
    # mouse (also inside groups/components), X = model red axis projected on
    # the face. No face: world axes. Returns [transformation, on_face].
    def placement
      pt   = @ip.position
      face = @ip.face
      return [Geom::Transformation.translation(pt - ORIGIN), false] unless face
      z = face.normal.transform(@ip.transformation)
      return [Geom::Transformation.translation(pt - ORIGIN), false] unless z.valid?
      z.normalize!
      ref = z.parallel?(X_AXIS) ? Y_AXIS : X_AXIS
      x = Geom::Vector3d.linear_combination(1.0, ref, -ref.dot(z), z)
      x.normalize!
      y = z * x
      [Geom::Transformation.axes(pt, x, y, z), true]
    end

    def tap?(group)
      group.name.to_s.start_with?('Tap ')
    end

    # Transformation of each part: placement frame, tap sunk into the face
    def part_transformations
      t, on_face = placement
      @groups.map do |g|
        if on_face && tap?(g) && @tap_depth > 0
          t * Geom::Transformation.translation(Geom::Vector3d.new(0, 0, -@tap_depth))
        else
          t
        end
      end
    end

    def boxes_points
      trans = part_transformations
      @corners.each_with_index.map { |pts, i| pts.map { |p| p.transform(trans[i]) } }
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
