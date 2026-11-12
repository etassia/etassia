# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/mermaid/ir_adapters/flowchart"

RSpec.describe Etassia::Notation::Mermaid::IRAdapters::Flowchart do
  it "falls back to a generic id for an empty diagram id" do
    node = Etassia::Diagram::FlowchartNode.new(id: "a", label: "A")
    diagram = Etassia::Diagram::Flowchart.new(id: "", nodes: [node])

    expect(described_class.call(diagram).id).to eq("item")
  end
end
