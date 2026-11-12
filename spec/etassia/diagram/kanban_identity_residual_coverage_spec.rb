# frozen_string_literal: true

require "spec_helper"
require "etassia/diagram/kanban"

RSpec.describe Etassia::Diagram::Kanban do
  it("identifies itself as kanban") do
    expect(described_class.new.diagram_type).to eq(:kanban)
  end
end
