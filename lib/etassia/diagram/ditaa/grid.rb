# frozen_string_literal: true

module Etassia
  module Diagram
    class Ditaa
      # The character grid behind ditaa: the port of ascii2image's TextGrid.
      # Boundaries are `/ \ | - * = :`; corners, intersections, stubs and
      # lone diagonals are recognised by 3x3 pattern groups; type on a line
      # and `*` markers on a line are replaced so the boundary reading sees
      # plain line characters.
      class Grid
        BOUNDARIES = %w[/ \\ | - * = :].freeze
        HORIZONTAL_LINES = %w[- =].freeze
        VERTICAL_LINES = %w[| :].freeze
        DASHED_LINES = %w[: ~ =].freeze
        POINT_MARKERS = %w[*].freeze

        HUMAN_COLOR_CODES = {
          "cGRE" => "c9D9", "cBLU" => "c55B", "cPNK" => "cFAA",
          "cRED" => "cE32", "cYEL" => "cFF3", "cBLK" => "c000"
        }.freeze
        MARKUP_TAGS = %w[d s io c mo tr o].freeze
        COLOR_CODE = /\Ac[A-F0-9]{3}\z/
        TAG_PATTERN = /\{(.+?)\}/
        TAB_SIZE = 8
        BLANK_BORDER = 2

        ENTRY_POINTS = {
          1 => ["\\"].freeze, 2 => %w[| : + \\ /].freeze, 3 => ["/"].freeze,
          4 => %w[- = + \\ /].freeze, 5 => ["\\"].freeze,
          6 => %w[| : + \\ /].freeze, 7 => ["/"].freeze,
          8 => %w[- = + \\ /].freeze
        }.freeze

        NEIGHBOUR_OFFSETS = [[0, -1], [0, 1], [1, 0], [-1, 0]].freeze
        INTERSECTION_ARMS = [[0, -1, 6], [0, 1, 2], [1, 0, 8],
                             [-1, 0, 4]].freeze
        STUB_PROBES = [[1, 0], [-1, 0], [0, -1], [0, 1]].freeze
        H_STEPS = [[1, 0], [-1, 0]].freeze
        V_STEPS = [[0, -1], [0, 1]].freeze
        SENTINEL = "\x01"

        attr_reader :rows

        def initialize(rows = [])
          @rows = rows
        end

        # Pads every line to one width, wraps the buffer in a two-cell blank
        # border, expands tabs, turns `o`/`*` bullets into `•` and rewrites
        # the human colour codes (the jar's initialiseWithLines, tabs first).
        # Trailing blank rows are gone entirely — measured on the pinned
        # jar, whose canvas grows only with content rows.
        def self.from_lines(body_lines)
          trimmed = trim_trailing_blank_rows(body_lines.map(&:chomp))
          tabbed = trimmed.map { |line| expand_tabs(line) }
          grid = new(bordered_rows(tabbed))
          grid.replace_bullets
          grid.replace_human_color_codes
          grid
        end

        def self.bordered_rows(tabbed)
          width = tabbed.map(&:length).max || 0
          blank = " " * (width + (BLANK_BORDER * 2))
          rows = [blank, blank]
          tabbed.each do |line|
            rows << "  #{line}#{' ' * (width - line.length)}  "
          end
          rows.push(blank, blank)
          rows
        end

        def self.expand_tabs(line)
          expanded = +""
          line.each_char do |char|
            expanded << if char == "\t"
                          (" " * (TAB_SIZE - (expanded.length % TAB_SIZE)))
                        else
                          char
                        end
          end
          expanded
        end
        private_class_method :expand_tabs

        def self.trim_trailing_blank_rows(lines)
          last = lines.rindex { |line| !line.strip.empty? } || -1
          lines.first(last + 1)
        end
        private_class_method :trim_trailing_blank_rows

        def width = @rows.first&.length.to_i
        def height = @rows.length

        # Out of bounds reads return nil, Java's char 0.
        def get(col, row)
          return nil if col.negative? || row.negative?
          return nil if col > width - 1 || row > height - 1

          @rows[row][col]
        end

        def set(col, row, char)
          return if col.negative? || row.negative?
          return if col > width - 1 || row > height - 1

          @rows[row][col] = char
        end

        # Java distinguishes isBlank(Cell): out of bounds is NOT blank, from
        # isBlank(int, int): out of bounds IS blank. Both are load-bearing.
        def blank_at?(col, row)
          char = get(col, row)
          char.nil? || char == " "
        end

        def blank_cell?(col, row)
          char = get(col, row)
          !char.nil? && char == " "
        end

        def string_at(col, row, length)
          return nil if col.negative? || row.negative?
          return nil if col > width - 1 || row > height - 1

          @rows[row][col, length]
        end

        # `o` or `*` with blank on both sides and a letter or digit two east:
        # the marker becomes a space and its east neighbour the `•` glyph.
        def replace_bullets
          height.times do |row|
            width.times do |col|
              next unless bullet?(col, row)

              set(col, row, " ")
              set(col + 1, row, "•")
            end
          end
        end

        def bullet?(col, row)
          return false unless %w[o *].include?(get(col, row))
          return false unless blank_cell?(col + 1,
                                          row) && blank_cell?(col - 1, row)

          next_char = get(col + 2, row)
          !next_char.nil? && next_char.match?(/[[:alnum:]]/)
        end

        def replace_human_color_codes
          @rows = @rows.map do |row|
            HUMAN_COLOR_CODES.reduce(row) do |current, (human, hex)|
              current.gsub(human, hex)
            end
          end
        end

        # Letters or digits sitting on a horizontal or vertical run become
        # line characters, `+` where both meet.
        def replace_type_on_line
          height.times do |row|
            width.times do |col|
              line_char = type_on_line_char(col, row)
              set(col, row, line_char) if line_char
            end
          end
        end

        def type_on_line_char(col, row)
          return nil unless get(col, row).to_s.match?(/[[:alnum:]]/)

          between_lines(col, row)
        end

        def between_lines(col, row)
          horizontal = hrun?(col, row)
          return "+" if horizontal && vrun?(col, row)
          return "-" if horizontal

          "|" if vrun?(col, row)
        end

        def hrun?(col, row)
          horizontal_line?(col - 1, row) && horizontal_line?(col + 1, row)
        end

        def vrun?(col, row)
          vertical_line?(col, row - 1) && vertical_line?(col, row + 1)
        end

        def replace_point_markers_on_line
          height.times do |row|
            width.times do |col|
              marker_char = marker_on_line_char(col, row)
              set(col, row, marker_char) if marker_char
            end
          end
        end

        def marker_on_line_char(col, row)
          return nil unless POINT_MARKERS.include?(get(col, row))
          return nil unless star_on_line?(col, row)

          beside_lines(col, row)
        end

        def beside_lines(col, row)
          horizontal = hrun_either?(col, row)
          return "+" if horizontal && vrun_either?(col, row)
          return "-" if horizontal

          "|"
        end

        def hrun_either?(col, row)
          horizontal_line?(col + 1, row) || horizontal_line?(col - 1, row)
        end

        def vrun_either?(col, row)
          vertical_line?(col, row - 1) || vertical_line?(col, row + 1)
        end

        def point_markers_on_line
          cells = CellSet.new
          height.times do |row|
            width.times do |col|
              cells.add(col, row) if marker_on_line?(col, row)
            end
          end
          cells
        end

        def marker_on_line?(col, row)
          POINT_MARKERS.include?(get(col, row)) && star_on_line?(col, row)
        end

        def horizontal_line?(col, row)
          HORIZONTAL_LINES.include?(get(col, row))
        end

        def vertical_line?(col, row) = VERTICAL_LINES.include?(get(col, row))

        def line?(col, row)
          horizontal_line?(col, row) || vertical_line?(col, row)
        end

        def boundary?(col, row)
          char = get(col, row)
          return false if char.nil?
          return shaped_boundary?(col, row) if %w[+ \\ /].include?(char)

          BOUNDARIES.include?(char) && !lone_diagonal?(col, row)
        end

        def shaped_boundary?(col, row)
          intersection?(col, row) || corner?(col, row) || stub?(col, row) ||
            cross_on_line?(col, row)
        end

        def arrowhead?(col, row)
          north_arrowhead?(col, row) || south_arrowhead?(col, row) ||
            west_arrowhead?(col, row) || east_arrowhead?(col, row)
        end

        def north_arrowhead?(col, row) = get(col, row) == "^"
        def east_arrowhead?(col, row) = get(col, row) == ">"
        def west_arrowhead?(col, row) = get(col, row) == "<"

        def south_arrowhead?(col, row)
          %w[v V].include?(get(col, row)) && vertical_line?(col, row - 1)
        end

        def arrowheads
          cells = []
          height.times do |row|
            width.times do |col|
              cells << [col, row] if arrowhead?(col, row)
            end
          end
          cells
        end

        def color_codes
          codes = []
          height.times do |row|
            (width - 3).times do |col|
              pair = color_code_at(col, row)
              codes << pair if pair
            end
          end
          codes
        end

        def color_code_at(col, row)
          text = string_at(col, row, 4)
          return nil unless text.match?(COLOR_CODE)

          [[col, row], hex_color(text)]
        end

        def hex_color(text)
          red, green, blue = text[1..].each_char.map do |digit|
            digit.to_i(16) * 17
          end
          format("#%<red>02x%<green>02x%<blue>02x", red: red, green: green,
                                                    blue: blue)
        end

        def markup_tags
          tags = []
          height.times do |row|
            width.times do |col|
              next unless get(col, row) == "{"

              match = TAG_PATTERN.match(@rows[row][col..])
              next unless match && MARKUP_TAGS.include?(match[1])

              tags << [[col, row], match[1]]
            end
          end
          tags
        end

        def remove_non_text
          remove_arrowheads
          remove_color_codes
          remove_boundaries
          remove_markup_tags
        end

        def remove_arrowheads
          arrowheads.each { |col, row| set(col, row, " ") }
        end

        def remove_color_codes
          cells = color_codes.map(&:first)
          cells.each do |col, row|
            4.times { |step| set(col + step, row, " ") }
          end
        end

        # Removed in two stages: the boundary? decision reads neighbours, so
        # blanking while scanning would change later answers.
        def remove_boundaries
          doomed = []
          height.times do |row|
            width.times do |col|
              doomed << [col, row] if boundary?(col, row)
            end
          end
          doomed.each { |col, row| set(col, row, " ") }
        end

        def remove_markup_tags
          markup_tags.each do |(col, row), tag|
            (tag.length + 2).times { |step| set(col + step, row, " ") }
          end
        end

        def all_boundaries
          cells = CellSet.new
          height.times do |row|
            width.times do |col|
              cells.add(col, row) if boundary?(col, row)
            end
          end
          cells
        end

        def all_non_blank
          cells = CellSet.new
          height.times do |row|
            width.times do |col|
              cells.add(col, row) unless blank_cell?(col, row)
            end
          end
          cells
        end

        def has_blank_cells?
          height.times do |row|
            width.times do |col|
              return true if blank_cell?(col, row)
            end
          end
          false
        end

        def blanks_between_characters
          cells = CellSet.new
          height.times do |row|
            width.times do |col|
              next unless blank_cell?(col, row)
              next if blank_cell?(col + 1, row) || blank_cell?(col - 1, row)

              cells.add(col, row)
            end
          end
          cells
        end

        def dashed_line_char?(col, row) = DASHED_LINES.include?(get(col, row))

        def contains_dashed_line?(cell_set)
          cell_set.any? { |col, row| dashed_line_char?(col, row) }
        end

        def copy_cells_to(cell_set, other)
          cell_set.each do |col, row|
            char = get(col, row)
            other.set(col, row, char) unless char.nil?
          end
        end

        def fill_cells_with(cell_set, char)
          cell_set.each { |col, row| set(col, row, char) }
        end

        # Floods over the seed's character, writing `char`; returns the
        # filled cells (the jar's seedFillOld).
        def fill_continuous_area(col, row, char)
          old = get(col, row)
          filled = CellSet.new
          return filled if old.nil? || old == char

          flood(col, row, old, char, filled)
          filled
        end

        def flood(col, row, old, char, filled)
          stack = [[col, row]]
          until stack.empty?
            visit = stack.pop
            set(*visit, char)
            filled.add(*visit)
            stack.concat(flood_neighbours(visit, old))
          end
        end

        def flood_neighbours(cell, old)
          NEIGHBOUR_OFFSETS.filter_map do |dcol, drow|
            next_cell = [cell.first + dcol, cell.last + drow]
            next_cell if get(*next_cell) == old
          end
        end

        # The `*` cells a flood from the seed would run into. The flooded
        # region is written with a sentinel so it is not swept twice.
        def boundaries_expanding_from(col, row)
          old = get(col, row)
          boundaries = CellSet.new
          return boundaries if old.nil?

          expand_boundaries(col, row, old, boundaries)
          boundaries
        end

        def expand_boundaries(col, row, old, boundaries)
          stack = [[col, row]]
          until stack.empty?
            visit = stack.pop
            set(*visit, SENTINEL)
            stack.concat(expansion_neighbours(visit, old, boundaries))
          end
        end

        def expansion_neighbours(cell, old, boundaries)
          NEIGHBOUR_OFFSETS.filter_map do |dcol, drow|
            next_cell = [cell.first + dcol, cell.last + drow]
            value = get(*next_cell)
            if value == old
              next_cell
            elsif value == "*"
              boundaries.add(*next_cell)
              nil
            end
          end
        end

        # Continuous non-blank runs. A run ends only at TWO blanks in a row,
        # so one trailing blank joins the string (the jar does too), and the
        # appended characters are read before the pair check.
        def strings
          runs = []
          height.times { |row| runs.concat(row_runs(row)) }
          runs
        end

        def row_runs(row)
          runs = []
          col = 0
          while col < width
            run = blank_cell?(col, row) ? nil : string_run(col, row)
            col = run ? run_end(run) : col + 1
            runs << run if run
          end
          runs
        end

        def run_end(run)
          run.first.first + run.last.length + 1
        end

        def string_run(col, row)
          string = get(col, row)
          char = get(col + 1, row)
          [[col, row], grow_string(string, char, col + 2, row)]
        end

        def grow_string(string, char, cursor, row)
          loop do
            string += char.to_s
            char = get(cursor, row)
            following = get(cursor + 1, row)
            cursor += 1
            break if blankish?(char) && blankish?(following)
          end
          string
        end

        def sub_grid(col, row, sub_width, sub_height)
          if col.negative? || row.negative? || col + sub_width > width ||
              row + sub_height > height
            raise IndexError, "sub grid out of bounds at #{col},#{row}"
          end

          rows = (0...sub_height).map do |offset|
            @rows[row + offset][col, sub_width]
          end
          self.class.new(rows)
        end

        def testing_sub_grid(col, row)
          sub_grid(col - 1, row - 1, 3, 3)
        end

        # Same size, all blank.
        def self.blank_like(other)
          new(Array.new(other.height) { " " * other.width })
        end

        def ==(other)
          other.is_a?(Grid) && @rows == other.rows
        end

        def entry_point?(col, row, id)
          ENTRY_POINTS.fetch(id).include?(get(col, row))
        end

        # The cells a trace step can move to from x,y having come from
        # `blocked`. Nil when the cell type cannot be determined (the jar
        # throws here; the caller decides what an untraceable cell means).
        def follow_cell(col, row, blocked = nil)
          if intersection?(col, row) then follow_intersection(col, row, blocked)
          elsif corner?(col, row) then follow_corner(col, row, blocked)
          elsif line?(col, row) then follow_line(col, row, blocked)
          elsif stub?(col, row) then follow_stub(col, row, blocked)
          elsif cross_on_line?(col,
                               row) then follow_cross_on_line(col, row, blocked)
          end
        end

        def follow_intersection(col, row, blocked)
          result = CellSet.new
          INTERSECTION_ARMS.each do |dcol, drow, entry|
            hit = [col + dcol, row + drow]
            result.add(*hit) if entry_point?(*hit, entry)
          end
          result.delete(Array(blocked)) if blocked
          result
        end

        def follow_line(col, row, blocked)
          result = CellSet.new
          steps = horizontal_line?(col, row) ? H_STEPS : V_STEPS
          steps.each do |dcol, drow|
            result.add(col + dcol, row + drow) if boundary?(col + dcol,
                                                            row + drow)
          end
          result.delete(Array(blocked)) if blocked
          result
        end

        def follow_corner(col, row, blocked)
          return follow_corner1(col, row, blocked) if corner1?(col, row)
          return follow_corner2(col, row, blocked) if corner2?(col, row)
          return follow_corner3(col, row, blocked) if corner3?(col, row)

          follow_corner4(col, row, blocked)
        end

        def follow_corner1(col, row, blocked)
          result = CellSet.new
          result.add(col, row + 1) unless blocked == [col, row + 1]
          result.add(col + 1, row) unless blocked == [col + 1, row]
          result
        end

        def follow_corner2(col, row, blocked)
          result = CellSet.new
          result.add(col, row + 1) unless blocked == [col, row + 1]
          result.add(col - 1, row) unless blocked == [col - 1, row]
          result
        end

        def follow_corner3(col, row, blocked)
          result = CellSet.new
          result.add(col, row - 1) unless blocked == [col, row - 1]
          result.add(col - 1, row) unless blocked == [col - 1, row]
          result
        end

        def follow_corner4(col, row, blocked)
          result = CellSet.new
          result.add(col, row - 1) unless blocked == [col, row - 1]
          result.add(col + 1, row) unless blocked == [col + 1, row]
          result
        end

        def follow_stub(col, row, blocked)
          result = CellSet.new
          hit = STUB_PROBES.find do |dcol, drow|
            boundary?(col + dcol, row + drow)
          end
          result.add(col + hit.first, row + hit.last)
          result.delete(Array(blocked)) if blocked
          result
        end

        def follow_cross_on_line(col, row, blocked)
          result = CellSet.new
          if horizontal_cross_on_line?(col, row)
            result.add(col + 1, row)
            result.add(col - 1, row)
          else
            result.add(col, row - 1)
            result.add(col, row + 1)
          end
          result.delete(Array(blocked)) if blocked
          result
        end

        def horizontal_cross_on_line?(col, row)
          matches_any?(col, row, PatternGroup::HORIZONTAL_CROSS_ON_LINE)
        end

        def vertical_cross_on_line?(col, row)
          matches_any?(col, row, PatternGroup::VERTICAL_CROSS_ON_LINE)
        end

        def normal_corner?(col, row)
          matches_any?(col, row, PatternGroup::NORMAL_CORNER)
        end

        def round_corner?(col, row)
          matches_any?(col, row, PatternGroup::ROUND_CORNER)
        end

        def corner1?(col, row) = matches_any?(col, row, PatternGroup::CORNER1)
        def corner2?(col, row) = matches_any?(col, row, PatternGroup::CORNER2)
        def corner3?(col, row) = matches_any?(col, row, PatternGroup::CORNER3)
        def corner4?(col, row) = matches_any?(col, row, PatternGroup::CORNER4)
        def corner?(col, row) = matches_any?(col, row, PatternGroup::CORNER)

        def intersection?(col, row)
          matches_any?(col, row, PatternGroup::INTERSECTION)
        end

        def intersection_t?(col, row) = matches_any?(col, row, PatternGroup::T)
        def intersection_k?(col, row) = matches_any?(col, row, PatternGroup::K)

        def intersection_inverse_t?(col, row)
          matches_any?(col, row, PatternGroup::INVERSE_T)
        end

        def intersection_inverse_k?(col, row)
          matches_any?(col, row, PatternGroup::INVERSE_K)
        end

        def stub?(col, row) = matches_any?(col, row, PatternGroup::STUB)

        def lines_end?(col, row)
          matches_any?(col, row, PatternGroup::LINES_END)
        end

        def cross_on_line?(col, row)
          matches_any?(col, row, PatternGroup::CROSS_ON_LINE)
        end

        def star_on_line?(col, row)
          matches_any?(col, row, PatternGroup::STAR_ON_LINE)
        end

        def lone_diagonal?(col, row)
          matches_any?(col, row, PatternGroup::LONE_DIAGONAL)
        end

        def cross?(col, row) = matches_any?(col, row, PatternGroup::CROSS)

        private

        def blankish?(char)
          char.nil? || char == " "
        end

        def matches_any?(col, row, group)
          testing_sub_grid(col, row).matches_group?(group)
        end
      end
    end
  end
end
