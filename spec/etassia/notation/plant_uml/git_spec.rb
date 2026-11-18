# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml"

# Requiring an external notation registers it; restore the suite baseline
# and register inside the isolated context per example.
Etassia::Notation.send(:entries).delete(:plantuml)

RSpec.describe Etassia::Notation::PlantUML::Git do
  include_context "with an isolated notation registry"

  before do
    Etassia::Notation.register(Etassia::Notation::PlantUML) unless
      Etassia::Notation.send(:entries).key?(:plantuml)
  end

  def wrap(*lines)
    "@startgit\n#{lines.join("\n")}\n@endgit\n"
  end

  def parse(*lines)
    described_class.parse(wrap(*lines))
  end

  it "detects an @startgit wrapper" do
    expect(described_class.git?(wrap("* main"))).to be(true)
  end

  it "leaves other sources alone" do
    expect(described_class.git?("@startmindmap\n* root\n@endmindmap\n"))
      .to be(false)
  end

  it "reads every commit with its rail and line" do
    diagram = parse("* c1", "* c2", "| * c3", "|/", "* c4").diagram

    expect(diagram.commits.map(&:to_a))
      .to eq([%w[c1] + [0, 0], %w[c2] + [0, 1], %w[c3] + [2, 2],
              %w[c4] + [0, 4]])
  end

  it "reads a name with a drawing character beside it" do
    diagram = parse("* fix-deadlock.2").diagram

    expect(diagram.commits.first.name).to eq("fixdeadlock2")
  end

  it "lays one column per rail and one row per line" do
    source = wrap("* c1", "* c2", "| * c3", "|/", "* c4")
    boxes = described_class.parse(source).transform.new
      .call(described_class.parse(source).diagram).boxes

    expect(boxes.map { |box| [box[:x], box[:y]] })
      .to eq([[19.0, 10.0], [19.0, 59.0], [107.0, 108.0], [19.0, 206.0]])
  end

  it "renders named boxes for every commit" do
    rendered = parse("* c1", "* c2").renderer.new.render(
      parse("* c1", "* c2").transform.new.call(parse("* c1", "* c2").diagram),
    ).to_xml

    expect(rendered).to include("c1").and include("c2").and include("<svg")
  end
end
