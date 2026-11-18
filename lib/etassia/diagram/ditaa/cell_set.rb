# frozen_string_literal: true

module Etassia
  module Diagram
    class Ditaa
      # An ordered set of grid cells, with the set algorithms the shape
      # pipeline needs: open/closed/mixed classification, mixed-boundary
      # breaking, filled equivalents and the one-third scaling that pairs
      # with the abstraction grid.
      class CellSet
        include Enumerable

        TYPE_OPEN = :open
        TYPE_CLOSED = :closed
        TYPE_MIXED = :mixed
        TYPE_UNDETERMINED = :undetermined
        TYPE_HAS_CLOSED_AREA = :has_closed_area

        attr_reader :cells

        def initialize(cells = [])
          @cells = cells
          @index = Set.new(cells)
        end

        def add(first, second = nil)
          cell = second.nil? ? first : [first, second]
          return if @index.include?(cell)

          @cells << cell
          @index << cell
          self
        end

        def delete(cell)
          @index.delete(cell)
          @cells.delete(cell)
          self
        end

        def each(&) = @cells.each(&)
        def size = @cells.length
        def empty? = @cells.empty?
        def any?(&) = @cells.any?(&)
        def include?(cell) = @index.include?(cell)
        def first = @cells.first

        def ==(other)
          other.is_a?(CellSet) && @cells.sort == other.cells.sort
        end

        def translate(d_col, d_row)
          @cells.map! { |cell| [cell.first + d_col, cell.last + d_row] }
          @index = Set.new(@cells)
          self
        end

        def subtract_set(other)
          other.each { |cell| delete(cell) }
          self
        end

        def has_common_cells?(other)
          any? { |cell| other.include?(cell) }
        end

        def min_x = @cells.map(&:first).min
        def max_x = @cells.map(&:first).max
        def min_y = @cells.map(&:last).min
        def max_y = @cells.map(&:last).max

        def width = max_x - min_x
        def height = max_y - min_y

        def self.copy(set)
          new(set.cells.dup)
        end

        def self.remove_duplicates(sets)
          unique = []
          sets.each do |set|
            unique << set unless unique.any?(set)
          end
          unique
        end

        # Connected components over cell adjacency (the jar's flood fill on
        # a grid of the set's own cells).
        def break_into_distinct
          seen = Set.new
          @cells.filter_map do |cell|
            next if seen.include?(cell)

            component_from(cell, seen)
          end
        end

        def component_from(cell, seen)
          component = CellSet.new
          stack = [cell]
          until stack.empty?
            current = stack.pop
            next if seen.include?(current) || !include?(current)

            seen << current
            component.add(*current)
            stack.push(*component_neighbours(current))
          end
          component
        end

        def component_neighbours(cell)
          [[cell.first, cell.last - 1], [cell.first, cell.last + 1],
           [cell.first + 1, cell.last], [cell.first - 1, cell.last]]
        end

        # Components through the abstraction grid, where each cell occupies
        # only the rows and columns its character draws (the jar's
        # breakIntoDistinctBoundaries for a set against a grid).
        def break_into_distinct_boundaries(source_grid)
          buffer = abstraction_buffer(source_grid, self)
          buffer.all_non_blank.break_into_distinct.map do |component|
            scaled_component(buffer, component)
          end
        end

        def scaled_component(_buffer, component)
          scaled = CellSet.new
          component.each do |col, row|
            scaled.add(col / 3, row / 3)
          end
          scaled
        end

        def make_into_grid
          grid = Grid.new(Array.new(max_y + 2) { " " * (max_x + 2) })
          grid.fill_cells_with(self, "*")
          grid
        end

        def make_scaled_one_third_equivalent
          grid_big = make_into_grid
          grid_small = Grid.new(Array.new((max_y + 2) / 3) do
            " " * ((max_x + 2) / 3)
          end)
          stamp_scaled(grid_big, grid_small)
          grid_small.all_non_blank
        end

        def stamp_scaled(grid_big, grid_small)
          grid_big.height.times do |row|
            grid_big.width.times do |col|
              next if grid_big.blank_cell?(col, row)

              grid_small.set(col / 3, row / 3, "*")
            end
          end
        end

        # Open, closed or mixed per the jar: trace from a line end first;
        # when that cannot decide, fill from the first blank of the enclosing
        # sub grid and see whether blanks survive inside.
        def type(grid)
          return TYPE_OPEN if size < 2

          traced = type_by_trace(grid)
          return traced if %i[open closed].include?(traced)

          fill = type_by_fill(grid)
          return TYPE_MIXED if fill == TYPE_HAS_CLOSED_AREA

          fill
        end

        def type_by_trace(grid)
          work = Grid.blank_like(grid)
          grid.copy_cells_to(self, work)
          start = trace_start(work)
          next_cells = work.follow_cell(*start)
          return TYPE_OPEN if next_cells.nil? || next_cells.empty?

          trace_round(work, start, next_cells.first)
        end

        def trace_start(work)
          found = nil
          each { |cell| found = cell if work.lines_end?(*cell) }
          found || first
        end

        def trace_round(work, start, cell)
          previous = start
          until cell == start
            next_cells = work.follow_cell(*cell, previous)
            return TYPE_OPEN if next_cells.nil? || next_cells.empty?
            return TYPE_UNDETERMINED if next_cells.size > 1

            previous = cell
            cell = next_cells.first
          end
          TYPE_CLOSED
        end

        def type_by_fill(grid)
          buffer = fill_buffer(grid)
          fill_cell = first_blank(buffer)
          buffer.fill_continuous_area(*fill_cell, "*")
          buffer.has_blank_cells? ? TYPE_HAS_CLOSED_AREA : TYPE_OPEN
        end

        def fill_buffer(grid)
          temp = CellSet.copy(self)
          temp.translate(1 - min_x, 1 - min_y)
          abstraction_buffer(sub_grid_around(grid), temp)
        end

        def sub_grid_around(grid)
          grid.sub_grid(min_x - 1, min_y - 1, width + 3, height + 3)
        end

        def first_blank(buffer)
          buffer.height.times do |row|
            buffer.width.times do |col|
              return [col, row] if buffer.blank_cell?(col, row)
            end
          end
        end

        def abstraction_buffer(source_grid, cell_set)
          AbstractCell.stamp_buffer(source_grid, cell_set)
        end

        # The filled region a closed set covers (for obsolete-shape removal).
        def filled_equivalent(grid)
          return CellSet.copy(self) if type(grid) == TYPE_OPEN

          grid = make_into_grid
          seed = interior_seed(grid)
          return CellSet.copy(self) if seed.nil?

          fill = [seed.first + 1, seed.last]
          grid.fill_continuous_area(*fill, "*")
          grid.all_non_blank
        end

        def interior_seed(grid)
          grid.height.times do |row|
            grid.width.times do |col|
              return [col, row] if interior_cell?(grid, col, row)
            end
          end
          nil
        end

        def interior_cell?(grid, col, row)
          !grid.blank_cell?(col, row) && grid.blank_cell?(col + 1, row) &&
            grid.blank_cell?(col - 1, row)
        end

        # Splits a truly mixed boundary into open and closed parts by
        # tracing outwards from every line end.
        def break_truly_mixed(grid)
          work = Grid.blank_like(grid)
          grid.copy_cells_to(self, work)
          result = mixed_parts(work)
          whats_left = CellSet.copy(self)
          result.each { |set| whats_left.subtract_set(set) }
          result << whats_left
          result
        end

        def mixed_parts(work)
          result = []
          visited_ends = CellSet.new
          each do |cell|
            next if visited_ends.include?(cell) || !work.lines_end?(*cell)

            mixed_trace(work, cell, visited_ends, result)
          end
          result
        end

        # Traces one leg outwards from a line end; returns the leg's ends
        # so the outer loop skips them.
        def mixed_trace(work, cell, visited_ends, result)
          set = CellSet.new
          set.add(*cell)
          next_cells = work.follow_cell(*cell)
          grow_mixed(work, set, cell, next_cells.first, visited_ends)
          result << set
        end

        def grow_mixed(work, set, previous, cell, visited_ends)
          set.add(*cell)
          return if work.lines_end?(*cell)

          follow = work.follow_cell(*cell, previous)
          if follow && follow.size == 1
            leg_end(work, set, cell, follow.first, visited_ends)
          end
        end

        def leg_end(work, set, previous, cell, visited_ends)
          if work.lines_end?(*cell)
            visited_ends.add(*cell)
            set.add(*cell)
          else
            grow_mixed(work, set, previous, cell, visited_ends)
          end
        end
      end

      # The 3x3 footprints a boundary cell occupies in the abstraction grid
      # (ascii2image's AbstractCell), chosen by the cell's pattern class.
      module AbstractCell
        module_function

        HORIZONTAL = [[0, 1], [1, 1], [2, 1]].freeze
        VERTICAL = [[1, 0], [1, 1], [1, 2]].freeze
        CORNER1 = [[1, 1], [1, 2], [2, 1]].freeze
        CORNER2 = [[0, 1], [1, 1], [1, 2]].freeze
        CORNER3 = [[0, 1], [1, 0], [1, 1]].freeze
        CORNER4 = [[1, 0], [1, 1], [2, 1]].freeze
        T = (HORIZONTAL + [[1, 2]]).freeze
        INVERSE_T = (HORIZONTAL + [[1, 0]]).freeze
        K = (VERTICAL + [[2, 1]]).freeze
        INVERSE_K = (VERTICAL + [[0, 1]]).freeze
        CROSS = (VERTICAL + [[0, 1], [2, 1]]).freeze
        STAR = [0, 1, 2].product([0, 1, 2]).freeze

        def for_cell(grid, col, row)
          junction(grid, col, row) || cornerish(grid, col, row) ||
            linelike(grid, col, row)
        end

        def junction(grid, col, row)
          return CROSS if grid.cross?(col, row)
          return T if grid.intersection_t?(col, row)
          return K if grid.intersection_k?(col, row)
          return INVERSE_T if grid.intersection_inverse_t?(col, row)

          INVERSE_K if grid.intersection_inverse_k?(col, row)
        end

        def cornerish(grid, col, row)
          return CORNER1 if grid.corner1?(col, row)
          return CORNER2 if grid.corner2?(col, row)
          return CORNER3 if grid.corner3?(col, row)

          CORNER4 if grid.corner4?(col, row)
        end

        def linelike(grid, col, row)
          return HORIZONTAL if grid.horizontal_line?(col, row)
          return VERTICAL if grid.vertical_line?(col, row)
          return CROSS if grid.cross_on_line?(col, row)

          STAR if grid.star_on_line?(col, row)
        end

        # The 3x-scaled buffer carrying `*` at every marked footprint cell
        # of the set, blank elsewhere (ascii2image's AbstractionGrid).
        def stamp_buffer(source_grid, cell_set)
          buffer = Grid.new(Array.new(source_grid.height * 3) do
            " " * (source_grid.width * 3)
          end)
          cell_set.each { |cell| stamp_cell(buffer, source_grid, cell) }
          buffer
        end

        def stamp_cell(buffer, source_grid, cell)
          return if source_grid.blank_cell?(*cell)

          marks = for_cell(source_grid, *cell)
          marks&.each do |dcol, drow|
            buffer.set((cell.first * 3) + dcol, (cell.last * 3) + drow, "*")
          end
        end
      end
    end
  end
end
