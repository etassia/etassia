# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecSupport::LayoutParity::C4Recognizer do
  subject(:recognizer) { described_class.new }

  let(:description_case) { "should_parse_the_description-82dca309" }
  let(:description_key) do
    "A customer of the bank, with personal bank accounts."
  end
  let(:description_identities) do
    [identities(summaries(reference_svg("c4/#{description_case}.svg"))),
     identities(summaries(description_output))]
  end
  let(:description_output) do
    Etassia.render(corpus_source("c4/#{description_case}.mmd"))
  end

  include SpecSupport::LayoutParity::FigureHelpers

  def summaries(svg)
    extract(svg, recognizer).elements.map do |element|
      [element.kind, element.key, element.parent]
    end.sort_by { |item| item.map(&:to_s) }
  end

  def real_pair
    name = "c4-8ab0b1ef"
    reference = reference_svg("c4/#{name}.svg")
    etassia = Etassia.render(corpus_source("c4/#{name}.mmd"))
    [summaries(reference), summaries(etassia)]
  end

  def identities(summary)
    summary.map { |kind, key, _parent| [kind, key] }
  end

  def parent_map(summary)
    summary.to_h { |_kind, key, parent| [key, parent] }
  end

  it "matches boundary and element labels" do
    reference_summary, etassia_summary = real_pair

    expect(identities(etassia_summary)).to eq(identities(reference_summary))
  end

  it "matches the containment of the reference" do
    reference_summary, etassia_summary = real_pair
    parents = [parent_map(reference_summary), parent_map(etassia_summary)]

    expect(parents.map { |map| map.fetch("Banking Customer A") })
      .to eq(%w[BankBoundary0 BankBoundary0])
  end

  it "keys an element declared with an empty name by its description" do
    expect(description_identities).to all(eq([[:c4_element, description_key]]))
  end
end
