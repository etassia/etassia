# frozen_string_literal: true

require "spec_helper"
require "etassia/parser/builders/xy_chart"

RSpec.describe Etassia::Parser::Builders::XyChart do
  it "ignores unsupported statements and extraction artifacts" do
    statements = [{ type: :unknown, value: "ignored" }, "artifact", nil]
    expected = { title: nil, x_axis: nil, y_axis: nil, datasets: [] }

    expect(described_class.build(statements)).to eq(expected)
  end
end
