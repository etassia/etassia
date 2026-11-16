# frozen_string_literal: true

require "json"

module Etassia
  module Notation
    # The DIM notation: a Diagram Interchange Model 0.1 document — the
    # JSON a model tool emits (the emitter guide is etassia/docs
    # emitter-guide.md). Detection is structural: a JSON object carrying
    # a `dim` version and a `graph`.
    #
    # There is no Ruby DIM pipeline — layout and rendering live in the
    # engine, which reaches them through etassia-native. The runtime
    # routes DIM sources straight to the native engine; this plugin's
    # `parse` is reached only when ETASSIA_RUNTIME=ruby forced the Ruby
    # pipeline on, and it declines with the reason.
    module Dim
      extend self

      NOT_FOUND = "Unable to detect diagram type from source. " \
                  "Source must start with a JSON object carrying a " \
                  "`dim` version and a `graph`"
      private_constant :NOT_FOUND

      def id
        :dim
      end

      def extensions
        %w[.dim].freeze
      end

      def types
        %i[dim].freeze
      end

      # A DIM document claims itself: a JSON object whose `dim` names a
      # version and whose `graph` is an object. Anything else — plain
      # JSON, a broken document, binary — is not ours. Never raises.
      def claims?(source)
        document = claimed_document(source)
        document.is_a?(Hash) && document["dim"].is_a?(String) &&
          document["graph"].is_a?(Hash)
      end

      def parse(source)
        raise Engine::DiagramTypeError, NOT_FOUND unless claims?(source)

        Etassia::Dim::Document.parse(source)
        raise Engine::PipelineError,
              "rendering a DIM document requires the etassia-native gem; " \
              "the Ruby pipeline has no DIM renderer"
      end

      private

      # The parsed document, or nil for anything that is not ours:
      # non-strings, invalid encodings, non-JSON, non-objects.
      def claimed_document(source)
        return nil unless source.is_a?(String) && source.valid_encoding?

        trimmed = source.strip
        return nil unless trimmed.start_with?("{")

        JSON.parse(trimmed)
      rescue JSON::ParserError, EncodingError
        nil
      end
    end
  end
end
