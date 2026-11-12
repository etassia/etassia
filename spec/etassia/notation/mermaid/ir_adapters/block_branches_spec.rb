# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/mermaid/ir_adapters/block"

RSpec.describe Etassia::Notation::Mermaid::IRAdapters::Block do
  subject(:ir) { described_class.call(diagram) }

  let(:diagram) do
    block = Etassia::Diagram::BlockNode.new(id: "source", label: "Source")
    block.shape = nil
    Etassia::Diagram::Block.new(
      blocks: [block],
      connections: [
        Etassia::Diagram::BlockConnection.new(
          from: "source", to: "missing", connection_type: "arrow",
        ),
      ],
    )
  end

  it "omits absent shape intent and unresolved connections" do
    block = ir.items.find { |item| item.id == "source" }

    expect([block.placements.map(&:dimension), ir.connections])
      .to eq([%w[source_order column_span compound], []])
  end
end
