# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Renderer::Base, "#render" do
  let(:fractional) { /font-size="\d+\.5"/ }

  {
    Etassia::Renderer::Info => "info",
    Etassia::Renderer::Pie => "pie\n \"a\" : 1\n \"b\" : 2",
    Etassia::Renderer::Packet => "packet-beta\n 0-7: \"x\"",
    Etassia::Renderer::Radar => "radar-beta\n axis a,b,c\n curve c1{1,2,3}",
    Etassia::Renderer::Timeline => "timeline\n 2020 : x",
    Etassia::Renderer::Treemap => "treemap-beta\n \"A\"\n  \"B\": 5",
    Etassia::Renderer::UserJourney => [
      "journey", " title T", " section S", " T: 5: Me"
    ].join("\n"),
    Etassia::Renderer::Kanban => "kanban\n col\n  t1[task]",
    Etassia::Renderer::StateDiagram =>
      "stateDiagram-v2\n [*] --> A\n A --> B: go\n B --> [*]",
    Etassia::Renderer::Quadrant =>
      "quadrantChart\n x-axis L --> R\n y-axis B --> T\n P: [0.3, 0.6]",
  }.each do |renderer, source|
    before do
      allow(renderer).to receive(:new).and_wrap_original do |original, **opts|
        original.call(**opts).tap do |instance|
          instance.singleton_class.prepend(FractionalFontScene::Widening)
        end
      end
    end

    it "keeps a fractional font size in #{renderer.name}" do
      expect(Etassia::Engine.new.render(source)).to match(fractional)
    end
  end

  it "keeps a fractional font size in Etassia::Renderer::Error" do
    scene = FractionalFontScene.widen(Etassia::Layout::Error.from_graph({}))

    xml = Etassia::Renderer::Error.new.render(scene).to_xml

    expect(xml).to match(fractional)
  end
end
