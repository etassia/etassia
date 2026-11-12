# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecSupport::LayoutParity::RadarRecognizer do
  include SpecSupport::LayoutParity::FigureHelpers

  subject(:recognizer) { described_class.new }

  def summaries(svg)
    extract(svg, recognizer).elements.map do |element|
      [element.kind, element.key]
    end
  end

  def real_pair
    name = "radar_spec-9dd39c75"
    reference = reference_svg("radar/#{name}.svg")
    etassia = Etassia.render(corpus_source("radar/#{name}.mmd"))
    [summaries(reference), summaries(etassia)]
  end

  it "matches axes, curves and the title on both producers" do
    reference_summary, etassia_summary = real_pair

    expect(etassia_summary).to match_array(reference_summary)
  end
end
