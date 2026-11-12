# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Renderer::Radar, "#render" do
  subject(:children) { described_class.new.render(scene).children }

  let(:scene) do
    Etassia::Layout::Radar.new.call(Etassia::Parser::Radar.new.parse(source))
  end
  let(:source) do
    "radar-beta\n  axis a, b, c\n  curve c1{1, 2, 3}\n  graticule polygon\n"
  end

  it "draws each ring and each curve as a polygon" do
    expect(children.grep(Etassia::Svg::Polygon).map(&:class_name))
      .to eq([*%w[radarGraticule] * 5, "radarCurve-0"])
  end

  it "draws no circle graticule" do
    classes = children.grep(Etassia::Svg::Circle).map(&:class_name)

    expect(classes).not_to include("radarGraticule")
  end
end
