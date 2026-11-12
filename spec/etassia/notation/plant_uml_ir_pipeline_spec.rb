# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml"

Etassia::Notation.send(:entries).delete(:plantuml)

RSpec.describe Etassia::Notation::PlantUML do
  include PlantUmlIrHelpers

  include_context "with an isolated notation registry"

  before { Etassia::Notation.register(described_class) }

  it "hands layout the shared graph, not its private diagram" do
    parsed = described_class.parse(feature_source)

    expect(parsed.diagram).to be_a(Etassia::IR::Graph)
  end

  it "renders a class diagram through the shared graph" do
    svg = Etassia.render(feature_source, notation: :plantuml)

    expect(svg).to include("class-Shape")
  end
end
