# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml"

RSpec.describe Etassia::Notation::PlantUML::Sequence::Layout do
  include_context "with an isolated notation registry"

  before do
    Etassia::Notation.send(:entries).delete(:plantuml)
    Etassia::Notation.register(Etassia::Notation::PlantUML)
  end

  def arrow_ys(*body)
    source = "@startuml\n!pragma teoz true\n#{body.join("\n")}\n@enduml\n"
    parsed = Etassia::Notation::PlantUML::Sequence.parse(source)
    scene = parsed.transform.new.call(parsed.diagram)

    scene.arrows.map { |arrow| arrow.path[/M \S+ (\S+)/, 1].to_f }
  end

  it "keeps a parallel side note on its message row" do
    messages = ["A -> B: first", "A -> B: second"]
    with_note = arrow_ys(messages.first, "& note right of B: ok",
                         messages.last)

    expect(with_note).to eq(arrow_ys(*messages))
  end
end
