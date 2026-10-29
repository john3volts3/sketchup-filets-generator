# vis_filets_generator/place_tool.rb
# Placement of the freshly generated parts (created at the model origin).
#
# PlaceTool: an orange cylinder per part (bottom and top circles, outline seen
# from the camera, dashed axis) follows the mouse (SketchUp inference on
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
      # Bounding cylinder of each part, in the generation frame (origin, world axes)
      @cylinders = @groups.map { |g| bounding_cylinder(g.bounds) }
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
      placed_cylinders.each do |cyl|
        view.line_width   = 2
        view.line_stipple = ''
        cyl[:rings].each { |pts| view.draw(GL_LINE_LOOP, pts) }
        outline = silhouette_lines(view, cyl)
        view.draw(GL_LINES, outline) unless outline.empty?
        axis = axis_line(cyl)
        next if axis.empty?
        view.line_width   = 1
        view.line_stipple = '-'
        view.draw(GL_LINES, axis)
      end
      view.line_stipple = ''
    end

    def getExtents
      bb = Sketchup.active_model.bounds
      if @ip.valid?
        placed_cylinders.each do |cyl|
          (cyl[:rings].flatten + axis_line(cyl)).each { |p| bb.add(p) }
        end
      end
      bb
    end

    private

    # Number of segments of the preview circles
    SEGMENTS = 24

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

    # Bounding cylinder of a part built along the Z axis: centers of the bottom
    # and top of its box, radius = half of the box widest side (hex nut: circle
    # through its corners; the tap square is inscribed in its shank).
    def bounding_cylinder(bb)
      c   = bb.center
      r   = [bb.width, bb.height].max / 2.0
      bot = Geom::Point3d.new(c.x, c.y, bb.min.z)
      top = Geom::Point3d.new(c.x, c.y, bb.max.z)
      { bot: bot, top: top, r: r, rings: [ring_points(bot, r), ring_points(top, r)] }
    end

    # Circle of radius r around a vertical axis, in the generation frame
    def ring_points(center, r)
      (0...SEGMENTS).map do |k|
        a = 2.0 * Math::PI * k / SEGMENTS
        Geom::Point3d.new(center.x + r * Math.cos(a), center.y + r * Math.sin(a), center.z)
      end
    end

    # Bounding cylinders moved by the transformation of each part (rigid: the
    # radius is kept)
    def placed_cylinders
      trans = part_transformations
      @cylinders.each_with_index.map do |cyl, i|
        t = trans[i]
        { bot: cyl[:bot].transform(t), top: cyl[:top].transform(t), r: cyl[:r],
          rings: cyl[:rings].map { |pts| pts.map { |p| p.transform(t) } } }
      end
    end

    # Outline of the cylinder seen from the camera: the 2 generatrices tangent
    # to the view rays. Empty when the eye is inside the cylinder.
    def silhouette_lines(view, cyl)
      bot, top, r = cyl[:bot], cyl[:top], cyl[:r]
      axis = top - bot
      return [] unless axis.valid?
      axis.normalize!
      cam    = view.camera
      to_eye = cam.perspective? ? cam.eye - bot : cam.direction.reverse
      # Component of the eye direction perpendicular to the axis
      u = Geom::Vector3d.linear_combination(1.0, to_eye, -to_eye.dot(axis), axis)
      return [] unless u.valid?
      if cam.perspective?
        dist = u.length.to_f
        return [] if dist <= r
        cos_a = r / dist   # tangent point seen from the eye
      else
        cos_a = 0.0        # parallel rays: tangent at 90 degrees
      end
      sin_a = Math.sqrt(1.0 - cos_a * cos_a)
      u.normalize!
      w = axis * u
      [1.0, -1.0].flat_map do |s|
        off = Geom::Vector3d.linear_combination(r * cos_a, u, s * r * sin_a, w)
        [bot.offset(off), top.offset(off)]
      end
    end

    # Axis of the cylinder, overhanging both ends by half the radius
    def axis_line(cyl)
      axis = cyl[:top] - cyl[:bot]
      return [] unless axis.valid?
      ext = cyl[:r] / 2.0
      [cyl[:bot].offset(axis.reverse, ext), cyl[:top].offset(axis, ext)]
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
