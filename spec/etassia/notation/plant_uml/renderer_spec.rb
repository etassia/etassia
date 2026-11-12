# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml"

Etassia::Notation.send(:entries).delete(:plantuml)

RSpec.describe Etassia::Notation::PlantUML::Renderer do
  include_context "with an isolated notation registry"

  before { Etassia::Notation.register(Etassia::Notation::PlantUML) }

  it "paints a note with the hex colour it was given" do
    source = "@startuml\nclass A\nnote right of A #FFAA00 : hi\n@enduml\n"

    expect(Etassia.render(source, notation: :plantuml)).to include("#FFAA00")
  end
end
