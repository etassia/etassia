# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml/sequence/message"

RSpec.describe Etassia::Notation::PlantUML::Sequence::Message do
  it "identifies a non-leftward self message" do
    style = Etassia::Notation::PlantUML::Sequence::ArrowStyle.plain(:filled)
    message = described_class.new(from: "A", to: "A", label: "x", style: style)
    expect([message.self_message?, message.leftward?]).to eq([true, false])
  end
end
