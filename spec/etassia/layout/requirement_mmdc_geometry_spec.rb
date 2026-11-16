# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Layout::Requirement do
  subject(:layout) { described_class.new }

  let(:scene) do
    layout.call(
      Etassia::Diagram::Requirement.new(
        requirements: [
          Etassia::Diagram::RequirementNode.new(
            name: "test_req", id: "1", text: "the test text.",
            risk: "high", verifymethod: "test"
          ),
        ],
        elements: [
          Etassia::Diagram::RequirementElement.new(name: "test_entity",
                                                   type: "simulation"),
        ],
        relationships: [
          Etassia::Diagram::RequirementRelationship.new(
            source: "test_entity", target: "test_req", type: "satisfies",
          ),
        ],
      ),
    )
  end

  let(:reversed) do
    layout.call(
      Etassia::Diagram::Requirement.new(
        requirements: [Etassia::Diagram::RequirementNode.new(name: "r")],
        elements: [Etassia::Diagram::RequirementElement.new(name: "e")],
        relationships: [Etassia::Diagram::RequirementRelationship.new(
          source: "r", target: "e", type: "verifies",
        )],
      ),
    )
  end

  def node(id)
    scene.children.find { |child| child.id == id }
  end

  # mmdc: 8px above the first row, 24px rows, a 20px gap under the name,
  # 12px below (spec/fixtures_mermaid/requirement/requirement-9f8b7e75: 184
  # and 112 tall).
  it "sizes a box from its row count, as mmdc does" do
    expect([node("test_req").height, node("test_entity").height])
      .to eq([184, 112])
  end

  it "sizes a box from its widest label plus 10px each side" do
    expect(node("test_req").width).to be_within(15).of(157.7)
  end

  it "puts the relationship source above its target" do
    ys = reversed.children.to_h { |child| [child.id, child.y] }
    expect(ys["r"]).to be < ys["e"]
  end

  it "centres boxes of different widths on one axis" do
    centres = scene.children.map { |child| child.x + (child.width / 2) }
    expect(centres.first).to be_within(0.01).of(centres.last)
  end

  it "leaves 74px between ranks and an 8px canvas margin" do
    entity = node("test_entity")
    expect([entity.y, node("test_req").y - (entity.y + entity.height)])
      .to eq([8, 74])
  end

  it "draws an element as a rectangle" do
    expect(node("test_entity").shape_points.split.length).to eq(4)
  end
end
