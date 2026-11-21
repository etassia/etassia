# frozen_string_literal: true

require_relative "../error/parse_error"
require_relative "error_formatting"
require_relative "native/engine_unavailable_error"

module Etassia
  module Parser
    # The native parse path: Mermaid grammars compiled from PARG
    # (etassia/etassia-grammar) and run by the parsanol engine.
    #
    # For a parser with a Ruby lane it is an accelerator: it answers only
    # for input it accepts; on a missing engine, an unreadable encoding or
    # any rejection it returns nil and the caller runs the Ruby grammar,
    # which stays the source of every positioned ParseError.
    #
    # For a parser with NO Ruby lane (see Parser::UserJourney) .parse! is
    # the whole contract: the engine is required, a decline raises instead
    # of returning nil.
    module Native
      ARTIFACT_PATH = File.expand_path("native/mermaid.json", __dir__)
      ARTIFACT_VARIABLE = "ETASSIA_NATIVE_ARTIFACT"
      DISABLE_VARIABLE = "ETASSIA_NATIVE_PARSER"
      DISABLED_VALUES = %w[0 off false ruby].freeze
      # The engine recurses on the machine stack once per nested block and
      # a source that nests deeper than the stack allows kills the whole
      # process (a segfault in the extension, not a SystemStackError): about
      # 60 nested subgraphs on a 1 MB stack, Windows' main-thread size. Past
      # this depth the Ruby grammar answers, as it does without the engine.
      MAX_NESTING = 32
      NESTING_OPEN = /\A\s*(?:subgraph|block:|alt|loop|opt|par|critical|break|
                            rect|box)\b|\{\s*\z/ix
      NESTING_CLOSE = /\A\s*(?:end\b|\})/i
      private_constant :ARTIFACT_PATH, :ARTIFACT_VARIABLE, :DISABLE_VARIABLE,
                       :DISABLED_VALUES, :MAX_NESTING, :NESTING_OPEN,
                       :NESTING_CLOSE

      class << self
        # @return [Boolean] whether the parsanol engine and artifact loaded
        def available?
          !artifact.nil?
        end

        # Parses source with one entry of the Mermaid artifact.
        #
        # @param entry [Symbol] an entry of mermaid.parg
        # @param source [String] Mermaid source
        # @return [Hash, Array, Parsanol::Slice, nil] the parse tree, or
        #   nil when the native path does not answer
        def parse(entry, source)
          return nil if disabled? || !readable?(source) || too_deep?(source)

          artifact&.parse(entry.to_s, source)
        rescue Parsanol::ParseFailed
          nil
        end

        # The strict variant for a parser with no Ruby lane: the engine is
        # the ONLY parse path, so a decline raises instead of returning
        # nil. A parse is never silently handed to another parser, which
        # would change both its cost and its answer.
        #
        # @param entry [Symbol] an entry of mermaid.parg
        # @param source [String] Mermaid source
        # @return [Hash, Array, Parsanol::Slice] the parse tree
        # @raise [EngineUnavailableError] when the engine cannot serve the
        #   parse at all: parsanol or its artifact did not load, or the
        #   ETASSIA_NATIVE_PARSER switch turned the engine off
        # @raise [Etassia::Parser::ParseError] when the engine is present
        #   but the source is not readable UTF-8, nests deeper than
        #   {MAX_NESTING}, or does not parse
        def parse!(entry, source)
          raise EngineUnavailableError, unavailable_message unless usable?
          raise ParseError, unreadable_message(source) unless readable?(source)
          raise ParseError, nesting_message if too_deep?(source)

          # The guards stay outside the begin: they answer even when
          # parsanol never loaded.
          begin
            artifact.parse(entry.to_s, source)
          rescue Parsanol::ParseFailed => e
            raise ParseError, rejection_message(e, source)
          end
        end

        # Forgets the loaded artifact (specs swap the engine out).
        def reset!
          @artifact = nil
          @loaded = false
        end

        private

        # Whether the engine can serve a parse at all: present and not
        # switched off by the environment.
        def usable?
          !disabled? && available?
        end

        def unavailable_message
          if disabled?
            "The parsanol native engine is switched off by " \
              "#{DISABLE_VARIABLE}=#{ENV.fetch(DISABLE_VARIABLE, nil)} and " \
              "this parser has no Ruby lane. Unset #{DISABLE_VARIABLE} or " \
              "install a parsanol native gem."
          else
            "The parsanol native engine did not load. Install a parsanol " \
              "native gem for this platform; this parser has no Ruby lane " \
              "to fall back to."
          end
        end

        # The engine reads UTF-8 only; anything else is the byte-level
        # failure a UTF-8 reader sees, whatever tag the source carries.
        def unreadable_message(source)
          "Parse error: invalid byte sequence: the source is tagged " \
            "#{source.encoding}, which the native engine cannot read as " \
            "UTF-8"
        end

        def nesting_message
          "Parse error: the source nests deeper than #{MAX_NESTING} " \
            "levels, deeper than the engine answers"
        end

        # The positioned ParseError for a source the engine refused: the
        # same four-line shape Parser::Base raises on the Ruby lane.
        def rejection_message(error, source)
          cause = error.parse_failure_cause
          return "Parse error: #{error}" unless cause

          line, = cause.source.line_and_column(cause.position)
          column = ErrorFormatting.character_column(source, line,
                                                    cause.position)
          ErrorFormatting.message(source, line, column, failure_text(cause),
                                  "Parse error: #{cause}")
        rescue StandardError
          "Parse error: #{cause}"
        end

        # A Parsanol message is a String for some failures and an Array of
        # String and Slice parts for a literal mismatch; a Slice quotes its
        # content, anything else renders as is.
        def failure_text(cause)
          Array(cause.message).map do |part|
            part.is_a?(Parsanol::Slice) ? part.content.inspect : part.to_s
          end.join
        end

        def disabled?
          DISABLED_VALUES.include?(ENV.fetch(DISABLE_VARIABLE, "").downcase)
        end

        def readable?(source)
          source.encoding == Encoding::UTF_8 && source.valid_encoding?
        end

        # Whether blocks opened and not yet closed ever pass MAX_NESTING.
        # A line that merely looks like an opener only sends the source to
        # the Ruby grammar, which answers identically.
        def too_deep?(source)
          depth = 0
          source.each_line do |line|
            if line.match?(NESTING_OPEN)
              depth += 1
              return true if depth > MAX_NESTING
            elsif line.match?(NESTING_CLOSE)
              depth -= 1 if depth.positive?
            end
          end
          false
        end

        def artifact
          return @artifact if @loaded

          @loaded = true
          @artifact = load_artifact
        end

        def load_artifact
          require "parsanol"
          Parsanol::PARG::Artifact.load(ENV.fetch(ARTIFACT_VARIABLE,
                                                  ARTIFACT_PATH))
        rescue LoadError, StandardError
          nil
        end
      end
    end
  end
end
