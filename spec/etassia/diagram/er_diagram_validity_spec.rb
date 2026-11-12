# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Diagram::ErDiagram do
  it "is valid with entities and an absent relationship list" do
    entity = Etassia::Diagram::ErEntity.new(id: "A", name: "A")
    expect(described_class.new(entities: [entity], relationships: nil))
      .to be_valid
  end
end
