# frozen_string_literal: true

require_relative "ditaa/grid"
require_relative "ditaa/pattern"
require_relative "ditaa/cell_set"
require_relative "ditaa/builder"

module Etassia
  module Diagram
    # The model behind PlantUML's `@startditaa` blocks: ASCII-art drawings
    # read into boxes, lines, arrowheads, markers and text the way ditaa
    # (ascii2image) interprets them. {Ditaa::Grid} prepares the character
    # grid, {Ditaa::Builder} turns it into geometry.
    class Ditaa
      # The start-line flags: `-E` drops the common-edge separation, `-S`
      # the shadows, `-r` rounds every corner, `-T` makes the background
      # transparent, `scale=` rescales the cell size.
      Options = Struct.new(:separation, :shadows, :round_corners,
                           :transparent, :scale, keyword_init: true)

      DEFAULTS = Options.new(separation: true, shadows: true,
                             round_corners: false, transparent: false,
                             scale: 1.0).freeze

      Result = Builder::Result

      # @param body_lines [Array<String>] the lines between the start and
      #   end tags
      # @param options [Options]
      # @return [Builder::Result] shapes, composites, texts and canvas
      def self.parse(body_lines, options = DEFAULTS)
        grid = Grid.from_lines(dedent(body_lines))
        Builder.new(options).build(grid)
      end

      # The jar strips every line's common leading spaces before reading
      # the grid (PSystemDitaa's nbStartingSpace).
      def self.dedent(body_lines)
        pad = common_pad(body_lines)
        return body_lines if pad.zero?

        body_lines.map { |line| line[pad..].to_s }
      end

      def self.common_pad(body_lines)
        body_lines.map { |line| line[/\A */] }.map(&:length).min || 0
      end
    end
  end
end
