# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecSupport::LayoutParity::XyChartRecognizer do
  include SpecSupport::LayoutParity::FigureHelpers

  subject(:recognizer) { described_class.new }

  def keys(svg)
    extract(svg, recognizer).elements.map do |element|
      [element.kind, element.key]
    end
  end

  def real_pair
    name = "xychart-aaf2900f"
    reference = reference_svg("xychart/#{name}.svg")
    etassia = Etassia.render(corpus_source("xychart/#{name}.mmd"))
    [keys(reference), keys(etassia)]
  end

  it "matches every bar and line series by stable ordinal" do
    reference_keys, etassia_keys = real_pair

    expect(etassia_keys).to eq(reference_keys)
  end
end
