# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Renderer::Quadrant, "#render" do
  subject(:rendered_title) do
    group = described_class.new.render(scene).children
      .grep(Etassia::Svg::Group).find { |item| item.class_name == "title" }
    group.children.grep(Etassia::Svg::Text).first
  end

  let(:scene) do
    diagram = Etassia::Parser::Quadrant.new.parse("quadrantChart\n  title T\n")
    Etassia::Layout::Quadrant.new.call(diagram)
  end

  it "serializes typed Scene label emphasis" do
    scene.title.font_weight = "bold"

    expect(rendered_title.font_weight).to eq("bold")
  end
end
