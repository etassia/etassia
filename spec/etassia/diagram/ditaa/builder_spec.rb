# frozen_string_literal: true

require "spec_helper"
require "etassia/diagram/ditaa"
require "etassia/notation/plantuml"

# Geometry pins for the ditaa builder: edge touching, the jar's pure
# font-metric walks, and end-to-end arm coverage through the renderer.

# Requiring an external notation registers it; restore the suite baseline
# and register inside the isolated context per example.
Etassia::Notation.send(:entries).delete(:plantuml) if defined?(Etassia::Notation)
RSpec.describe Etassia::Diagram::Ditaa::Builder do
  def metrics
    described_class.new(Etassia::Diagram::Ditaa::DEFAULTS)
  end

  def point(at_x, at_y)
    Etassia::Diagram::Ditaa::Builder::Point.new(x: at_x, y: at_y,
                                                type: :normal, locked: false)
  end

  def edge(one, two)
    Etassia::Diagram::Ditaa::Builder::Edge.new(one, two, nil)
  end

  before do
    Etassia::Notation.register(Etassia::Notation::PlantUML) unless
      Etassia::Notation.send(:entries).key?(:plantuml)
  end

  it "sees an edge as touching its exact twin" do
    a = edge(point(0, 0), point(10, 0))

    expect(a.touches_with?(edge(point(0, 0), point(10, 0)))).to be(true)
  end

  it "walks the ascent search downward for tall cells" do
    expect(metrics.font_for(6)).to be < 12.0
  end

  it "orders overlapping edges regardless of direction" do
    a = edge(point(10, 0), point(0, 0))
    b = edge(point(5, 0), point(20, 0))

    expect(a.touches_with?(b)).to be(true)
  end

  it "rejects edges that merely meet at one endpoint" do
    a = edge(point(0, 0), point(10, 0))
    b = edge(point(10, 0), point(20, 0))

    expect(a.touches_with?(b)).to be(false)
  end

  it "shrinks a string that overruns its width" do
    expect(metrics.smaller_size("abcdefgh", 30)).to be < 12.0
  end

  it "grows a string well inside its width" do
    expect(metrics.smaller_size("ab", 100)).to be > 12.0
  end

  it "accepts a fit exactly at the limit" do
    expect(metrics.string_fits?("abcdefgh", 12.0, 52.801)).to be(true)
  end

  it "refuses a fit a hair past the limit" do
    expect(metrics.string_fits?("abcdefgh", 12.0, 52.79)).to be(false)
  end

  include_context "with an isolated notation registry"

  def render_source(source)
    given = Etassia::Notation::PlantUML::Ditaa.parse(source)
    layout = given.transform.new.call(given.diagram)
    given.renderer.new.render(layout).to_xml
  end

  it "draws slash corners rounded even without -r" do
    source = "@startditaa\n /----+\n |    |\n +----+\n@endditaa\n"

    expect(render_source(source)).to include("Q ")
  end

  it "separates the shared wall of three aligned boxes" do
    source = "@startditaa\n+---+---+---+\n| a | b | c |\n+---+---+---+\n" \
             "|   |   |   |\n+---+---+---+\n@endditaa\n"

    expect(render_source(source)).to include("<path")
  end

  it "separates a sloped diamond's edges" do
    source = "@startditaa\n  +--+\n   \\  /\n    ++\n   /  \\\n  +--+\n" \
             "@endditaa\n"

    expect(render_source(source)).to include("<path")
  end

  it "reads a lone horizontal dash as a small line" do
    source = "@startditaa\nx - y\n@endditaa\n"
    parsed = Etassia::Notation::PlantUML::Ditaa.parse(source)

    expect(parsed.diagram.shapes.map(&:kind)).to include(:line)
  end

  it "keeps containing-shape order when coloring nested boxes" do
    source = "@startditaa\n+---------+\n| cF00    |\n| +-----+ |\n" \
             "| | c0F0| |\n| +-----+ |\n+---------+\n@endditaa\n"
    parsed = Etassia::Notation::PlantUML::Ditaa.parse(source)

    expect(parsed.diagram.shapes.count(&:fill)).to eq(2)
  end

  it "swaps overlapping edge order without touching the twin" do
    a = edge(point(5, 0), point(20, 0))
    b = edge(point(10, 0), point(0, 0))

    expect(a.touches_with?(b)).to be(true)
  end

  def edge(one, two)
    Etassia::Diagram::Ditaa::Builder::Edge.new(one, two, nil)
  end

  def point(at_x, at_y)
    Etassia::Diagram::Ditaa::Builder::Point.new(x: at_x, y: at_y,
                                                type: :normal, locked: false)
  end

  it "drops a diagonal-leg open set whose start cannot follow" do
    source = "@startditaa\n-/\n@endditaa\n"
    parsed = Etassia::Notation::PlantUML::Ditaa.parse(source)

    expect(parsed.diagram.composites.flatten).to be_empty
  end
end
