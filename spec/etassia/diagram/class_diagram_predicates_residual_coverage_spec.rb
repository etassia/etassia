# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Diagram::ClassDiagram do
  let(:entity) { Etassia::Diagram::ClassEntity.new(stereotype: "enum") }
  let(:relationships) do
    %w[association dependency realization].map do |type|
      Etassia::Diagram::ClassRelationship.new(relationship_type: type)
    end
  end

  it "identifies the remaining public class diagram kinds" do
    evidence = [entity.enum?] + relationships.map do |relationship|
      relationship.public_send("#{relationship.relationship_type}?")
    end

    expect(evidence).to eq([true, true, true, true])
  end
end
