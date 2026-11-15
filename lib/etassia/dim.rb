# frozen_string_literal: true

require "json"
require "lutaml/model"

module Etassia
  # The Diagram Interchange Model (DIM): the interchange between
  # model-holding tools (a schema documentation generator, a UML
  # repository browser) and the engine. A tool walks its own model,
  # builds a Dim::Document, and hands it to the engine — the guide is
  # etassia/docs emitter-guide.md, the specification dim/SPEC.md, the
  # wire contract dim-0.1.schema.json.
  #
  # Validation split: this model validates what an EMITTER must get
  # right — the version, the notation shape, the edge styles, the
  # content roles, the required identifiers. The engine remains the
  # strict gatekeeper of the wire contract (unknown keys and nested
  # children are rejected there, not here).
  module Dim
    VERSION = "0.1"
    NOTATION_PATTERN = /\A[a-z][a-z0-9_-]*\z/
    EDGE_STYLES = %w[association generalization composition dependency
                     reference].freeze
    CONTENT_ROLES = %w[title member stereotype note].freeze

    class Error < StandardError; end

    # The document names a DIM version this model cannot speak.
    class UnsupportedError < Error; end

    # A label block inside a node: what the node shows, and what the
    # block means — the styling vocabulary the renderer maps to its
    # theme.
    class ContentBlock < Lutaml::Model::Serializable
      attribute :kind, :string, default: "label"
      attribute :text, :string
      attribute :role, :string, default: "member"

      json do
        map "kind", to: :kind, render_default: true
        map "text", to: :text
        map "role", to: :role, render_default: true
      end

      def validate!
        guard_kind!
        guard_text!
        guard_role!
      end

      def guard_kind!
        return if kind == "label"

        raise Error, "content block kind must be \"label\", got #{kind.inspect}"
      end

      def guard_text!
        return if text.is_a?(String) && !text.empty?

        raise Error, "content block text is required"
      end

      def guard_role!
        return if CONTENT_ROLES.include?(role)

        raise Error,
              "content role #{role.inspect} is not one of " \
              "#{CONTENT_ROLES.join(', ')}"
      end
    end

    # A node: one shape on the canvas. Width and height are the
    # emitter's honest size estimate; the engine places the node.
    class Node < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :width, :float
      attribute :height, :float
      attribute :content, ContentBlock, collection: true, default: -> { [] }

      json do
        map "id", to: :id
        map "width", to: :width
        map "height", to: :height
        map "content", to: :content
      end

      def validate!
        return unless id.nil? || id.to_s.empty?

        raise Error, "node id is required"
      end
    end

    # The text riding on an edge.
    class EdgeLabel < Lutaml::Model::Serializable
      attribute :text, :string

      json do
        map "text", to: :text
      end

      def validate!
        return if text.is_a?(String) && !text.empty?

        raise Error, "edge label text is required"
      end
    end

    # An edge: a relationship with a semantic intent. The style is what
    # the renderer draws, not how it draws it.
    class Edge < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :sources, :string, collection: true
      attribute :targets, :string, collection: true
      attribute :style, :string
      attribute :label, EdgeLabel

      json do
        map "id", to: :id
        map "sources", to: :sources
        map "targets", to: :targets
        map "style", to: :style
        map "label", to: :label
      end

      def validate!
        guard_id!
        guard_endpoints!
        guard_style!
        label&.validate!
      end

      def guard_id!
        return unless id.nil? || id.to_s.empty?

        raise Error, "edge id is required"
      end

      def guard_endpoints!
        if Array(sources).empty?
          raise Error,
                "edge #{id} needs at least one source"
        end
        return unless Array(targets).empty?

        raise Error, "edge #{id} needs at least one target"
      end

      def guard_style!
        return if style.nil? || EDGE_STYLES.include?(style)

        raise Error,
              "edge style #{style.inspect} is not one of " \
              "#{EDGE_STYLES.join(', ')}"
      end
    end

    # The graph: nodes, edges, and the layout options that steer the
    # engine. The emitter never sets an x or a y.
    class Graph < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :layout_options, :hash, default: -> { {} }
      attribute :children, Node, collection: true, default: -> { [] }
      attribute :edges, Edge, collection: true, default: -> { [] }

      json do
        map "id", to: :id
        map "layoutOptions", to: :layout_options
        map "children", to: :children
        map "edges", to: :edges
      end

      def validate!
        guard_id!
        guard_options!
        children.each(&:validate!)
        edges.each(&:validate!)
      end

      def guard_id!
        return unless id.nil? || id.to_s.empty?

        raise Error, "graph id is required"
      end

      def guard_options!
        bad = layout_options.find do |k, v|
          !k.is_a?(String) || !v.is_a?(String)
        end
        return if bad.nil?

        raise Error,
              "layout option #{bad.first.inspect} must map " \
              "a String to a String"
      end
    end

    # The document: the version, the notation the view expresses, and
    # the graph. Render hands the serialized document to the engine
    # through the native gem; the drawing that comes back is a function
    # of the document and the engine's version triple.
    class Document < Lutaml::Model::Serializable
      attribute :dim, :string, default: VERSION
      attribute :notation, :string
      attribute :graph, Graph

      json do
        map "dim", to: :dim, render_default: true
        map "notation", to: :notation
        map "graph", to: :graph
      end

      class << self
        def parse(json_string)
          raw = JSON.parse(json_string)
          guard_documented_version(raw)
          document = from_json(json_string)
          document.validate!
          document
        end

        def guard_documented_version(raw)
          return if raw.is_a?(Hash) && raw["dim"] == VERSION

          raise UnsupportedError,
                "DIM version #{raw['dim'].inspect} is not supported; " \
                "this model speaks #{VERSION}"
        end
      end

      def validate!
        guard_version!
        guard_notation!
        return if graph.is_a?(Graph)

        raise Error, "graph is required"
      end

      def guard_version!
        return if dim == VERSION

        raise UnsupportedError,
              "DIM version #{dim.inspect} is not supported; " \
              "this model speaks #{VERSION}"
      end

      def guard_notation!
        return if notation.is_a?(String) && notation =~ NOTATION_PATTERN

        raise Error,
              "notation #{notation.inspect} must match " \
              "#{NOTATION_PATTERN.source}"
      end

      def render
        require "etassia/native"
        Etassia::Native.render_dim(to_json)
      rescue LoadError
        raise Error, "rendering DIM requires the etassia-native gem"
      end
    end
  end
end
