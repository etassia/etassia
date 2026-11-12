# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/mermaid/ir_adapters/git_graph"

RSpec.describe Etassia::Notation::Mermaid::IRAdapters::GitGraph do
  subject(:ir) { described_class.call(diagram) }

  let(:diagram) do
    commit = Etassia::Diagram::GitGraph::Commit.new(
      id: "current", parent_ids: ["missing"],
    )
    Etassia::Diagram::GitGraph.new(commits: [commit])
  end

  it "keeps unknown parent references as metadata without a dangling edge" do
    commit = ir.nodes.find { |node| node.role == "commit" }
    parent = ir.nodes.find { |node| node.role == "parent_reference" }

    expect([ir.valid?, ir.edges, parent.parent_id, parent.label])
      .to eq([true, [], commit.id, "missing"])
  end
end
