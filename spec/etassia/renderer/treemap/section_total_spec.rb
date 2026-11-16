# frozen_string_literal: true

require "spec_helper"
require "etassia"

RSpec.describe Etassia::Renderer::Treemap::SectionTotal do
  let(:source) do
    <<~MMD
      treemap-beta
      "Products"
          "Electronics"
              "Phones": 50
              "Computers": 30
          "Clothing"
              "Shirts": 10
    MMD
  end
  let(:texts) do
    svg = Etassia::Engine.new.render(source)
    svg.scan(%r{<text[^>]*>([^<]*)</text>}).flatten
  end

  it "prints the summed value on the root section" do
    expect(texts).to include("90")
  end

  it "prints the summed value on a nested section" do
    expect(texts).to include("80")
  end

  it "keeps the leaf values" do
    expect(texts).to include("50", "30", "10")
  end

  describe "the total of a fixture cell, unit-level" do
    # Rendering derives totals from the scene (treemap_section_total_scene_spec
    # holds that line), so only these fixtures reach the class itself.
    def cell(children: [], value_label: nil)
      Struct.new(:children, :value_label).new(children, value_label)
    end

    def label(text)
      Struct.new(:text).new(text)
    end

    it "returns nil when the section has no labelled leaves" do
      expect(described_class.new(cell).text).to be_nil
    end

    it "skips unlabelled leaves and sums the labelled ones" do
      section = cell(children: [cell(value_label: label("10")), cell])

      expect(described_class.new(section).text).to eq("10")
    end

    it "formats an integral total without decimals" do
      section = cell(children: [cell(value_label: label("10")),
                                cell(value_label: label("20"))])

      expect(described_class.new(section).text).to eq("30")
    end

    it "formats a fractional total with one decimal" do
      section = cell(children: [cell(value_label: label("10.5")),
                                cell(value_label: label("20.4"))])

      expect(described_class.new(section).text).to eq("30.9")
    end

    it "sums a section nested under a section" do
      inner = cell(children: [cell(value_label: label("5"))])
      outer = cell(children: [inner, cell(value_label: label("7"))])

      expect(described_class.new(outer).text).to eq("12")
    end
  end
end
