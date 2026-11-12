# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Diagram::XyChart do
  subject(:chart) { described_class.new }

  it "starts with empty collections" do
    expect([chart.datasets, chart.options]).to eq([[], {}])
  end

  it "identifies itself as a valid XY chart" do
    expect([chart.diagram_type, chart.valid?]).to eq([:xychart, true])
  end

  it "adds a dataset" do
    dataset = Etassia::Diagram::XYDataset.new("sales")
    chart.add_dataset(dataset)
    expect(chart.datasets).to eq([dataset])
  end
end
