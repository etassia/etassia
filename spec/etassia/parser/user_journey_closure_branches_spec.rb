# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Parser::UserJourney do
  it "drops an actor that is only a vertical tab" do
    diagram = described_class.new.parse("journey\n  task: 3: A,\v\n")

    expect(diagram.sections.first.tasks.first.actors).to eq(["A"])
  end
end
