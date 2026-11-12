# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Renderer::Quadrant, "#render" do
  let(:source) do
    "quadrantChart\n  title T\n  x-axis L --> R\n  y-axis B --> U\n"
  end
  let(:scene) do
    diagram = Etassia::Parser::Quadrant.new.parse(source)
    Etassia::Layout::Quadrant.new.call(diagram)
  end
  let(:title) do
    group = described_class.new.render(scene).children
      .grep(Etassia::Svg::Group).find { |item| item.class_name == "title" }
    group.children.grep(Etassia::Svg::Text).first
  end

  it "anchors a label that names an anchor" do
    expect(title.text_anchor).to eq(scene.title.text_anchor)
  end

  it "leaves the anchor unset for a label without one" do
    scene.title.text_anchor = nil

    expect(title.text_anchor).to be_nil
  end
end
