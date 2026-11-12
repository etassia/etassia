# frozen_string_literal: true

require "spec_helper"
require "etassia/parser/git_graph"

RSpec.describe Etassia::Parser::GitGraph do
  it "preserves the character in an unsupported message escape" do
    source = "gitGraph\n  commit msg: \"left\\xright\"\n"
    diagram = described_class.new.parse(source)

    expect(diagram.commits.first.message).to eq("leftxright")
  end
end
