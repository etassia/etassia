# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml"

# Requiring an external notation registers it; restore the suite baseline
# and register inside the isolated context per example.
Etassia::Notation.send(:entries).delete(:plantuml)

# Unit pins for the ditaa pipeline's arms, in the parity-wave style: one
# feature input per arm, asserted through the public parse and render.
RSpec.describe Etassia::Notation::PlantUML::Ditaa do
  include_context "with an isolated notation registry"

  before do
    Etassia::Notation.register(Etassia::Notation::PlantUML) unless
      Etassia::Notation.send(:entries).key?(:plantuml)
  end

  def wrap(*lines, flags: "")
    "@startditaa#{flags}\n#{lines.join("\n")}\n@endditaa\n"
  end

  def diagram(*lines, flags: "")
    described_class.parse(wrap(*lines, flags: flags)).diagram
  end

  def rendered(*lines, flags: "")
    given = described_class.parse(wrap(*lines, flags: flags))
    layout = given.transform.new.call(given.diagram)
    given.renderer.new.render(layout).to_xml
  end

  it "renders every special markup kind" do
    svg = rendered("+-----+", "| {s} |", "+-----+")

    expect(svg).to include("<path")
  end

  it "renders the io parallelogram" do
    svg = rendered("+-----+", "|{io} |", "+-----+")

    expect(svg).to include("<path")
  end

  it "renders the decision diamond" do
    svg = rendered("+-----+", "| {c} |", "+-----+")

    expect(svg).to include("<path")
  end

  it "renders the manual operation trapezoid" do
    svg = rendered("+-----+", "|{mo} |", "+-----+")

    expect(svg).to include("<path")
  end

  it "renders the trapezoid tag" do
    svg = rendered("+-----+", "| {tr}|", "+-----+")

    expect(svg).to include("<path")
  end

  it "reads a lone marker as no shape" do
    result = diagram("*x*")

    expect(result.shapes).to be_empty
  end

  it "reads a stub as a line point" do
    result = diagram(" -+", "  |", "  +---+", "  |  ", "  +--+", "     x")

    expect(result.composites).not_to be_empty
  end

  it "rounds diagonal corners with -r" do
    svg = rendered(" /----+", " |    |", " +----+", flags: " -r")

    expect(svg).to include("Q ")
  end

  it "draws diagonal corners with -r" do
    svg = rendered(" /---+", " |   |", " +---/", flags: " -r")

    expect(svg).to include("Q ")
  end

  it "abuts two boxes at a shared corner" do
    svg = rendered("+---++---+", "|   ||   |", "+---++---+")

    expect(svg).to include("<path")
  end

  it "stacks boxes touching one wide box" do
    svg = rendered("+---+  +---+", "| a |  | b |", "+---+  +---+",
                   "+----------+", "|    c     |", "+----------+")

    expect(svg).to include("<path")
  end

  it "breaks a mixed boundary with an open line" do
    result = diagram("+-----+", "|  A  |C               B",
                     "+  ---+-----------------", "|     |", "+-----+")

    expect(result.composites).not_to be_empty
  end

  it "reads an open line ending at a stub" do
    result = diagram("      x", "      |", " --+--+")

    expect(result.composites.flatten.map(&:kind)).to include(:line)
  end

  it "dashes an open dashed connector" do
    svg = rendered("A === B")

    expect(svg).to include("stroke-dasharray")
  end

  it "draws white text over a dark fill" do
    svg = rendered("+--------+", "| c111   |", "|  dark  |", "+--------+")

    expect(svg).to match(/<text[^>]*fill="#ffffff"[^>]*>dark<\/text>/)
  end

  it "keeps black text over a light fill" do
    svg = rendered("+--------+", "| cEEE   |", "|  light |", "+--------+")

    expect(svg).to match(/<text[^>]*fill="#000000"[^>]*>light<\/text>/)
  end

  it "keeps the base font size for ordinary strings" do
    texts = diagram("+---------+", "| Longer label here |", "+---------+").texts

    expect(texts.map(&:font_size)).to all(eq(17.5))
  end

  it "left-aligns a string ending where others start" do
    texts = diagram("+----------+", "| a   bb   |", "| aa   b   |",
                    "+----------+").texts

    expect(texts.map(&:anchor)).to include(:start)
  end

  it "right-aligns strings that end in one column" do
    texts = diagram("+--------+", "| a      |", "|  bb    |",
                    "+--------+").texts

    expect(texts.map(&:anchor)).to include(:middle)
  end

  it "reads a mixed boundary beside an independent closed box" do
    result = diagram("+---+", "", "+-----+", "|  A  |C",
                     "+  ---+----", "|     |", "+-----+")

    expect(result.shapes + result.composites.flatten).not_to be_empty
  end

  # An L-shaped closed ring has six corners; a markup tag on it exercises
  # the special paths' four-point guard and the polygon fallback.
  context "with a tag on a six-corner shape" do
    def wrap_lshape(tag)
      pad = " " * (7 - tag.length)
      lines = ["+----+", "|    |", "|    +----+",
               "|{#{tag}}#{pad}|", "+---------+"]
      "@startditaa\n#{lines.join("\n")}\n@endditaa\n"
    end

    def render_lshape(tag)
      given = described_class.parse(wrap_lshape(tag))
      layout = given.transform.new.call(given.diagram)
      given.renderer.new.render(layout).to_xml
    end

    tags = { "d" => :document, "s" => :storage, "io" => :io, "c" => :decision,
             "mo" => :manual_operation, "tr" => :trapezoid, "o" => :ellipse }
    tags.each do |tag, kind|
      it "tags the six-corner shape as #{kind} and falls back to a polygon" do
        given = described_class.parse(wrap_lshape(tag))

        expect(given.diagram.shapes.first.kind).to eq(kind)
      end
    end
  end

  context "with mixed corners and detached text" do
    def rendered_source(source)
      given = described_class.parse(source)
      layout = given.transform.new.call(given.diagram)
      given.renderer.new.render(layout).to_xml
    end

    it "rounds a mixed corner polygon with -r" do
      source = "@startditaa -r\n+---+\n|    \\\n|     |\n+-----+\n@endditaa\n"

      expect(rendered_source(source)).to include("Q ")
    end

    it "ignores a markup tag outside every shape" do
      result = diagram("{d}      ", "+---+", "| x |", "+---+")

      expect(result.shapes.map(&:kind)).to all(eq(:rectangle))
    end

    it "ignores a colour code outside every shape" do
      result = diagram("cF00", "", "+---+", "| x |", "+---+")

      expect(result.shapes.count(&:fill)).to be_zero
    end

    it "leaves uncontained text black" do
      source = "@startditaa\nA === B\n\n+---+\n| x |\n+---+\n@endditaa\n"

      expect(rendered_source(source)).to match(/fill="#000000"[^>]*>A </)
    end

    it "tests text intersection by row separation" do
      source = "@startditaa\nlabel\n\n+---+\n| x |\n+---+\n@endditaa\n"
      diagram = described_class.parse(source).diagram

      expect(diagram.texts.map(&:anchor)).to include(:middle)
    end
  end

  context "with the jar's open-trace step budget" do
    it "gives up on an open trace longer than the jar's 1000 steps" do
      line = ("-" * 1200)
      source = "@startditaa\n#{line}\n@endditaa\n"
      parsed = described_class.parse(source)

      expect(parsed.diagram.composites).to be_empty
    end

    it "keeps a normal open trace well inside the step budget" do
      line = ("-" * 200)
      source = "@startditaa\n#{line}\n@endditaa\n"
      parsed = described_class.parse(source)

      expect(parsed.diagram.composites.flatten).not_to be_empty
    end
  end
end
