#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates the ArchiMate sprite table from the pinned PlantUML checkout,
# one jar probe per sprite. The jar draws an `archimate` element's icon as
# a single absolute-coordinate <path> in the element's SVG; this script
# renders `archimate #red "X" as x <<NAME>>` for every sprite in the
# checkout's resources/sprites/archimate, extracts that path verbatim, and
# records the geometry the renderer needs to place it: the path's bounding
# box relative to the element box (jar 1.2026.6 draws one element at
# x=7 y=7, so box centre and top are fixed across probes).
#
#   PATH="$HOME/src/etassia/tools/bin:$PATH" \
#     ruby scripts/build_archimate_sprites.rb --upstream <plantuml checkout> \
#       [--rust <etassia-rs component archimate_sprites.rs>]
#
# The checkout must be at the commit named in spec/plantuml/pin.json, the
# same pin the corpus extractor refuses any other of. Output is written
# atomically to lib/etassia/notation/plantuml/node_graph/archimate_sprites.rb;
# the generated file is committed, so rendering never needs the jar. With
# --rust, the same probes are also emitted as the Rust renderer's sprite
# table, so both languages consume one probe run.
require "fileutils"
require "json"
require "open3"
require "optparse"
require "rexml/document"

module ArchimateSprites
  ROOT = File.realpath("#{__dir__}/..")
  TABLE_PATH = File.join(ROOT, "lib/etassia/notation/plantuml/" \
                               "node_graph/archimate_sprites.rb")
  PIN_PATH = File.join(ROOT, "spec/plantuml/pin.json")
  SPRITE_DIR = "src/main/resources/sprites/archimate"

  Box = Struct.new(:left, :top, :width) do
    def center = left + (width / 2)
  end

  module_function

  def build(upstream, rust: nil)
    pin_sha(upstream)
    rows, failures = measure_all(sprite_names(upstream))
    write_table(rows, upstream)
    verify(rows)
    write_rust(rows, upstream, rust) if rust
    puts summary(rows.size, failures)
  end

  # The emitted chunked strings must rebuild every probed path byte for
  # byte; a chunking bug corrupts icons silently otherwise.
  def verify(rows)
    require TABLE_PATH
    loaded = Etassia::Notation::PlantUML::NodeGraph::ArchimateSprites::TABLE
    broken = rows.keys.reject do |name|
      loaded[name] == rows[name]
    end
    abort "the written table differs from the probes: #{broken.join(', ')}" \
      unless broken.empty?
  end

  def sprite_names(upstream)
    names = Dir.glob("*.svg", base: File.join(upstream, SPRITE_DIR)).sort
    abort "no sprites under #{SPRITE_DIR}" if names.empty?
    names
  end

  def measure_all(names)
    rows = {}
    failures = []
    names.each do |file|
      name = file.delete_suffix(".svg")
      row = probe(name)
      row ? rows[name] = row : failures << name
    end
    [rows, failures]
  end

  def summary(count, failures)
    tail = failures.empty? ? "" : " (skipped: #{failures.join(', ')})"
    "generated #{count} sprites#{tail}"
  end

  def pin_sha(upstream)
    sha = JSON.parse(File.read(PIN_PATH)).fetch("upstream").fetch("sha")
    current, = Open3.capture2("git", "-C", upstream, "rev-parse", "HEAD")
    return if current.strip == sha

    abort "upstream checkout is at #{current.strip}, pin.json pins #{sha}"
  end

  # The icon path and its box-relative geometry from one jar render, or
  # nil when the jar refuses the sprite name.
  def probe(name)
    entity = rendered_entity(name)
    return unless entity

    geometry(entity)
  end

  def rendered_entity(name)
    source = "@startuml\narchimate #red \"X\" as x <<#{name}>>\n@enduml\n"
    stdout, _stderr, status = Open3.capture3("plantuml", "-svg", "-pipe",
                                             stdin_data: source)
    return unless status.success?

    root = REXML::Document.new(stdout).root
    return unless root

    REXML::XPath.first(root, "//g[@class='entity']")
  end

  def geometry(entity)
    rect = entity.elements["rect"]
    path = entity.elements["path"]
    return unless path && rect

    measure(path.attributes["d"], box_of(rect))
  end

  def box_of(rect)
    Box.new(rect.attributes["x"].to_f, rect.attributes["y"].to_f,
            rect.attributes["width"].to_f)
  end

  def measure(text, box)
    min_x, min_y, max_x, max_y = PathBounds.of(text)
    center = (min_x + max_x) / 2
    {
      d: text,
      w: span(max_x, min_x), h: span(max_y, min_y),
      dx: offset(center, box.center), top: min_y - box.top,
      cx: center.round(4), cy_top: min_y.round(4)
    }
  end

  def span(high, low) = (high - low).round(4)

  def offset(one, other) = (one - other).round(4)

  def write_table(rows, upstream)
    sha = JSON.parse(File.read(PIN_PATH)).fetch("upstream").fetch("sha")
    body = "# frozen_string_literal: true\n\n#{header_comment(upstream, sha)}"
    body << table_block(rows)
    write_atomically(body)
  end

  def header_comment(upstream, sha)
    sprite_count = Dir.glob(
      "*.svg", base: File.join(upstream, SPRITE_DIR)
    ).count
    <<~COMMENT
      # GENERATED by scripts/build_archimate_sprites.rb from the pinned
      # PlantUML checkout #{sha[0, 12]} (#{sprite_count} SVG sprites under
      # resources/sprites/archimate), one jar 1.2026.6 render per sprite;
      # do not hand-edit. Each entry carries the icon path exactly as the
      # jar emits it (absolute coordinates for an element drawn at x=7
      # y=7), plus the placement geometry: w/h the path bounding box, dx
      # the bbox centre right of the box centre, top the bbox top below
      # the box top, and cx/cy_top the absolute bbox centre and top the
      # path was probed at.

      module Etassia
        module Notation
          module PlantUML
            module NodeGraph
              # The ArchiMate icon vocabulary, keyed by the `<<name>>`
              # stereotype the jar resolves into `$archimate/<name>`.
              module ArchimateSprites
    COMMENT
  end

  def table_block(rows)
    inner = rows.map { |name, row| row_line(name, row) }.join(",\n")
    "#{table_opening}#{inner},\n#{table_closing}"
  end

  def table_opening
    "          TABLE = {\n"
  end

  def table_closing
    "          }.freeze\n        end\n      end\n    end\n  end\nend\n"
  end

  def row_line(name, row)
    entry = "            "
    key = "              "
    "#{entry}#{name.inspect} => {\n" \
      "#{key}d: #{chunked(row[:d])},\n" \
      "#{key}w: #{row[:w]}, h: #{row[:h]},\n" \
      "#{key}dx: #{row[:dx]}, top: #{row[:top]},\n" \
      "#{key}cx: #{row[:cx]}, cy_top: #{row[:cy_top]}\n" \
      "#{entry}}"
  end

  # The path on several physical lines (each under the line-length limit)
  # through adjacent string literals. The split point is always a space
  # the jar emitted between path commands, so every line but the last
  # keeps that space as its trailing character and the concatenation
  # rebuilds the path byte for byte.
  def chunked(text)
    lines = [""]
    text.split.each { |segment| append_chunk(lines, segment) }
    lines.map!(&:inspect)
    lines.join(" \\\n                 ")
  end

  def append_chunk(lines, segment)
    candidate = lines.last.empty? ? segment : "#{lines.last} #{segment}"
    if candidate.length > 57
      lines.last << " " unless lines.last.empty?
      lines << segment
    else
      lines[-1] = candidate
    end
  end

  def write_atomically(body)
    tmp = "#{TABLE_PATH}.tmp#{Process.pid}"
    File.write(tmp, body)
    File.rename(tmp, TABLE_PATH)
  end

  # The same probes as the Ruby table, as the Rust renderer's static
  # vocabulary, so one probe run feeds both languages.
  def write_rust(rows, upstream, path)
    body = +""
    body << rust_header(upstream)
    body << <<~RUST
      /// One sprite row of the Ruby `ArchimateSprites::TABLE`: the icon
      /// path exactly as the jar emits it plus its placement geometry
      /// (w/h the path bounding box, dx the bbox centre right of the box
      /// centre, top the bbox top below the box top, cx/cy_top the
      /// absolute bbox centre and top the path was probed at).
      #[derive(Debug)]
      pub struct Sprite {
          pub d: &'static str,
          pub w: f64,
          pub h: f64,
          pub dx: f64,
          pub top: f64,
          pub cx: f64,
          pub cy_top: f64,
      }

      #[rustfmt::skip]
      pub static TABLE: &[(&str, Sprite)] = &[
    RUST
    body << rows.map { |name, row| rust_row(name, row) }.join(",\n")
    body << ",\n];\n"
    FileUtils.mkdir_p(File.dirname(path))
    tmp = "#{path}.tmp#{Process.pid}"
    File.write(tmp, body)
    File.rename(tmp, path)
  end

  def rust_header(upstream)
    sha = JSON.parse(File.read(PIN_PATH)).fetch("upstream").fetch("sha")
    sprite_count = Dir.glob(
      "*.svg", base: File.join(upstream, SPRITE_DIR)
    ).count
    <<~RUST
      // GENERATED by scripts/build_archimate_sprites.rb from the pinned
      // PlantUML checkout #{sha[0, 12]} (#{sprite_count} SVG sprites under
      // resources/sprites/archimate), one jar 1.2026.6 render per sprite;
      // do not hand-edit. The same probes as the Ruby
      // ArchimateSprites::TABLE, one source of truth for both languages.

    RUST
  end

  def rust_row(name, row)
    "    (#{name.inspect}, Sprite {\n        " \
      "d: #{row[:d].inspect},\n        " \
      "w: #{row[:w]}, h: #{row[:h]},\n        " \
      "dx: #{row[:dx]}, top: #{row[:top]},\n        " \
      "cx: #{row[:cx]}, cy_top: #{row[:cy_top]}\n    " \
      "})"
  end

  # Conservative bounding box of an absolute-coordinate SVG path: every
  # command's coordinate pairs, with A contributing its radii around the
  # endpoint. Control points make the box slightly generous, which only
  # softens the centring.
  module PathBounds
    Bounds = Struct.new(:min_x, :min_y, :max_x, :max_y) do
      def grow(pos_x, pos_y)
        self.min_x = [min_x, pos_x].min
        self.min_y = [min_y, pos_y].min
        self.max_x = [max_x, pos_x].max
        self.max_y = [max_y, pos_y].max
      end
    end

    Cursor = Struct.new(:pos_x, :pos_y)

    module_function

    def of(text)
      tokens = text.scan(/[MmLlCcAaZzVvHh]|-?\d+(?:\.\d+)?/)
      bounds = Bounds.new(Float::INFINITY, Float::INFINITY,
                          -Float::INFINITY, -Float::INFINITY)
      cursor = Cursor.new
      consume_all(bounds, cursor, tokens)
      [bounds.min_x, bounds.min_y, bounds.max_x, bounds.max_y]
    end

    def consume_all(bounds, cursor, tokens)
      index = 0
      while index < tokens.length
        index += consume(bounds, cursor, tokens, index)
      end
      index
    end

    def consume(bounds, cursor, tokens, index)
      letter = tokens[index]
      return 1 unless letter.match?(/\A[A-Za-z]\z/)

      moved = step(bounds, cursor, letter, tokens, index)
      cursor.pos_x = moved[0]
      cursor.pos_y = moved[1]
      moved[2] + 1
    end

    def step(bounds, cursor, letter, tokens, index)
      case letter
      when /\A[MmLl]\z/i then pair(bounds, tokens, index + 1)
      when /\A[Cc]\z/i then curve(bounds, tokens, index + 1)
      when /\A[Aa]\z/i then arc(bounds, tokens, index + 1)
      when /\A[Vv]\z/i then straight(bounds, cursor, tokens, index + 1, true)
      when /\A[Hh]\z/i then straight(bounds, cursor, tokens, index + 1, false)
      else [cursor.pos_x, cursor.pos_y, 0]
      end
    end

    def pair(bounds, tokens, index)
      first = tokens[index].to_f
      second = tokens[index + 1].to_f
      bounds.grow(first, second)
      [first, second, 2]
    end

    def curve(bounds, tokens, index)
      2.times { |step| pair(bounds, tokens, index + (2 * step)) }
      last = pair(bounds, tokens, index + 4)
      [last[0], last[1], 6]
    end

    def arc(bounds, tokens, index)
      radius_x = tokens[index].to_f
      radius_y = tokens[index + 1].to_f
      reached = pair(bounds, tokens, index + 5)
      grow_around(bounds, reached, radius_x, radius_y)
      [reached[0], reached[1], 7]
    end

    def grow_around(bounds, center, radius_x, radius_y)
      bounds.grow(center[0] + radius_x, center[1] + radius_y)
      bounds.grow(center[0] - radius_x, center[1] - radius_y)
    end

    def straight(bounds, cursor, tokens, index, vertical)
      value = tokens[index].to_f
      pos_x = vertical ? cursor.pos_x : value
      pos_y = vertical ? value : cursor.pos_y
      bounds.grow(pos_x, pos_y)
      [pos_x, pos_y, 1]
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = {}
  OptionParser.new do |opts|
    opts.banner = "usage: build_archimate_sprites.rb --upstream <checkout>"
    opts.on("--upstream DIR", "the pinned PlantUML checkout") do |dir|
      options[:upstream] = dir
    end
    opts.on("--rust PATH", "also emit the Rust sprite table at PATH") do |path|
      options[:rust] = path
    end
  end.parse!
  upstream = options[:upstream]
  abort "usage: build_archimate_sprites.rb --upstream <checkout>" unless
    upstream && File.directory?(upstream)

  ArchimateSprites.build(upstream, rust: options[:rust])
end
