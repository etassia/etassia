# frozen_string_literal: true

require "nokogiri"
require "spec_helper"
require "etassia/notation/plantuml"

Etassia::Notation.send(:entries).delete(:plantuml)

RSpec.describe Etassia::Notation::PlantUML::Sequence::Layout do
  include_context "with an isolated notation registry"
  include DejaVuText

  before { Etassia::Notation.register(Etassia::Notation::PlantUML) }

  let(:source) do
    <<~PLANTUML
      @startuml
      participant App
      actor OEM
      App -> OEM : hi
      @enduml
    PLANTUML
  end
  let(:rectangle) do
    Nokogiri::XML(Etassia.render(source, notation: :plantuml))
      .remove_namespaces!.at_xpath(
        '//g[starts-with(@id,"participant-App-")]/rect',
      )
  end

  it "sizes a plain participant to its label beside an actor" do
    expect(rectangle["width"].to_f).to eq(dejavu("App", size: 14) + 14.0)
  end
end
