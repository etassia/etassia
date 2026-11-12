# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Layout::Architecture do
  subject(:layout) { described_class.new }

  it "puts a lone empty group at the grid origin" do
    diagram = Etassia::Parser::Architecture.new
      .parse("architecture-beta\n  group g(cloud)[G]\n")
    group = layout.call(diagram).children.find { |node| node.id == "g" }

    expect([group.x, group.y]).to eq([60.0, 60.0])
  end
end
