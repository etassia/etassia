# frozen_string_literal: true

require "spec_helper"
require "etassia/ir"

RSpec.describe Etassia::IR::Model do
  let(:ir_classes) do
    [
      Etassia::IR::Scalar, Etassia::IR::PropertySet, Etassia::IR::Item,
      Etassia::IR::Placement, Etassia::IR::PrepositionedItem, Etassia::IR::Edge,
      Etassia::IR::Prepositioned, Etassia::IR::Node, Etassia::IR::Graph,
      Etassia::IR::Dimension, Etassia::IR::Series, Etassia::IR::DataValue,
      Etassia::IR::Data
    ]
  end
  let(:forbidden_attributes) do
    %i[
      x y width height bounds path points routes bend_points polygon_points
      metadata layout_options mermaid plantuml arrow_type
    ]
  end

  it "loads every IR type as a strict Lutaml model" do
    expect(ir_classes).to all(be < Lutaml::Model::Serializable)
  end

  it "rejects unknown symbol and string fields" do
    attempts = [
      -> { Etassia::IR::Graph.new(id: "graph", x: 10) },
      -> { Etassia::IR::Graph.new("id" => "graph", "metadata" => {}) },
    ]

    expect { attempts.each(&:call) }.to raise_error(ArgumentError)
  end

  it "rejects unknown fields inside nested typed properties" do
    expect do
      Etassia::IR::Item.new(id: "item", properties: { arrow_type: "-->" })
    end.to raise_error(ArgumentError)
  end

  it "keeps geometry and notation spellings out of every schema" do
    exposed = ir_classes.flat_map { |model| model.attributes.keys }.uniq

    expect(exposed & forbidden_attributes).to be_empty
  end

  it "uses typed fields instead of generic hashes" do
    attribute_types = ir_classes.flat_map do |model|
      model.attributes.values.map(&:type)
    end

    expect(attribute_types).not_to include(Lutaml::Model::Type::Hash)
  end

  it "rejects attributes that are not a Hash" do
    expect { Etassia::IR::Graph.new([]) }
      .to raise_error(ArgumentError, "attributes must be a Hash")
  end

  it "rejects attribute names that are not Strings or Symbols" do
    expect { Etassia::IR::Graph.new(1 => "graph") }
      .to raise_error(ArgumentError, /names must be Strings or Symbols/)
  end

  it "rejects a name given as both String and Symbol" do
    expect { Etassia::IR::Graph.new("id" => "a", id: "b") }
      .to raise_error(ArgumentError, "duplicate attribute names")
  end

  it "has no default semantic errors" do
    expect(described_class.new).to be_valid
  end
end
