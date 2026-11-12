# frozen_string_literal: true

require "spec_helper"
require "etassia/parser/builders/architecture"

RSpec.describe Etassia::Parser::Builders::Architecture do
  let(:diagram) { described_class.new.apply("artifact") }
  let(:actual) do
    [
      diagram.title, diagram.groups, diagram.services,
      diagram.junctions, diagram.edges
    ]
  end

  it "ignores a scalar extraction artifact" do
    expect(actual).to eq([nil, [], [], [], []])
  end
end
