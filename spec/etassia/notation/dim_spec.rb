# frozen_string_literal: true

require "spec_helper"
require "etassia"

RSpec.describe Etassia::Notation::Dim do
  let(:document) do
    Etassia::Dim::Document.new(
      notation: "generic",
      graph: Etassia::Dim::Graph.new(
        id: "root",
        children: [Etassia::Dim::Node.new(
          id: "a", width: 100, height: 40,
          content: [Etassia::Dim::ContentBlock.new(text: "Person",
                                                   role: "title")]
        )],
      ),
    )
  end

  let(:dim_source) { document.to_json }

  describe "the registry entry" do
    it "claims a DIM document" do
      notation = Etassia::Notation.resolve(explicit: nil, path: nil,
                                           source: dim_source)
      expect(notation.id).to eq(:dim)
    end

    it "carries the .dim extension and the dim type" do
      expect([described_class.extensions, described_class.types])
        .to eq([%w[.dim], %i[dim]])
    end
  end

  describe "claims?" do
    it "accepts a DIM document" do
      expect(described_class.claims?(dim_source)).to be(true)
    end

    it "refuses plain JSON without a dim version and graph" do
      expect(described_class.claims?('{"a": 1}')).to be(false)
    end

    it "refuses broken JSON" do
      expect(described_class.claims?('{"dim": ')).to be(false)
    end

    it "refuses diagram text" do
      expect(described_class.claims?("flowchart\nA --> B")).to be(false)
    end

    it "refuses invalid bytes without raising" do
      expect(described_class.claims?("\xFF\xFE")).to be(false)
    end
  end
end
