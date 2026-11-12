# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/mermaid/ir_adapters/radar"

RSpec.describe Etassia::Notation::Mermaid::IRAdapters::Radar do
  let(:diagram) do
    Etassia::Diagram::Radar.new.tap do |radar|
      radar.axes = [Etassia::Diagram::RadarAxis.new("a", "A"),
                    Etassia::Diagram::RadarAxis.new("a", "B")]
      radar.curves = []
      radar.options = {}
    end
  end

  it "gives two axes with the same id distinct dimension ids" do
    ids = described_class.call(diagram).dimensions.map(&:id)

    expect(ids).to eq(%w[a a_2])
  end
end
