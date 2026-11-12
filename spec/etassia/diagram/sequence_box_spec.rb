# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Diagram::SequenceBox do
  it "starts boxes without participants" do
    expect(described_class.new.participant_ids).to eq([])
  end

  it "starts frames without sections" do
    expect(Etassia::Diagram::SequenceFrame.new.sections).to eq([])
  end
end
