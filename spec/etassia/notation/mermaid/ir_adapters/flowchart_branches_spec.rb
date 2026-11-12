# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/mermaid/ir_adapters/flowchart"

RSpec.describe Etassia::Notation::Mermaid::IRAdapters::Flowchart do
  subject(:ir) { described_class.call(diagram) }

  let(:diagram) do
    Etassia::Diagram::Flowchart.new(
      nodes: [flow_node("first"), flow_node("second")],
      edges: [
        Etassia::Diagram::FlowchartEdge.new(
          source_id: "first", target_id: "second", arrow_type: "line",
        ),
      ],
    )
  end

  it "preserves a plain connection without inventing arrow markers" do
    edge = ir.edges.fetch(0)

    expect([edge.role, edge.properties.source_marker,
            edge.properties.target_marker])
      .to eq(["line", nil, nil])
  end

  def flow_node(id)
    Etassia::Diagram::FlowchartNode.new(id: id, label: id.capitalize)
  end
end
