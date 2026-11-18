# frozen_string_literal: true

require_relative "../../diagram/git_log"

module Etassia
  module Notation
    module PlantUML
      # Reads PlantUML's `@startgit` panels: the body is an ASCII git-log
      # drawing - a `*` marks a commit on its rail, `|` continues a rail,
      # `/` and `\` switch rails - and each commit keeps the name written
      # beside it. Dispatched to from {PlantUML.parse}.
      module Git
        HEADERS = /\A(?:\xEF\xBB\xBF)?
                   (?:[ \t\v\f\x00]*(?:'[^\r\n]*)?(?:\r\n|\r|\n))*
                   [ \t\v\f\x00]*@startgit(?![A-Za-z0-9_])/xn
        private_constant :HEADERS

        module_function

        # @param source [String] PlantUML source
        # @return [Notation::Parsed]
        def parse(source)
          body = source.sub(HEADERS, "").sub(/@endgit\s*\z/m, "")
          diagram = Etassia::Diagram::GitLog.parse(body.gsub(/\A\n+/, "").lines)
          Notation::Parsed.new(
            type: :git_diagram, diagram: diagram,
            transform: GitLogLayout, renderer: GitLogRenderer
          )
        end

        # @return [Boolean] whether an @startgit wrapper opens the source
        def git?(source)
          HEADERS.match?(source.b)
        end
      end

      # Lays the commit boxes out: one column per rail, one row per line
      # that carries a commit, named boxes centred on their rail.
      class GitLogLayout
        COLUMN_WIDTH = 44.0
        BOX_WIDTH = 26.0
        BOX_HEIGHT = 24.0
        ROW_HEIGHT = 49.0
        MARGIN = 10.0

        LayoutResult = Struct.new(:boxes, :width, :height)

        def call(diagram, theme: nil, today: nil) # rubocop:disable Lint/UnusedMethodArgument
          boxes = diagram.commits.map { |commit| box_for(commit, diagram) }
          LayoutResult.new(boxes, total_width(diagram), total_height(diagram))
        end

        def box_for(commit, diagram)
          {
            name: commit.name,
            x: rail_x(commit.rail, diagram) - (BOX_WIDTH / 2),
            y: MARGIN + ((commit.line - base_line(diagram)) * ROW_HEIGHT),
            width: BOX_WIDTH, height: BOX_HEIGHT
          }
        end

        def base_line(diagram)
          diagram.commits.map(&:line).min || 0
        end

        def total_width(diagram)
          (MARGIN * 2) + (rails(diagram) * COLUMN_WIDTH)
        end

        def total_height(diagram)
          (MARGIN * 2) + (diagram.lines.size * ROW_HEIGHT)
        end

        private

        def rails(diagram)
          diagram.lines.flat_map { |line| line[:rails] }.uniq.size.clamp(1, nil)
        end

        def rail_x(star_column, diagram)
          star_columns = diagram.lines.flat_map do |line|
            line[:rails]
          end.uniq.sort
          index = star_columns.index(star_column) || 0
          MARGIN + (index * COLUMN_WIDTH) + (COLUMN_WIDTH / 2)
        end
      end

      # Draws the laid-out commit boxes and the curves connecting
      # consecutive commits that share a rail.
      class GitLogRenderer
        INK = "#181818"
        FONT = "monospace"

        def initialize(theme: nil)
          @theme = theme
        end

        def render(layout_result)
          svg = Svg::Document.new(
            width: layout_result.width, height: layout_result.height,
            view_box: "0 0 #{layout_result.width} #{layout_result.height}"
          )
          layout_result.boxes.each_with_index do |box, index|
            draw_curves_from(layout_result, box, index, svg)
            draw_box(box, svg)
          end
          svg
        end

        def draw_box(box, svg)
          draw_outline(box, svg)
          draw_name(box, svg)
        end

        def draw_outline(box, svg)
          svg.add_element(
            Svg::Rect.new(
              x: box[:x], y: box[:y], width: box[:width],
              height: box[:height], rx: 4, ry: 4, fill: "none",
              stroke: INK, stroke_width: "1.5"
            ),
          )
        end

        def draw_name(box, svg)
          label = Svg::Text.new.tap do |element|
            place_name(element, box)
          end
          svg.add_element(label)
        end

        def place_name(element, box)
          element.x = box[:x] + 4
          element.y = box[:y] + 17.2
          element.content = box[:name]
          element.fill = "#000000"
          element.font_size = "15"
          element.font_family = FONT
          element.font_weight = "700"
        end

        def draw_curves_from(layout_result, box, index, svg)
          layout_result.boxes[(index + 1)..].each do |other|
            next unless same_rail?(box, other)

            draw_curve(box, other, svg)
            break
          end
        end

        def draw_curve(box, other, svg)
          svg.add_element(Svg::Path.new.tap do |path|
            path.d = curve(box, other)
            path.stroke = INK
            path.stroke_width = "1"
            path.fill = "none"
          end)
        end

        def same_rail?(first, second)
          (first[:x] - second[:x]).abs < 1.0
        end

        def curve(first, second)
          top = first[:y] + first[:height]
          bottom = second[:y]
          mid1 = top + ((bottom - top) * 0.22)
          mid2 = bottom - ((bottom - top) * 0.22)
          x = first[:x] + (first[:width] / 2)
          "M#{x},#{top} C#{x},#{mid1} #{x},#{mid2} #{x},#{bottom}"
        end
      end
    end
  end
end
