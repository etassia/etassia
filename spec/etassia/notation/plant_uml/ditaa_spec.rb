# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml"

# Requiring an external notation registers it; restore the suite baseline
# and register inside the isolated context per example.
Etassia::Notation.send(:entries).delete(:plantuml)

RSpec.describe Etassia::Notation::PlantUML::Ditaa do
  include_context "with an isolated notation registry"

  before do
    Etassia::Notation.register(Etassia::Notation::PlantUML) unless
      Etassia::Notation.send(:entries).key?(:plantuml)
  end

  def wrap(*lines, flags: "")
    "@startditaa#{flags}\n#{lines.join("\n")}\n@endditaa\n"
  end

  def parsed(*lines, flags: "")
    described_class.parse(wrap(*lines, flags: flags))
  end

  def diagram(*lines, flags: "")
    parsed(*lines, flags: flags).diagram
  end

  def rendered(*lines, flags: "")
    given = parsed(*lines, flags: flags)
    layout = given.transform.new.call(given.diagram)
    given.renderer.new.render(layout).to_xml
  end

  it "detects an @startditaa wrapper" do
    expect(described_class.ditaa?(wrap("+---+"))).to be(true)
  end

  it "leaves other sources alone" do
    expect(described_class.ditaa?("@startmindmap\n* root\n@endmindmap\n"))
      .to be(false)
  end

  it "declares the ditaa diagram type" do
    expect(parsed("+---+").type).to eq(:ditaa_diagram)
  end

  it "reads a box as one closed shape on the jar's canvas" do
    result = diagram("+---------+", "|  Hello  |", "+---------+")

    expect([result.width, result.height]).to eq([150, 98])
  end

  it "closes the box into a single shape" do
    result = diagram("+---------+", "|  Hello  |", "+---------+")

    expect(result.shapes.size).to eq(1)
  end

  it "centres the box's text" do
    texts = diagram("+-----+", "| Abc |", "+-----+").texts

    expect(texts.first.anchor).to eq(:middle)
  end

  it "keeps the box's text string" do
    texts = diagram("+-----+", "| Abc |", "+-----+").texts

    expect(texts.first.string).to eq("Abc")
  end

  it "dedents the body's common leading spaces" do
    result = diagram("   +---+", "   | x |", "   +---+")

    expect([result.width, result.height]).to eq([90, 98])
  end

  it "drops trailing blank rows like the jar" do
    result = diagram("+---+", "| x |", "+---+", "", "")

    expect(result.height).to eq(98)
  end

  it "reads the start line's flags" do
    options = described_class.options("@startditaa -S -r -T -E scale=2.5")

    expect(options.shadows).to be(false)
  end

  it "rounds corners with -r" do
    options = described_class.options("@startditaa -r")

    expect(options.round_corners).to be(true)
  end

  it "makes the background transparent with -T" do
    options = described_class.options("@startditaa -T")

    expect(options.transparent).to be(true)
  end

  it "drops separation with -E" do
    options = described_class.options("@startditaa -E")

    expect(options.separation).to be(false)
  end

  it "reads scale= as a float" do
    options = described_class.options("@startditaa scale=2.5")

    expect(options.scale).to eq(2.5)
  end

  it "keeps every option on by default" do
    options = described_class.options("@startditaa")

    expect(options.separation).to be(true)
  end

  it "keeps shadows on by default" do
    options = described_class.options("@startditaa")

    expect(options.shadows).to be(true)
  end

  it "rescales the canvas with scale=" do
    result = diagram("+---+", "| x |", "+---+", flags: " scale=2.0")

    expect([result.width, result.height]).to eq([180, 196])
  end

  it "accepts @enduml as the closing tag" do
    source = "@startditaa\n+---+\n@enduml\n"

    expect(described_class.parse(source).diagram.width).to eq(90)
  end

  it "renders shadows by default" do
    svg = rendered("+---+", "| x |", "+---+")

    expect(svg).to include("#969696")
  end

  it "renders a background by default" do
    svg = rendered("+---+", "| x |", "+---+")

    expect(svg).to include("<rect")
  end

  it "omits shadows and background with -S -T" do
    svg = rendered("+---+", "| x |", "+---+", flags: " -T -S")

    expect(svg).not_to include("#969696")
  end

  it "keeps no background rect with -T" do
    svg = rendered("+---+", "| x |", "+---+", flags: " -T -S")

    expect(svg).not_to include("<rect")
  end

  it "renders the document shape with quadratic curves" do
    svg = rendered("+-----+", "| {d} |", "+-----+")

    expect(svg).to include("Q ")
  end

  it "renders the ellipse shape with cubic curves" do
    svg = rendered("+-----+", "| {o} |", "+-----+")

    expect(svg).to include("C ")
  end

  it "fills a shape carrying a colour code" do
    svg = rendered("+--------+", "| cF00   |", "+--------+")

    expect(svg).to include('fill="#ff0000"')
  end

  it "rewrites human colour codes on the grid" do
    svg = rendered("+--------+", "| cRED   |", "+--------+")

    expect(svg).to include('fill="#ee3322"')
  end

  it "dashes a shape drawn with dashed lines" do
    svg = rendered("+======+", ":  x   :", "+======+")

    expect(svg).to include("stroke-dasharray")
  end

  it "renders arrowheads as filled triangles" do
    svg = rendered("+---+     ", "| A | --> B", "+---+     ")

    expect(svg).to match(/M \d+ \d+ L \d+ \d+ L \d+ \d+ Z/)
  end

  it "renders point markers as white circles" do
    svg = rendered("---*---", "   |   ", "   v   ")

    expect(svg).to include("<circle")
  end

  it "turns bullets into the bullet glyph" do
    texts = diagram("+--------+", "| o Item |", "+--------+").texts

    expect(texts.map(&:string)).to include("•Item")
  end

  it "separates shared edges of touching boxes" do
    svg = rendered("+---------+", "| +-----+ |", "| +-----+ |",
                   "+---------+")

    expect(svg).to include("<path")
  end

  it "keeps round corners with -r" do
    svg = rendered("+---+", "| x |", "+---+", flags: " -r")

    expect(svg).to include("Q ")
  end

  it "traces an open connector between boxes" do
    svg = rendered("A ----- B", "      |  ", "      v  ")

    expect(svg).to include('fill="none"')
  end

  describe "grid reading" do
    def grid(*lines)
      Etassia::Diagram::Ditaa::Grid.from_lines(lines)
    end

    it "pads rows and borders the buffer" do
      expect([grid("+---+", "| x |", "+---+").width,
              grid("+---+", "| x |", "+---+").height]).to eq([9, 7])
    end

    it "expands tabs to the next stop" do
      expect(grid("\tA").get(10, 2)).to eq("A")
    end

    it "replaces letters on lines with line characters" do
      marked = grid("+---+", "| x |", "+---+")
      marked.replace_type_on_line

      expect(marked.get(2, 2)).to eq("+")
    end

    it "replaces point markers on lines" do
      marked = grid("-*--")
      marked.replace_point_markers_on_line

      expect(marked.get(3, 2)).to eq("-")
    end

    it "reads colour codes with the jar's 17-step values" do
      expect(grid("cF00").color_codes).to eq([[[2, 2], "#ff0000"]])
    end

    it "reads markup tags" do
      expect(grid("{d}").markup_tags).to eq([[[2, 2], "d"]])
    end

    it "reads arrowheads on all four sides" do
      heads = grid("^", "|", "<->", "|", "V").arrowheads

      expect(heads).to eq([[2, 2], [2, 4], [4, 4], [2, 6]])
    end

    it "strings stop at two blanks, keeping a single trailing blank" do
      runs = grid("A B  C").strings

      expect(runs.map(&:last)).to eq(["A B", "C "])
    end

    it "refuses a sub grid that leaves the buffer" do
      expect { grid("+---+").sub_grid(-1, 0, 3, 3) }.to raise_error(IndexError)
    end

    it "floods a region and reports its star ring" do
      source = stamped_box_buffer

      expect(source.boundaries_expanding_from(0, 0)).not_to be_empty
    end

    def stamped_box_buffer
      work = Etassia::Diagram::Ditaa::Grid.new(
        grid("+---+", "|   |", "+---+").rows.map(&:dup),
      )
      Etassia::Diagram::Ditaa::AbstractCell.stamp_buffer(
        work, work.all_boundaries
      )
    end
  end

  describe "cell set algebra" do
    let(:grid) do
      Etassia::Diagram::Ditaa::Grid.from_lines(["+---+", "|   |", "+---+"])
    end
    let(:box) { grid.all_boundaries }

    it "classifies a box as closed" do
      expect(box.type(grid))
        .to eq(Etassia::Diagram::Ditaa::CellSet::TYPE_CLOSED)
    end

    it "classifies an open line as open" do
      line = Etassia::Diagram::Ditaa::Grid.from_lines(["----"]).all_boundaries

      expect(line.type(grid))
        .to eq(Etassia::Diagram::Ditaa::CellSet::TYPE_OPEN)
    end

    it "scales a 3x set down to its one-third equivalent" do
      wide = Etassia::Diagram::Ditaa::CellSet.new(
        [[0, 0], [1, 0], [2, 0], [6, 1], [7, 1], [8, 1]],
      )

      expect(wide.make_scaled_one_third_equivalent.cells)
        .to eq([[0, 0], [2, 0]])
    end

    it "fills a closed set's interior" do
      expect(box.filled_equivalent(grid).size).to be > box.size
    end

    it "copies an open set unchanged as its own filled equivalent" do
      line = Etassia::Diagram::Ditaa::Grid.from_lines(["----"]).all_boundaries

      expect(line.filled_equivalent(grid).size).to eq(line.size)
    end

    it "breaks a mixed boundary into open and closed parts" do
      mixed = Etassia::Diagram::Ditaa::Grid.from_lines(
        ["+----+", "|    |", "+  --+----------+", "|    |", "+----+"],
      )
      parts = mixed.all_boundaries.break_truly_mixed(mixed)

      expect(parts.size).to be >= 2
    end

    it "subtracts sets and reports common cells" do
      other = Etassia::Diagram::Ditaa::CellSet.new([[2, 2]])
      box.subtract_set(other)

      expect(box.has_common_cells?(other)).to be(false)
    end

    it "sees a member cell before subtracting it" do
      other = Etassia::Diagram::Ditaa::CellSet.new([[2, 2]])

      expect(box.has_common_cells?(other)).to be(true)
    end

    it "removes duplicate sets" do
      sets = [box, Etassia::Diagram::Ditaa::CellSet.copy(box)]

      expect(Etassia::Diagram::Ditaa::CellSet.remove_duplicates(sets).size)
        .to eq(1)
    end

    it "splits a composite set into distinct parts" do
      both = Etassia::Diagram::Ditaa::CellSet.new([[2, 2], [4, 2]])

      expect(both.break_into_distinct.size).to eq(2)
    end
  end

  describe "patterns" do
    it "builds entry-point classes and literal fallbacks" do
      pattern = Etassia::Diagram::Ditaa::Pattern.new(".2.", "4+8", ".%1.")

      expect(pattern.matched_by?(Etassia::Diagram::Ditaa::Grid.new(
                                   [".|.", "-+-", ".x."],
                                 ))).to be(true)
    end

    it "matches corners" do
      corner = Etassia::Diagram::Ditaa::Grid.from_lines(["-+-", " |"])
        .testing_sub_grid(3, 2)

      expect(corner.matches_group?(
               Etassia::Diagram::Ditaa::PatternGroup::CORNER,
             )).to be(true)
    end

    it "matches intersections" do
      cross = Etassia::Diagram::Ditaa::Grid.from_lines([" | ", "-+-", " | "])
        .testing_sub_grid(3, 3)

      expect(cross.matches_group?(
               Etassia::Diagram::Ditaa::PatternGroup::INTERSECTION,
             )).to be(true)
    end
  end
end
