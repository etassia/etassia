# frozen_string_literal: true

require "spec_helper"
require "etassia/ir"
require "etassia/notation/plantuml/sequence/ir_reader/index"
require "etassia/notation/plantuml/sequence/ir_reader/settings"

RSpec.describe Etassia::Notation::PlantUML::Sequence::IRReader::Settings do
  subject(:settings) { described_class.call(index) }

  let(:node) { Etassia::IR::Node.new(id: "appearance", role: "appearance") }
  let(:graph) { Etassia::IR::Graph.new(id: "graph", nodes: [node]) }
  let(:index) do
    Etassia::Notation::PlantUML::Sequence::IRReader::Index.new(graph)
  end

  it "defaults optional settings absent from the index" do
    values = [settings[:appearance].alignment, settings[:chrome].legend_place,
              settings[:footbox], settings[:warnings], settings[:title]]
    expect(values).to eq([:center, "bottom center", true, [], nil])
  end
end
