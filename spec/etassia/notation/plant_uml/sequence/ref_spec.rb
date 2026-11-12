# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Notation::PlantUML::Sequence::Ref do
  it "is not parallel" do
    expect(described_class.new(targets: %w[A], label: "x")).not_to be_parallel
  end
end
