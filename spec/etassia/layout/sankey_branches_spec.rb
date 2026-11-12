# frozen_string_literal: true

require "spec_helper"
require "etassia/layout/sankey"

RSpec.describe Etassia::Layout::Sankey do
  def graph(nodes:, edges: [])
    Etassia::IR::Graph.new(
      id: "sankey", role: "flow_graph", nodes: nodes, edges: edges,
    )
  end

  def node(id, label = nil)
    Etassia::IR::Node.new(id: id, label: label, role: "flow_node")
  end

  def edge(weight)
    properties = Etassia::IR::PropertySet.new(weight: weight)
    Etassia::IR::Edge.new(
      id: "flow", role: "flow", source_id: "a", target_id: "b",
      properties: properties
    )
  end

  it "keeps zero-weight IR flows visible without a label" do
    scene = described_class.new.call(
      graph(nodes: [node("a"), node("b")], edges: [edge(0)]),
    )
    expect(scene.flows.first).to have_attributes(width: 1.0, label: nil)
  end

  it "lays disconnected nodes on the fallback layer" do
    scene = described_class.new.call(graph(nodes: [node("a"), node("b")]))
    evidence = scene.nodes.map do |item|
      [item.label.text, item.layer, item.width]
    end

    expect(evidence).to eq([["a", 0, 20.0], ["b", 0, 20.0]])
  end
end
