# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml"

RSpec.describe Etassia::Notation::PlantUML::Sequence::Layout do
  include_context "with an isolated notation registry"

  before do
    Etassia::Notation.send(:entries).delete(:plantuml)
    Etassia::Notation.register(Etassia::Notation::PlantUML)
  end

  def loop_height(*body)
    source = "@startuml\n!pragma teoz true\n#{body.join("\n")}\n@enduml\n"
    parsed = Etassia::Notation::PlantUML::Sequence.parse(source)
    path = parsed.transform.new.call(parsed.diagram).arrows.first.path
    coordinates = path.scan(/-?\d+(?:\.\d+)?/).map(&:to_f)

    coordinates[5] - coordinates[1]
  end

  it "matches self-loop height in a fragment-bearing Teoz diagram" do
    expect(loop_height("alt branch", "A -> A: nested", "end")).to eq(13.0)
  end

  it "matches the pinned ordinary Teoz self-loop shaft height" do
    expect(loop_height("A -> A: plain")).to eq(13.0)
  end
end
