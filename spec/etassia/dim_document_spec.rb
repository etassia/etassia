# frozen_string_literal: true

require "spec_helper"
require "etassia"

RSpec.describe Etassia::Dim do
  # The emitter-guide worked example: one type graph drawn from an XML
  # Schema's model.
  def person_graph_document
    Etassia::Dim::Document.new(
      notation: "xsd",
      graph: Etassia::Dim::Graph.new(
        id: "root",
        layout_options: { "elk.algorithm" => "layered",
                          "elk.direction" => "DOWN" },
        children: [
          Etassia::Dim::Node.new(
            id: "type-PersonType", width: 200, height: 110,
            content: [
              Etassia::Dim::ContentBlock.new(text: "PersonType", role: "title"),
              Etassia::Dim::ContentBlock.new(text: "name: xs:string"),
              Etassia::Dim::ContentBlock.new(text: "address: AddressType"),
            ]
          ),
          Etassia::Dim::Node.new(
            id: "type-AddressType", width: 200, height: 110,
            content: [Etassia::Dim::ContentBlock.new(text: "AddressType",
                                                     role: "title")]
          ),
        ],
        edges: [
          Etassia::Dim::Edge.new(
            id: "ref-person-address",
            sources: ["type-PersonType"], targets: ["type-AddressType"],
            style: "association",
            label: Etassia::Dim::EdgeLabel.new(text: "address")
          ),
        ],
      ),
    )
  end

  def wire
    JSON.parse(person_graph_document.to_json)
  end

  describe "the wire format" do
    it "carries the version, the notation and the graph" do
      expect(wire.values_at("dim", "notation")).to eq(["0.1", "xsd"])
    end

    it "maps the layout options to their wire name" do
      expect(wire["graph"]["layoutOptions"])
        .to include("elk.algorithm" => "layered")
    end

    it "carries content blocks with kind, text and role" do
      first = wire["graph"]["children"].first
      expect(first["content"].first)
        .to eq("kind" => "label", "text" => "PersonType", "role" => "title")
    end

    it "carries the edge intent" do
      edge = wire["graph"]["edges"].first
      expect(edge.values_at("style", "label"))
        .to eq(["association", { "text" => "address" }])
    end

    it "round-trips through parse" do
      document = person_graph_document
      parsed = Etassia::Dim::Document.parse(document.to_json)

      expect(parsed.to_json).to eq(document.to_json)
    end

    def schema_example
      <<~JSON
        {
          "dim": "0.1",
          "notation": "generic",
          "graph": {
            "id": "root",
            "layoutOptions": { "elk.algorithm": "layered",
                               "elk.direction": "RIGHT" },
            "children": [
              { "id": "n1", "width": 140, "height": 60,
                "content": [{ "kind": "label", "text": "Person",
                              "role": "title" }] }
            ],
            "edges": [
              { "id": "e1", "sources": ["n1"], "targets": ["n2"],
                "style": "reference" }
            ]
          }
        }
      JSON
    end

    it "parses the canonical schema example" do
      expect(Etassia::Dim::Document.parse(schema_example).notation)
        .to eq("generic")
    end
  end

  describe "the validation surface" do
    it "rejects a foreign version with UnsupportedError" do
      document = person_graph_document
      document.dim = "9.9"

      expect { document.validate! }
        .to raise_error(Etassia::Dim::UnsupportedError, /9\.9/)
    end

    it "rejects a notation outside the registry shape" do
      document = person_graph_document
      document.notation = "XML Schema"

      expect { document.validate! }.to raise_error(Etassia::Dim::Error,
                                                   /notation/)
    end

    it "rejects an unknown edge style" do
      edge = Etassia::Dim::Edge.new(id: "e", sources: ["a"], targets: ["b"],
                                    style: "arrow")

      expect { edge.validate! }.to raise_error(Etassia::Dim::Error,
                                               /edge style/)
    end

    it "rejects an unknown content role" do
      block = Etassia::Dim::ContentBlock.new(text: "x", role: "heading")

      expect { block.validate! }.to raise_error(Etassia::Dim::Error,
                                                /content role/)
    end

    it "rejects an edge without endpoints" do
      edge = Etassia::Dim::Edge.new(id: "e", sources: [], targets: ["b"])

      expect { edge.validate! }.to raise_error(Etassia::Dim::Error,
                                               /at least one source/)
    end

    it "rejects a non-string layout option value" do
      graph = Etassia::Dim::Graph.new(id: "root",
                                      layout_options: { "elk.algorithm" => 7 })

      expect { graph.validate! }.to raise_error(Etassia::Dim::Error,
                                                /layout option/)
    end

    it "reports a foreign version at parse before anything else" do
      json = '{"dim": "0.2", "notation": "x", "graph": {"id": "r"}}'

      expect { Etassia::Dim::Document.parse(json) }
        .to raise_error(Etassia::Dim::UnsupportedError)
    end
  end

  describe "rendering" do
    def load_native
      require "etassia/native"
    rescue LoadError
      nil
    end

    it "asks for the etassia-native gem when it is absent" do
      unless defined?(Etassia::Native)
        expect { person_graph_document.render }
          .to raise_error(Etassia::Dim::Error, /etassia-native/)
      end
    end

    it "renders to SVG through the native engine when available" do
      load_native
      skip "the etassia-native gem is not installed" unless native_ready?

      svg = person_graph_document.render
      expect(svg).to include("PersonType")
    end
  end

  def native_ready?
    defined?(Etassia::Native) && Etassia::Native.available?
  end
end
