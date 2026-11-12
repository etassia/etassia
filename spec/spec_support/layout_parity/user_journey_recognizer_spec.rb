# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecSupport::LayoutParity::UserJourneyRecognizer do
  include SpecSupport::LayoutParity::FigureHelpers

  subject(:recognizer) { described_class.new }

  def summaries(svg)
    extract(svg, recognizer).elements.map do |element|
      [element.kind, element.key]
    end.sort
  end

  def real_pair
    name = "journey_spec-efcd431c"
    reference = reference_svg("user_journey/#{name}.svg")
    etassia = Etassia.render(corpus_source("user_journey/#{name}.mmd"))
    [summaries(reference), summaries(etassia)]
  end

  it "uses the same section and task identities for a real pair" do
    reference_summary, etassia_summary = real_pair

    expect(etassia_summary).to eq(reference_summary)
  end
end
