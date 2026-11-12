# frozen_string_literal: true

require "spec_helper"
require "etassia/layout/class_diagram_namespaces"

RSpec.describe Etassia::Layout::ClassDiagramNamespaces do
  subject(:namespaces) { described_class.call(graph) }

  let(:graph) { Etassia::IR::Graph.new(nodes: nodes) }
  let(:nodes) do
    [
      Etassia::IR::Node.new(id: "domain", role: "namespace", label: "Domain"),
      Etassia::IR::Node.new(
        id: "customer", role: "member", label: "Customer", parent_id: "domain",
      ),
      Etassia::IR::Node.new(
        id: "order", role: "member", label: "Order", parent_id: "domain",
      ),
      Etassia::IR::Node.new(
        id: "target", role: "target", label: "Ignored", parent_id: "domain",
      ),
    ]
  end

  it "reads namespace members in source order" do
    expect(namespaces.map { |namespace| [namespace.name, namespace.class_ids] })
      .to eq([["Domain", %w[Customer Order]]])
  end
end
