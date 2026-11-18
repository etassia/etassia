# frozen_string_literal: true

module Etassia
  module Diagram
    class Ditaa
      # Turns a prepared {Grid} into shapes, texts and a canvas: the port of
      # ascii2image's Diagram constructor. Boundary cells are scaled onto a
      # 3x abstraction grid, split into distinct shapes, and every flood
      # region's edge becomes a candidate boundary; candidates classify as
      # closed, open or mixed, mixed ones are eliminated, and the survivors
      # are traced into geometry.
      class Builder
        CELL_WIDTH = 10
        CELL_HEIGHT = 14
        MARKUP_TYPES = {
          "d" => :document, "s" => :storage, "io" => :io, "c" => :decision,
          "mo" => :manual_operation, "tr" => :trapezoid, "o" => :ellipse
        }.freeze

        Point = Struct.new(:x, :y, :type, :locked, keyword_init: true)

        # One drawn piece: `points` carry the geometry, `kind` names the
        # rendered form (:rectangle, :document, :storage, :io, :decision,
        # :manual_operation, :trapezoid, :ellipse, :line, :arrowhead,
        # :point_marker), and the rest is paint.
        Shape = Struct.new(:points, :kind, :closed, :dashed, :fill, :stroke,
                           keyword_init: true) do
          def bounds
            xs = points.map(&:x)
            ys = points.map(&:y)
            [xs.min, ys.min, xs.max, ys.max]
          end

          def area
            (calculate_area.abs / 2)
          end

          def calculate_area
            sum = 0.0
            list = points
            list.each_with_index do |point, index|
              other = list[(index + 1) % list.length]
              sum += (point.x * other.y) - (other.x * point.y)
            end
            sum
          end

          def drops_shadow?
            closed && !%i[arrowhead point_marker].include?(kind) && !dashed
          end
        end

        TextRun = Struct.new(:x, :y, :string, :font_size, :anchor, :fill,
                             keyword_init: true)

        Result = Struct.new(:shapes, :composites, :texts, :width, :height,
                            :transparent, :shadows, :cell_width, :cell_height,
                            keyword_init: true)

        Edge = Struct.new(:start_point, :end_point, :owner) do
          def horizontal? = start_point.y == end_point.y
          def vertical? = start_point.x == end_point.x

          def touches_with?(other)
            return true if self == other
            return false if perpendicular?(other)
            return false if distance_from_origin != other.distance_from_origin

            overlapping?(other)
          end

          def distance_from_origin
            horizontal? ? start_point.y : start_point.x
          end

          def aligned_copy
            ordered = [start_point, end_point].sort_by do |point|
              horizontal? ? point.x : point.y
            end
            Edge.new(ordered.first, ordered.last, owner)
          end

          def within_any?(edge)
            within_edge?(edge.start_point, edge) ||
              within_edge?(edge.end_point, edge)
          end

          def perpendicular?(other)
            (horizontal? && other.vertical?) ||
              (other.horizontal? && vertical?)
          end

          def overlapping?(other)
            first = aligned_copy
            second = other.aligned_copy
            if first.start_point.x > second.start_point.x
              first, second = second, first
            end
            return false if first.end_point == second.start_point

            other.within_any?(self) || within_any?(other)
          end

          def within_edge?(point, edge)
            if edge.horizontal?
              within_horizontal?(point, edge)
            else
              within_vertical?(point, edge)
            end
          end

          def within_horizontal?(point, edge)
            point.y == edge.start_point.y &&
              point.x.between?(edge.start_point.x, edge.end_point.x)
          end

          def within_vertical?(point, edge)
            point.x == edge.start_point.x &&
              point.y.between?(edge.start_point.y, edge.end_point.y)
          end
        end

        OpenTrace = Struct.new(:work, :visited, :drawn)
        WalkState = Struct.new(:cell, :previous, :steps)
        CellBox = Struct.new(:left, :top, :mid_x, :mid_y)

        attr_reader :cell_width, :cell_height

        def initialize(options)
          @options = options
          @cell_width = (CELL_WIDTH * options.scale).round
          @cell_height = (CELL_HEIGHT * options.scale).round
          @separation = options.separation
          @transparent = options.transparent
          @round_corners = options.round_corners
        end

        def build(grid)
          work = prepare_work(grid)
          closed_sets, open_sets = boundary_sets(work)
          remove_obsolete_shapes(work, closed_sets)
          shapes = closed_shapes(work, closed_sets)
          separate_common_edges(shapes) if @separation
          extras, composites = open_geometry(work, grid, open_sets)
          shapes.concat(extras)
          decorate(grid, work, shapes)
          finish(grid, shapes, composites)
        end

        private

        def prepare_work(grid)
          work = Grid.new(grid.rows.map(&:dup))
          work.replace_type_on_line
          work.replace_point_markers_on_line
          work
        end

        def closed_shapes(work, closed_sets)
          closed_sets.filter_map { |set| closed_shape(work, set) }
        end

        # Single-cell open sets become small lines, multipart ones composites
        # of traced segments.
        def open_geometry(work, grid, open_sets)
          extras = []
          composites = []
          open_sets.each do |set|
            place_open(work, grid, set, extras, composites)
          end
          [extras, composites]
        end

        def place_open(work, grid, set, extras, composites)
          if set.size == 1
            add_small_line(extras, work, grid, set)
          else
            members = composite(work, set)
            composites << members if members.any?
          end
        end

        def add_small_line(extras, work, grid, set)
          line = small_line(work, grid, set)
          extras << line if line
        end

        def composite(work, set)
          members = open_shapes(work, set)
          members.each { |member| connect_ends_to_anchors(work, member) }
          members
        end

        def small_line(work, grid, set)
          cell = set.first
          return nil if grid.dashed_line_char?(cell.first, cell.last)

          line = line_shape(work, cell)
          return nil unless line

          connect_ends_to_anchors(work, line)
          line
        end

        def decorate(grid, work, shapes)
          assign_colors(grid, shapes)
          assign_markup(grid, shapes)
          build_arrowheads(work, shapes)
          build_point_markers(grid, shapes)
        end

        def finish(grid, shapes, composites)
          shapes = dedupe_shapes(shapes)
          texts = extract_texts(grid, shapes)
          Result.new(
            shapes: shapes, composites: composites, texts: texts,
            width: grid.width * cell_width, height: grid.height * cell_height,
            transparent: @transparent, shadows: @options.shadows,
            cell_width: cell_width, cell_height: cell_height
          )
        end

        # Every flood region's `*` ring, per distinct shape, deduplicated
        # and classified; mixed candidates are eliminated before classifying
        # again.
        def boundary_sets(work)
          candidates = candidate_boundaries(work)
          closed, = classify_boundaries(candidates, work)
          mixed = mixed_boundaries(candidates, closed, work)
          mixed.each { |set| resolve_mixed(set, closed, candidates, work) }
          closed, open = classify_boundaries(candidates, work)
          [closed, open]
        end

        def mixed_boundaries(candidates, _closed, work)
          candidates.select { |set| set.type(work) == CellSet::TYPE_MIXED }
        end

        def candidate_boundaries(work)
          found = []
          distinct_shapes(work).each do |set|
            found.concat(region_boundaries(work, set))
          end
          CellSet.remove_duplicates(found)
        end

        def classify_boundaries(sets, work)
          closed = []
          open = []
          sets.each do |set|
            kind = set.type(work)
            closed << set if kind == CellSet::TYPE_CLOSED
            open << set if kind == CellSet::TYPE_OPEN
          end
          [closed, open]
        end

        def resolve_mixed(set, closed, candidates, work)
          if closed.empty?
            candidates.delete(set)
            set.break_truly_mixed(work).each { |part| candidates << part }
          else
            subtract_and_split(set, closed, candidates, work)
          end
        end

        def subtract_and_split(set, closed, candidates, work)
          closed.each { |done| set.subtract_set(done) }
          return unless set.type(work) == CellSet::TYPE_OPEN

          candidates.delete(set)
          set.break_into_distinct_boundaries(work).each do |part|
            candidates << part
          end
        end

        def region_boundaries(work, set)
          found = []
          buffer = Grid.new(Array.new(work.height * 3) do
            " " * (work.width * 3)
          end)
          each_scaled_cell(work) do |col, row|
            found.concat(flood_region(buffer, work, set, col, row))
          end
          found
        end

        def each_scaled_cell(work)
          (work.height * 3).times do |row|
            (work.width * 3).times do |col|
              yield(col, row)
            end
          end
        end

        def flood_region(buffer, work, set, col, row)
          return [] unless buffer.blank_cell?(col, row)

          source = abstraction_buffer(work, set)
          boundaries = source.boundaries_expanding_from(col, row)
          return [] if boundaries.empty?

          mark_region(buffer, source, col, row, boundaries)
          [boundaries.make_scaled_one_third_equivalent]
        end

        def mark_region(buffer, source, col, row, boundaries)
          filled = source.fill_continuous_area(col, row, "*")
          buffer.fill_cells_with(filled, "*")
          buffer.fill_cells_with(boundaries, "-")
        end

        # Connected components of the 3x-scaled boundary cells.
        def distinct_shapes(work)
          all = CellSet.new
          work.all_boundaries.each { |cell| all.add(cell) }
          scaled_components(abstraction_buffer(work, all))
        end

        def scaled_components(buffer)
          buffer.all_non_blank.break_into_distinct.map do |component|
            scaled = CellSet.new
            component.each { |cell| scaled.add(cell.first / 3, cell.last / 3) }
            scaled
          end
        end

        def abstraction_buffer(source_grid, cell_set)
          AbstractCell.stamp_buffer(source_grid, cell_set)
        end

        # Drops the closed set that is the sum of the others it touches when
        # plotted filled (the jar's removeObsoleteShapes).
        def remove_obsolete_shapes(work, closed_sets)
          filled = closed_sets.map { |set| set.filled_equivalent(work) }
          doomed = filled.each_index.select { |index| obsolete?(filled, index) }
          doomed.reverse_each { |index| closed_sets.delete_at(index) }
        end

        def obsolete?(filled, index)
          mine = filled[index]
          others = touched_others(filled, index, mine)
          return false if others.size < 2

          family = [mine] + others
          largest = family.max_by(&:size)
          same_cells?(largest, family_sum(family - [largest]))
        end

        def touched_others(filled, index, mine)
          filled.each_with_index.filter_map do |other, other_index|
            next if other_index == index

            other if other.has_common_cells?(mine)
          end
        end

        def family_sum(parts)
          sum = CellSet.new
          parts.each { |part| part.each { |cell| sum.add(cell) } }
          sum
        end

        def same_cells?(set, other)
          set.cells.sort == other.cells.sort
        end

        def point_for_cell(grid, col, row)
          kind = point_type(grid, col, row)
          unless kind
            raise ArgumentError,
                  "cannot make point for cell #{col},#{row}"
          end

          Point.new(x: px_mid(col, cell_width), y: px_mid(row, cell_height),
                    type: kind, locked: false)
        end

        def point_type(grid, col, row)
          corner = corner_type(grid, col, row)
          return corner if corner

          :normal if grid.lines_end?(col, row) ||
            grid.intersection?(col, row)
        end

        def corner_type(grid, col, row)
          return :round if grid.corner?(col, row) && @round_corners
          return :normal if grid.normal_corner?(col, row)

          :round if grid.round_corner?(col, row)
        end

        def px_mid(cell, size) = (cell * size) + (size / 2)

        def new_shape(grid, set)
          Shape.new(points: [], kind: :rectangle, closed: true,
                    dashed: grid.contains_dashed_line?(set),
                    fill: nil, stroke: "#000000")
        end

        # The set is CLOSED per the type gate: a single cycle with no
        # branches, so the trace always returns to start.
        def closed_shape(grid, set)
          work = Grid.blank_like(grid)
          grid.copy_cells_to(set, work)
          shape = new_shape(grid, set)
          start = set.first
          add_corner_point(work, shape, start)
          walk_closed(work, shape, start, work.follow_cell(*start).first,
                      start)
          shape
        end

        def add_corner_point(work, shape, cell)
          shape.points << point_for_cell(work, *cell) if work.corner?(*cell)
        end

        def walk_closed(work, shape, start, cell, previous)
          add_corner_point(work, shape, cell)
          until cell == start
            next_cells = work.follow_cell(*cell, previous)
            previous = cell
            cell = next_cells.first
            add_corner_point(work, shape, cell) unless cell == start
          end
        end

        def shape_edges(shape)
          list = shape.points.each_cons(2).map do |a, b|
            Edge.new(a, b, shape)
          end
          list << Edge.new(shape.points.last, shape.points.first, shape)
          list
        end

        def separate_common_edges(shapes)
          offset = min_cell_dimension / 5.0
          edges = shapes.flat_map { |shape| shape_edges(shape) }
          touching_pairs(edges).each do |first, second|
            shift_pair(first, second, offset)
          end
        end

        def touching_pairs(edges)
          pairs = []
          edges.each_with_index do |edge, index|
            edges[(index + 1)..].each do |other|
              pairs << [edge, other] if edge.touches_with?(other)
            end
          end
          pairs
        end

        def shift_pair(first, second, offset)
          shifted = []
          [first, second].each do |edge|
            next if shifted.include?(edge)

            move_inwards(edge, offset)
            shifted << edge
          end
        end

        def move_inwards(edge, offset)
          shift = inward_shift(edge, offset)
          return unless shift

          apply_shift(edge, shift)
        end

        def apply_shift(edge, shift)
          edge.start_point.x += shift.first
          edge.start_point.y += shift.last
          edge.end_point.x += shift.first
          edge.end_point.y += shift.last
        end

        def inward_shift(edge, offset)
          mid = edge_middle(edge)
          if edge.horizontal?
            [0, probe_shift(offset, edge, mid.first, nil)]
          elsif edge.vertical?
            [probe_shift(offset, edge, nil, mid.last), 0]
          end
        end

        def edge_middle(edge)
          [(edge.start_point.x + edge.end_point.x) / 2,
           (edge.start_point.y + edge.end_point.y) / 2]
        end

        # Probes both sides of the edge; the side inside the shape says
        # which way inwards is.
        def probe_shift(offset, edge, probe_x, probe_y)
          return -offset if inside_probe?(edge, probe_x, probe_y, -0.05)
          return offset if inside_probe?(edge, probe_x, probe_y, 0.05)

          0
        end

        def inside_probe?(edge, probe_x, probe_y, delta)
          point_x = probe_x.nil? ? edge_middle(edge).first : probe_x + delta
          point_y = probe_y.nil? ? edge_middle(edge).last : probe_y + delta
          polygon_contains?(edge.owner, point_x, point_y)
        end

        def polygon_contains?(shape, probe_x, probe_y)
          points = shape.points
          return false if points.size < 3

          ray_cast(points, probe_x, probe_y)
        end

        def ray_cast(points, probe_x, probe_y)
          inside = false
          previous = points.size - 1
          points.each_with_index do |vertex, index|
            inside ^= crosses_ray?(vertex, points[previous], probe_x, probe_y)
            previous = index
          end
          inside
        end

        def crosses_ray?(vertex, other, probe_x, probe_y)
          return false unless (vertex.y > probe_y) != (other.y > probe_y)

          probe_x < (((other.x - vertex.x) * (probe_y - vertex.y)) /
            (other.y - vertex.y)) + vertex.x
        end

        def min_cell_dimension
          [cell_width, cell_height].min
        end

        def line_shape(grid, cell)
          shape = Shape.new(points: [], kind: :line, closed: false,
                            dashed: false, fill: nil, stroke: "#000000")
          if grid.horizontal_line?(*cell)
            add_horizontal_points(shape, cell.first, cell.last)
          elsif grid.vertical_line?(*cell)
            add_vertical_points(shape, cell.first, cell.last)
          else
            return nil
          end
          shape
        end

        def cell_point(at_x, at_y)
          Point.new(x: at_x, y: at_y, type: :normal, locked: false)
        end

        def add_horizontal_points(shape, col, row)
          mid_y = cell_top(row) + (cell_height / 2)
          shape.points << cell_point(cell_left(col), mid_y)
          shape.points << cell_point(line_end_x(col), mid_y)
        end

        def add_vertical_points(shape, col, row)
          mid_x = cell_left(col) + (cell_width / 2)
          shape.points << cell_point(mid_x, cell_top(row))
          shape.points << cell_point(mid_x, line_end_y(row))
        end

        def line_end_x(col) = (cell_left(col) + cell_width) - 1

        def line_end_y(row) = (cell_top(row) + cell_height) - 1

        def cell_left(col) = col * cell_width

        def cell_top(row) = row * cell_height

        def open_shapes(grid, set)
          work = Grid.blank_like(grid)
          grid.copy_cells_to(set, work)
          start = open_start(work, set)
          return [] if start.nil?

          next_cells = work.follow_cell(*start)
          return [] if next_cells.nil? || next_cells.empty?

          trace = OpenTrace.new(work, Set.new, [])
          grow_edges(trace, next_cells.first, start)
          infect_dashes(trace.drawn)
        end

        def open_start(work, set)
          found = nil
          set.each do |cell|
            if work.lines_end?(*cell)
              found = cell
              break
            end
          end
          found
        end

        def infect_dashes(members)
          return members unless members.any?(&:dashed)

          members.each { |member| member.dashed = true }
          members
        end

        # One traced segment per recursive branch, exactly the jar's
        # growEdgesFromCell.
        def grow_edges(trace, cell, previous_cell)
          trace.visited << previous_cell
          segment = open_segment(trace.work, previous_cell)
          state = WalkState.new(cell, previous_cell, 0)
          outcome = segment_walk(trace, segment, state)
          trace.drawn << segment unless outcome.nil?
        end

        def open_segment(work, cell)
          shape = Shape.new(points: [], kind: :line, closed: false,
                            dashed: false, fill: nil, stroke: "#000000")
          shape.points << point_for_cell(work, *cell)
          shape.dashed = true if work.dashed_line_char?(*cell)
          shape
        end

        def segment_walk(trace, segment, state)
          state.steps += 1
          return nil if state.steps > 1000
          if trace.work.lines_end?(*state.cell)
            return visit_and_end(trace, segment,
                                 state.cell)
          end

          visit_open_cell(trace, segment, state.cell)
          step_open(trace, segment, state)
        end

        def step_open(trace, segment, state)
          next_cells = trace.work.follow_cell(*state.cell, state.previous)
          if next_cells && next_cells.size == 1
            state.previous = state.cell
            state.cell = next_cells.first
            segment_walk(trace, segment, state)
          else
            branch_open(trace, state.cell, next_cells)
            :branch
          end
        end

        def visit_and_end(trace, segment, cell)
          visit_open_cell(trace, segment, cell)
          :end
        end

        def visit_open_cell(trace, segment, cell)
          trace.visited << cell
          segment.points << point_for_cell(trace.work, *cell) if
            point_cell?(trace.work, cell)
          segment.dashed = true if trace.work.dashed_line_char?(*cell)
        end

        def branch_open(trace, cell, next_cells)
          next_cells.to_a.each do |next_cell|
            grow_edges(trace, next_cell, cell)
          end
        end

        def point_cell?(grid, cell)
          grid.corner?(*cell) || grid.intersection?(*cell) ||
            grid.stub?(*cell) || grid.lines_end?(*cell)
        end

        def connect_ends_to_anchors(grid, shape)
          anchor_end_to(grid, shape.points[1], shape.points.first)
          anchor_end_to(grid, shape.points[-2], shape.points.last)
        end

        def anchor_end_to(grid, next_point, lines_end)
          anchor_cell = possible_anchor_cell(next_point, lines_end)
          return unless anchor?(grid, anchor_cell)

          lines_end.x = px_mid(anchor_cell.first, cell_width)
          lines_end.y = px_mid(anchor_cell.last, cell_height)
          lines_end.locked = true
        end

        def anchor?(grid, cell)
          grid.arrowhead?(*cell) || grid.corner?(*cell) ||
            grid.intersection?(*cell)
        end

        # One cell back towards the line's body, the way the jar finds the
        # corner or arrowhead a line end should meet.
        def possible_anchor_cell(next_point, lines_end)
          shift = anchor_shift(next_point, lines_end)
          [(lines_end.x + shift.first) / cell_width,
           (lines_end.y + shift.last) / cell_height]
        end

        def anchor_shift(next_point, lines_end)
          if next_point.y < lines_end.y
            [0, cell_height]
          elsif next_point.y > lines_end.y
            [0, -cell_height]
          elsif next_point.x < lines_end.x
            [cell_width, 0]
          else
            [-cell_width, 0]
          end
        end

        def assign_colors(grid, shapes)
          grid.color_codes.each do |cell, color|
            container = smallest_shape_containing(shapes, mid_point(cell))
            container.fill = color if container
          end
        end

        def assign_markup(grid, shapes)
          grid.markup_tags.each do |cell, tag|
            container = smallest_shape_containing(shapes, mid_point(cell))
            next unless container

            container.kind = MARKUP_TYPES.fetch(tag, :rectangle)
          end
        end

        def mid_point(cell)
          [px_mid(cell.first, cell_width), px_mid(cell.last, cell_height)]
        end

        def smallest_shape_containing(shapes, point)
          containing = nil
          shapes.each do |shape|
            next unless polygon_contains?(shape, point.first, point.last)

            containing = shape if containing.nil? ||
              bounds_area(shape) < bounds_area(containing)
          end
          containing
        end

        def bounds_area(shape)
          min_x, min_y, max_x, max_y = shape.bounds
          (max_x - min_x) * (max_y - min_y)
        end

        def build_arrowheads(grid, shapes)
          grid.arrowheads.each { |cell| shapes << arrowhead_shape(grid, cell) }
        end

        def arrowhead_shape(grid, cell)
          points = arrowhead_points(grid, cell)

          Shape.new(
            points: points.map do |px, py|
              Point.new(x: px, y: py, type: :normal, locked: false)
            end,
            kind: :arrowhead, closed: true, dashed: false,
            fill: "#000000", stroke: "#000000"
          )
        end

        def arrowhead_points(grid, cell)
          col, row = cell
          box = CellBox.new(col * cell_width, row * cell_height,
                            px_mid(col, cell_width), px_mid(row, cell_height))
          head_points(grid, col, row, box)
        end

        def head_points(grid, col, row, box)
          if grid.north_arrowhead?(col, row) || grid.south_arrowhead?(col, row)
            vertical_points(grid, col, row, box)
          else
            horizontal_points(grid, col, row, box)
          end
        end

        def vertical_points(grid, col, row, box)
          right = box.left + cell_width
          bottom = box.top + cell_height
          return [[box.mid_x, box.top], [box.left, bottom], [right, bottom]] if
            grid.north_arrowhead?(col, row)

          [[box.left, box.top], [box.mid_x, bottom], [right, box.top]]
        end

        def horizontal_points(grid, col, row, box)
          right = box.left + cell_width
          bottom = box.top + cell_height
          return [[right, box.top], [box.left, box.mid_y], [right, bottom]] if
            grid.west_arrowhead?(col, row)

          [[box.left, box.top], [right, box.mid_y], [box.left, bottom]]
        end

        def build_point_markers(grid, shapes)
          grid.point_markers_on_line.each do |cell|
            shapes << Shape.new(
              points: [Point.new(x: px_mid(cell.first, cell_width),
                                 y: px_mid(cell.last, cell_height),
                                 type: :normal, locked: false)],
              kind: :point_marker, closed: false, dashed: false,
              fill: "#ffffff", stroke: "#000000"
            )
          end
        end

        def dedupe_shapes(shapes)
          shapes.each_with_object([]) do |shape, kept|
            kept << shape unless kept.any? do |other|
              same_points?(shape, other)
            end
          end
        end

        def same_points?(shape, other)
          return false if shape.points.size != other.points.size

          point_keys(shape) == point_keys(other)
        end

        def point_keys(shape)
          shape.points.map { |point| [point.x.to_i, point.y.to_i] }.sort
        end

        # Text runs: the grid minus its non-text, grouped into words and
        # lines, positioned and aligned the jar's way.
        def extract_texts(grid, shapes)
          work = Grid.new(grid.rows.map(&:dup))
          work.remove_non_text
          runs = text_runs(work, font_for(cell_height))
          color_text_runs(runs, shapes)
          runs
        end

        def text_runs(work, base_size)
          runs = []
          text_groups(work).each do |isolation|
            isolation.strings.each do |cell, string|
              runs << text_run(isolation, cell, string, base_size)
            end
          end
          runs
        end

        def text_groups(work)
          grouped = Grid.new(work.rows.map(&:dup))
          grouped.fill_cells_with(grouped.blanks_between_characters, "|")
          grouped.all_non_blank.break_into_distinct.map do |component|
            isolation = Grid.new(Array.new(work.height) { " " * work.width })
            work.copy_cells_to(component, isolation)
            isolation
          end
        end

        def text_run(isolation, cell, string, base_size)
          span = run_span(cell, string)
          size = base_size
          anchor, anchor_x = anchor_for(isolation, cell, string, span)
          TextRun.new(x: anchor_x, y: baseline(cell.last, size),
                      string: string, font_size: size, anchor: anchor,
                      fill: "#000000")
        end

        def run_span(cell, string)
          col = cell.first
          last_col = col + string.length - 1
          [col * cell_width, (last_col + 1) * cell_width]
        end

        def anchor_for(isolation, cell, string, span)
          last_col = cell.first + string.length - 1
          anchor = text_anchor(starts_of(isolation, cell),
                               ends_of(isolation, cell, last_col))
          [anchor, anchor_position(anchor, span.first, span.last)]
        end

        def starts_of(isolation, cell)
          other_strings_starting_at(isolation, cell.first, cell.last)
        end

        def ends_of(isolation, cell, last_col)
          other_strings_ending_at(isolation, last_col, cell.last)
        end

        def text_anchor(starts, ends)
          return :middle if align_centre?(starts, ends)
          return :end if ends.positive? && (starts.zero? || ends > starts)

          :start
        end

        def align_centre?(starts, ends)
          (starts.zero? && ends.zero?) || (ends == starts && ends.positive?)
        end

        def anchor_position(anchor, min_x, max_x)
          anchor == :end ? max_x : (min_x + max_x) / 2
        end

        # A strings-start: a non-blank cell with a blank to its west, on a
        # row other than the run we are placing.
        def other_strings_starting_at(isolation, col, own_row)
          (0...isolation.height).count do |row|
            next false if row == own_row || col.zero?

            !isolation.blank_cell?(col, row) &&
              isolation.blank_cell?(col - 1, row)
          end
        end

        # A strings-end: a non-blank cell with a blank to its east.
        def other_strings_ending_at(isolation, last_col, own_row)
          (0...isolation.height).count do |row|
            next false if row == own_row

            !isolation.blank_cell?(last_col, row) &&
              isolation.blank_cell?(last_col + 1, row)
          end
        end

        def baseline(row, size)
          top = row * cell_height
          bottom = top + cell_height
          center = (bottom - top) / 2
          z_height = 0.72 * size
          bottom - (center - (z_height / 2)).abs
        end

        ASCENT_RATIO = 0.78
        WIDTH_RATIO = 0.55
        private_constant :ASCENT_RATIO, :WIDTH_RATIO

        # The jar walks a Dialog Bold size up and down by half points until
        # the ascent crosses the cell height. Pure; public for pins.
        def font_for(pixel_height)
          size = 12.0
          direction = size * ASCENT_RATIO > pixel_height ? -1 : 1
          size_search(size + direction, direction, pixel_height)
        end

        def size_search(size, direction, pixel_height)
          while size.positive?
            ascent = size * ASCENT_RATIO
            if direction == 1
              return size - 0.5 if ascent > pixel_height
            elsif ascent < pixel_height
              return size
            end
            size += (direction * 0.5)
          end
          size
        end

        def string_fits?(string, size, max_width)
          (string.length * size * WIDTH_RATIO) <= max_width
        end

        def smaller_size(string, max_width)
          size = 12.0
          direction = string.length * size * WIDTH_RATIO > max_width ? -1 : 1
          width_search(string, size + direction, direction, max_width)
        end

        def width_search(string, size, direction, max_width)
          while size.positive?
            width = string.length * size * WIDTH_RATIO
            if direction == 1
              return size - 1 if width > max_width
            elsif width < max_width
              return size
            end
            size += direction
          end
          size
        end

        # Text over a dark fill reads white (the jar flips it through
        # isColorDark: the max colour channel under 200).
        def color_text_runs(runs, shapes)
          runs.each do |run|
            container = smallest_shape_intersecting(shapes, run)
            next unless container&.fill

            run.fill = "#ffffff" if dark_color?(container.fill)
          end
        end

        def smallest_shape_intersecting(shapes, run)
          shapes.select { |shape| intersects_rect?(shape, run) }
            .min_by { |shape| bounds_area(shape) }
        end

        def intersects_rect?(shape, run)
          min_x, min_y, max_x, max_y = shape.bounds
          return false if run.x > max_x || text_right(run) < min_x
          return false if text_top(run) > max_y || text_bottom(run) < min_y

          true
        end

        def text_right(run)
          run.x + (run.string.length * run.font_size * WIDTH_RATIO)
        end

        def text_top(run) = run.y - run.font_size

        def text_bottom(run) = run.y + 2

        def dark_color?(hex)
          channels = hex.delete_prefix("#").scan(/../).map do |pair|
            pair.to_i(16)
          end
          channels.max < 200
        end

        # The pure jar-metric walks, public for the unit pins.
        public :font_for, :smaller_size, :string_fits?
      end
    end
  end
end
