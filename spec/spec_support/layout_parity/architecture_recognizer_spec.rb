# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecSupport::LayoutParity::ArchitectureRecognizer do
  include SpecSupport::LayoutParity::FigureHelpers

  subject(:recognizer) { described_class.new }

  def summaries(svg)
    extract(svg, recognizer).elements.map do |element|
      [element.kind, element.key, element.parent]
    end.sort_by { |item| item.map(&:to_s) }
  end

  def real_pair
    name = "architecture_spec-2a3d0f20"
    reference = reference_svg("architecture/#{name}.svg")
    etassia = Etassia.render(corpus_source("architecture/#{name}.mmd"))
    [summaries(reference), summaries(etassia)]
  end

  it "matches semantic group, service, and edge identities" do
    reference_summary, etassia_summary = real_pair

    expect(etassia_summary).to eq(reference_summary)
  end
end
