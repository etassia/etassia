# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/mermaid/ir_adapters/radar"

RSpec.describe Etassia::Notation::Mermaid::IRAdapters::Radar do
  def duplicate_axis_ir
    diagram = Etassia::Diagram::Radar.new
    diagram.axes = [
      Etassia::Diagram::RadarAxis.new("same", "First"),
      Etassia::Diagram::RadarAxis.new("same", "Second"),
    ]
    described_class.call(diagram)
  end

  it "preserves a duplicate axis source identity after allocation" do
    ir = duplicate_axis_ir
    identity = ir.values.find { |value| value.role == "identifier" }

    expect([ir.valid?, ir.dimensions.map(&:id), identity.parent_id,
            identity.value.value])
      .to eq([true, %w[same same_2], "same_2", "same"])
  end
end
