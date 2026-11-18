# frozen_string_literal: true

require "spec_helper"
require "etassia/diagram/ditaa"

# Unit pins for the 3x3 pattern grammar: one arm per example, asserted on
# the public pure pieces.
RSpec.describe Etassia::Diagram::Ditaa::Pattern do
  it "falls through to a literal for a char outside the classes" do
    pattern = described_class.new(".?.", "!+!", ".?.")

    expect(pattern.to_regexp("?")).to eq("\\?")
  end
end
