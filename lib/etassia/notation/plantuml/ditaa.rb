# frozen_string_literal: true

require_relative "../../diagram/ditaa"

module Etassia
  module Notation
    module PlantUML
      # Reads PlantUML's `@startditaa` blocks: the body is an ASCII-art
      # drawing that ditaa turns into boxes, lines, arrowheads, markers and
      # text. Dispatched to from {PlantUML.parse}; the start line carries
      # the flags (`-E`, `-S`, `-r`, `-T`, `scale=`).
      module Ditaa
        HEADERS = /\A(?:\xEF\xBB\xBF)?
                   (?:[ \t\v\f\x00]*(?:'[^\r\n]*)?(?:\r\n|\r|\n))*
                   [ \t\v\f\x00]*@startditaa(?![A-Za-z0-9_])[^\r\n]*/xn
        ENDING = /@(?:endditaa|enduml)\s*\z/m
        private_constant :HEADERS, :ENDING

        FLAGS = [
          ["--no-separation", "-E", :separation, false],
          ["--no-shadows", "-S", :shadows, false],
          ["--round-corners", "-r", :round_corners, true],
          ["--transparent", "-T", :transparent, true],
        ].freeze
        private_constant :FLAGS

        module_function

        # @param source [String] PlantUML source
        # @return [Notation::Parsed]
        def parse(source)
          body = source.sub(HEADERS, "").sub(ENDING, "").gsub(/\A\n+/, "")
          start_line = HEADERS.match(source)[0]
          diagram = Etassia::Diagram::Ditaa.parse(body.lines,
                                                  options(start_line))
          Notation::Parsed.new(
            type: :ditaa_diagram, diagram: diagram,
            transform: DitaaLayout,
            renderer: DitaaRenderer
          )
        end

        # @return [Boolean] whether an @startditaa wrapper opens the source
        def ditaa?(source)
          HEADERS.match?(source.b)
        end

        # @return [Etassia::Diagram::Ditaa::Options] the start line's flags
        def options(start_line)
          defaults = Etassia::Diagram::Ditaa::DEFAULTS
          values = flag_values(start_line)
          scale = /scale=([\d.]+)/.match(start_line)
          values[:scale] = scale[1].to_f if scale
          defaults.class.new(**defaults.to_h, **values)
        end

        def flag_values(start_line)
          FLAGS.each_with_object({}) do |(long, short, key, when_set), carried|
            carried[key] = when_set if flag_set?(start_line, long, short)
          end
        end

        def flag_set?(start_line, long, short)
          start_line.include?(long) || start_line.include?(short)
        end
      end

      # Carries the builder's geometry to the renderer with the canvas and
      # the paint options it needs.
      class DitaaLayout
        LayoutResult = Struct.new(:shapes, :composites, :texts, :width,
                                  :height, :shadows, :transparent,
                                  :cell_width, :cell_height,
                                  keyword_init: true)

        def call(diagram, theme: nil, today: nil) # rubocop:disable Lint/UnusedMethodArgument
          LayoutResult.new(
            shapes: diagram.shapes, composites: diagram.composites,
            texts: diagram.texts, width: diagram.width, height: diagram.height,
            shadows: diagram.shadows, transparent: diagram.transparent,
            cell_width: diagram.cell_width, cell_height: diagram.cell_height
          )
        end
      end

      # Draws the ditaa geometry: shadows behind closed shapes, storage
      # cylinders back to front, everything else largest area first, then
      # point markers and text.
      class DitaaRenderer
        INK = "#000000"
        SHADOW_INK = "#969696"
        KAPPA = 4.0 * (Math.sqrt(2) - 1.0) / 3.0
        MAIN_KINDS = %i[point_marker storage].freeze
        Bezier = Struct.new(:c1x, :c1y, :c2x, :c2y, :x, :y)

        def initialize(theme: nil)
          @theme = theme
        end

        def render(layout_result)
          @layout = layout_result
          @min_cell = [@layout.cell_width, @layout.cell_height].min
          @stroke_weight = @min_cell / 10.0
          @dash_interval = @min_cell / 2.0
          paint_scene(Svg::Document.new(
                        width: @layout.width, height: @layout.height,
                        view_box: view_box
                      ))
        end

        def view_box
          "0 0 #{@layout.width} #{@layout.height}"
        end

        def paint_scene(svg)
          draw_background(svg) unless @layout.transparent
          draw_all = all_shapes
          draw_shadows(svg, draw_all) if @layout.shadows
          draw_storage(svg, draw_all)
          draw_shapes(svg, draw_all)
          draw_texts(svg)
          svg
        end

        private

        def all_shapes
          @layout.shapes + @layout.composites.flatten
        end

        def draw_background(svg)
          svg.add_element(Svg::Rect.new(
                            x: 0, y: 0, width: @layout.width,
                            height: @layout.height,
                            fill: "#ffffff", stroke: "none"
                          ))
        end

        def draw_shadows(svg, shapes)
          offset = @min_cell / 3.333
          shapes.each do |shape|
            next unless shadowed?(shape)

            svg.add_element(Svg::Path.new.tap do |path|
              path.d = render_path(shape)
              path.transform = "translate(#{offset},#{offset})"
              path.fill = SHADOW_INK
              path.stroke = "none"
            end)
          end
        end

        def shadowed?(shape)
          shape.closed && shape.drops_shadow? && !shape.points.empty?
        end

        def draw_storage(svg, shapes)
          ordered = with_order(shapes.select { |shape| shape.kind == :storage })
            .sort_by { |shape, order| [-center_y(shape), order] }
            .map(&:first)
          ordered.each { |shape| paint(svg, shape) }
        end

        def draw_shapes(svg, shapes)
          markers = shapes.select { |shape| shape.kind == :point_marker }
          main = shapes.reject { |shape| MAIN_KINDS.include?(shape.kind) }
          by_area(main).each { |shape| paint(svg, shape) }
          draw_point_markers(svg, markers)
        end

        def by_area(shapes)
          with_order(shapes)
            .sort_by { |shape, order| [-shape.area, order] }
            .map(&:first)
        end

        def with_order(shapes)
          shapes.each_with_index.map { |shape, order| [shape, order] }
        end

        def draw_point_markers(svg, shapes)
          shapes.each do |shape|
            point = shape.points.first
            radius = 0.7 * @min_cell / 2
            svg.add_element(Svg::Circle.new(
                              cx: point.x, cy: point.y, r: radius,
                              fill: "#ffffff", stroke: INK,
                              stroke_width: Svg::Numbers.write(@stroke_weight)
                            ))
          end
        end

        def center_y(shape)
          _, min_y, _, max_y = shape.bounds
          (min_y + max_y) / 2
        end

        def paint(svg, shape)
          d = render_path(shape)
          svg.add_element(Svg::Path.new.tap do |path|
            path.d = d
            apply_fill(path, shape)
            apply_stroke(path, shape)
          end)
        end

        def apply_fill(path, shape)
          path.fill = if shape.closed && !shape.dashed
                        shape.fill || "#ffffff"
                      else
                        "none"
                      end
        end

        def apply_stroke(path, shape)
          path.stroke = shape.stroke || INK
          path.stroke_width = Svg::Numbers.write(@stroke_weight)
          if shape.dashed
            path.stroke_dasharray = Svg::Numbers.write(@dash_interval)
          else
            path.stroke_linecap = "round"
            path.stroke_linejoin = "round"
          end
        end

        def draw_texts(svg)
          @layout.texts.each { |run| svg.add_element(text_element(run)) }
        end

        def text_element(run)
          Svg::Text.new.tap do |text|
            place_text(text, run)
            text.text_anchor = run.anchor.to_s
            text.fill = run.fill
            text.font_size = Svg::Numbers.write(run.font_size)
            text.font_family = "sans-serif"
            text.font_weight = "bold"
          end
        end

        def place_text(text, run)
          text.x = run.x
          text.y = run.y
          text.content = run.string
        end

        # The rendered geometry for one shape: the traced polygon with
        # rounded corners as quadratic curves, or the special shape's path
        # (document, storage, io, decision, trapezoids, ellipse).
        def render_path(shape)
          special = special_path(shape)
          return special if special

          polygon_path(shape)
        end

        def special_path(shape)
          return nil if shape.points.size != 4

          flow_path(shape) || flowless_path(shape)
        end

        def flow_path(shape)
          case shape.kind
          when :document then document_path(shape)
          when :decision then decision_path(shape)
          when :manual_operation then trapezoid_path(shape, true)
          end
        end

        def flowless_path(shape)
          case shape.kind
          when :storage then storage_path(shape)
          when :io then io_path(shape)
          when :trapezoid then trapezoid_path(shape, false)
          when :ellipse then ellipse_path(shape)
          end
        end

        def polygon_path(shape)
          points = shape.points
          commands = opening_commands(points)
          commands + trailing_commands(points, shape)
        end

        def opening_commands(points)
          first = points.first
          if first.type == :round
            entry = cell_edge_point(first, points[-1])
            exit_point = cell_edge_point(first, points[1])
            "M #{entry[0]} #{entry[1]} " \
              "Q #{first.x} #{first.y} #{exit_point[0]} #{exit_point[1]} "
          else
            "M #{first.x} #{first.y} "
          end
        end

        def trailing_commands(points, shape)
          commands = +""
          points.each_with_index do |point, index|
            next if index.zero?

            commands << point_commands(points, point, index)
          end
          commands << "Z" if shape.closed && points.size > 2
          commands.strip
        end

        def point_commands(points, point, index)
          return "L #{point.x} #{point.y} " if point.type != :round

          round_commands(points, point, index)
        end

        def round_commands(points, point, index)
          following = neighbour_point(points, index)
          entry = cell_edge_point(point, points[index - 1])
          exit_point = cell_edge_point(point, following)
          curve = curve_command(point, entry, exit_point)
          curve + post_round_commands(following, point)
        end

        def neighbour_point(points, index)
          index < points.size - 1 ? points[index + 1] : points[0]
        end

        def curve_command(point, entry, exit_point)
          "L #{entry[0]} #{entry[1]} " \
            "Q #{point.x} #{point.y} #{exit_point[0]} #{exit_point[1]} "
        end

        def post_round_commands(following, point)
          if following.type == :normal
            "L #{following.x} #{following.y} "
          else
            next_entry = cell_edge_point(following, point)
            "L #{next_entry[0]} #{next_entry[1]} "
          end
        end

        def cell_edge_point(point, other)
          box = cell_box(point)
          vertical = cell_vertical_edge(point, other, box)
          vertical || horizontal_edge(point, other, box)
        end

        def cell_vertical_edge(point, other, box)
          if other.y < point.y
            [point.x, box[1]]
          elsif other.y > point.y
            [point.x, box[3]]
          end
        end

        def horizontal_edge(point, other, box)
          if other.x < point.x
            [box[0], point.y]
          else
            [box[2], point.y]
          end
        end

        def cell_box(point)
          left = cell_left_of(point)
          top = cell_top_of(point)
          [left, top, left + @layout.cell_width, top + @layout.cell_height]
        end

        def cell_left_of(point)
          (point.x / @layout.cell_width).floor * @layout.cell_width
        end

        def cell_top_of(point)
          (point.y / @layout.cell_height).floor * @layout.cell_height
        end

        def document_path(shape)
          min_x, min_y, max_x, max_y = shape.bounds
          mid_x = (min_x + max_x) / 2
          control_dx = (max_x - min_x) / 6
          control_dy = (max_y - min_y) / 8
          "M #{min_x} #{min_y} L #{max_x} #{min_y} L #{max_x} #{max_y} " \
            "Q #{mid_x + control_dx} #{max_y - control_dy} #{mid_x} #{max_y} " \
            "Q #{mid_x - control_dx} #{max_y + control_dy} #{min_x} #{max_y} Z"
        end

        def storage_path(shape)
          min_x, min_y, max_x, max_y = shape.bounds
          top_curves(min_x, min_y, max_x) + side_curve(min_x, min_y,
                                                       max_x, max_y)
        end

        # The cylinder curves read clearest as one Bezier table.
        # rubocop:disable Metrics/AbcSize
        def top_curves(min_x, min_y, max_x)
          cp_x = (max_x - min_x) / 6
          cp_top = @layout.cell_height / 2
          first = curve(Bezier.new(min_x + cp_x, min_y + cp_top, max_x - cp_x,
                                   min_y + cp_top, max_x, min_y))
          second = curve(Bezier.new(max_x - cp_x, min_y - cp_top, min_x + cp_x,
                                    min_y - cp_top, min_x, min_y))
          "M #{min_x} #{min_y} #{first} #{second}"
        end

        def curve(bend)
          "C #{bend.c1x} #{bend.c1y} #{bend.c2x} #{bend.c2y} " \
            "#{bend.x} #{bend.y} "
        end

        def side_curve(min_x, min_y, max_x, max_y)
          cp_x = (max_x - min_x) / 6
          cp_bottom = 10 * @layout.cell_height / 14
          "M #{min_x} #{min_y} L #{min_x} #{max_y} " \
            "C #{min_x + cp_x} #{max_y + cp_bottom} #{max_x - cp_x} " \
            "#{max_y + cp_bottom} #{max_x} #{max_y} " \
            "L #{max_x} #{min_y}"
        end

        def io_path(shape)
          min_x, min_y, max_x, max_y = shape.bounds
          offset = @layout.cell_width * 0.5
          "M #{min_x + offset} #{min_y} L #{max_x + offset} #{min_y} " \
            "L #{max_x - offset} #{max_y} L #{min_x - offset} #{max_y} Z"
        end

        def decision_path(shape)
          min_x, min_y, max_x, max_y = shape.bounds
          mid_x = (min_x + max_x) / 2
          mid_y = (min_y + max_y) / 2
          "M #{min_x} #{mid_y} L #{mid_x} #{min_y} " \
            "L #{max_x} #{mid_y} L #{mid_x} #{max_y} Z"
        end

        def trapezoid_path(shape, inverted)
          min_x, min_y, max_x, max_y = shape.bounds
          offset = @layout.cell_width * 0.5
          offset = -offset if inverted
          "M #{min_x + offset} #{min_y} L #{max_x - offset} #{min_y} " \
            "L #{max_x + offset} #{max_y} L #{min_x - offset} #{max_y} Z"
        end

        def ellipse_path(shape)
          min_x, min_y, max_x, _max_y = shape.bounds
          "M #{(min_x + max_x) / 2} #{min_y} #{ellipse_arcs(shape.bounds)} Z"
        end

        def ellipse_arcs(bounds)
          ellipse_bends(bounds).map { |bend| curve(bend) }.join
        end

        # rubocop:disable Metrics/AbcSize
        def ellipse_bends(bounds)
          min_x, min_y, max_x, max_y = bounds
          mid_x = (min_x + max_x) / 2
          mid_y = (min_y + max_y) / 2
          x_off = ((max_x - min_x) * 0.5 * KAPPA).round(6)
          y_off = ((max_y - min_y) * 0.5 * KAPPA).round(6)
          [
            Bezier.new(mid_x + x_off, min_y, max_x, mid_y - y_off,
                       max_x, mid_y),
            Bezier.new(max_x, mid_y + y_off, mid_x + x_off, max_y,
                       mid_x, max_y),
            Bezier.new(mid_x - x_off, max_y, min_x, mid_y + y_off,
                       min_x, mid_y),
            Bezier.new(min_x, mid_y - y_off, mid_x - x_off, min_y,
                       mid_x, min_y),
          ]
        end
        # rubocop:enable Metrics/AbcSize
      end
    end
  end
end
