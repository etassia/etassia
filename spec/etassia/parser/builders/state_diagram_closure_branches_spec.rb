# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Parser::Builders::StateDiagram do
  it "drops a note whose target state was never declared" do
    diagram = Etassia::Parser::StateDiagram.new.parse(
      "stateDiagram-v2\nnote right of Ghost : hi\n",
    )

    expect([diagram.notes, diagram.states]).to eq([[], []])
  end
end
