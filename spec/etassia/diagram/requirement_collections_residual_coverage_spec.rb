# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Diagram::Requirement do
  subject(:diagram) { described_class.new }

  describe Etassia::Diagram::RequirementNode do
    it "adds a class name" do
      node = described_class.new
      node.add_class("critical")
      expect(node.classes).to eq(["critical"])
    end
  end

  describe Etassia::Diagram::RequirementStyle do
    it "adds a target" do
      style = described_class.new
      style.add_target("R1")
      expect(style.target_ids).to eq(["R1"])
    end
  end

  describe Etassia::Diagram::RequirementClassAssignment do
    it "adds targets and class names" do
      assignment = described_class.new
      assignment.add_target("R1")
      assignment.add_class("critical")
      expect([assignment.target_ids, assignment.class_names])
        .to eq([["R1"], ["critical"]])
    end
  end

  {
    requirement: [Etassia::Diagram::RequirementNode, :requirements],
    element: [Etassia::Diagram::RequirementElement, :elements],
    relationship: [Etassia::Diagram::RequirementRelationship, :relationships],
    style: [Etassia::Diagram::RequirementStyle, :styles],
    class: [Etassia::Diagram::RequirementClass, :classes],
    class_assignment: [
      Etassia::Diagram::RequirementClassAssignment,
      :class_assignments,
    ],
  }.each do |kind, (model, collection)|
    it "appends #{kind} values" do
      item = model.new
      diagram.public_send("add_#{kind}", item)
      expect(diagram.public_send(collection)).to eq([item])
    end
  end
end
