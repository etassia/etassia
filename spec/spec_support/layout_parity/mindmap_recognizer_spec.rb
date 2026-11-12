# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecSupport::LayoutParity::MindmapRecognizer do
  include SpecSupport::LayoutParity::FigureHelpers

  subject(:recognizer) { described_class.new }

  def keys(svg)
    extract(svg, recognizer).elements.map(&:key)
  end

  def real_pair
    name = "mindmap_spec-7104af54"
    reference = reference_svg("mindmap/#{name}.svg")
    etassia = Etassia.render(corpus_source("mindmap/#{name}.mmd"))
    [keys(reference), keys(etassia)]
  end

  it "uses the same semantic labels for a real multi-level pair" do
    reference_keys, etassia_keys = real_pair

    expect(etassia_keys).to eq(reference_keys)
  end
end
