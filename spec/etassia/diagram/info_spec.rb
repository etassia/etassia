# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Diagram::Info do
  subject(:diagram) { described_class.new }

  it "identifies itself as an always-valid info diagram" do
    expect([diagram.diagram_type, diagram.valid?]).to eq([:info, true])
  end
end
