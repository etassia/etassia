# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/mermaid/ir_adapters/architecture"

RSpec.describe Etassia::Notation::Mermaid::IRAdapters::Architecture do
  subject(:ir) { described_class.call(diagram) }

  let(:diagram) do
    Etassia::Diagram::Architecture.new(
      id: "", groups: [group], services: [service],
      edges: [unresolved_edge]
    )
  end
  let(:group) do
    Etassia::Diagram::Architecture::Group.new(id: "", label: "Platform")
  end
  let(:service) do
    Etassia::Diagram::Architecture::Service.new(
      id: "", label: "API", group_id: "",
    )
  end
  let(:unresolved_edge) do
    Etassia::Diagram::Architecture::Edge.new(
      from_id: "", to_id: "missing", label: "ignored",
    )
  end

  it "assigns stable fallback identities and drops unresolved connections" do
    expect(adapter_evidence)
      .to eq([true, "item", [], %w[group_0 service_0]])
  end

  def adapter_evidence
    roles = %w[group service]
    entities = ir.nodes.select do |node|
      roles.include?(node.role)
    end
    [ir.valid?, ir.id, ir.edges, entities.map(&:id)]
  end
end
