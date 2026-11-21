# frozen_string_literal: true

require "parslet"
require_relative "error_formatting"
require_relative "native"
require_relative "native/declined"
require_relative "../error"
require_relative "../error/parse_error"

module Etassia
  module Parser
    # Abstract base class for diagram parsers.
    #
    # A parser is normally just a declaration of its grammar and builder:
    #
    # @example Declare a parser
    #   class Pie < Parser::Base
    #     grammar Grammars::Pie
    #     builder Builders::Pie
    #   end
    #
    # The default #parse runs the grammar through #parse_with_grammar, so a
    # syntax error is a ParseError carrying line, column, the source line and
    # a caret, then hands the tree to a new builder's #apply. A parser with
    # real per-type logic overrides #parse instead.
    #
    # @abstract Declare grammar and builder, or override #parse
    class Base
      EMPTY_SEPARATOR = ""
      private_constant :EMPTY_SEPARATOR

      class << self
        # Declares (with an argument) or reads (without) the native entry:
        # the mermaid.parg entry name and the native builder class that
        # turns its tree into the diagram. Without it, or when the native
        # engine is absent, the Ruby grammar parses. (A parser may instead
        # require the engine and carry no Ruby lane at all -- see
        # Parser::UserJourney, which overrides #parse to call
        # Native.parse!.)
        #
        # @param entry [Symbol, nil] a mermaid.parg entry name
        # @param builder [Class, nil] builder responding to #apply(tree)
        # @return [Array(Symbol, Class), nil] the declared pair
        def native(entry = nil, builder: nil)
          @native = [entry, builder] if entry
          @native || (superclass.native if superclass.respond_to?(:native))
        end

        # Declares (with an argument) or reads (without) the grammar class.
        # A subclass inherits its parent's declaration.
        #
        # @param klass [Class, nil] a Parslet grammar class
        # @return [Class, nil] the declared grammar class
        def grammar(klass = nil)
          @grammar = klass if klass
          @grammar || (superclass.grammar if superclass.respond_to?(:grammar))
        end

        # Declares (with an argument) or reads (without) the builder class,
        # whose instances respond to #apply(tree).
        #
        # @param klass [Class, nil] a builder class
        # @return [Class, nil] the declared builder class
        def builder(klass = nil)
          @builder = klass if klass
          @builder || (superclass.builder if superclass.respond_to?(:builder))
        end
      end

      # Parses Mermaid source code into a diagram model.
      #
      # Subclasses that declare both a grammar and a builder get this for
      # free; any other subclass must override it.
      #
      # @param source [String] the Mermaid source code to parse
      # @return [Diagram::Base] the parsed diagram model
      # @raise [ParseError] if the source does not match the grammar
      # @raise [NotImplementedError] if nothing is declared or overridden
      def parse(source)
        require_declarations
        native_diagram(source) || ruby_diagram(source)
      end

      private

      # The native path's diagram, or nil when it declines: no engine, a
      # rejection, or an input the Ruby builder must answer for.
      def native_diagram(source)
        entry, builder = self.class.native
        return nil unless entry

        tree = Native.parse(entry, source)
        tree && builder.new.apply(tree)
      rescue Native::Declined
        nil
      end

      def ruby_diagram(source)
        tree = parse_with_grammar(self.class.grammar.new, source)
        create_diagram(self.class.builder.new.apply(tree))
      end

      def require_declarations
        return if self.class.grammar && self.class.builder

        raise NotImplementedError,
              "#{self.class} must declare grammar and builder " \
              "or implement #parse(source)"
      end

      # Hook for a parser whose builder returns intermediate data rather
      # than the diagram. The default passes the builder's result through.
      #
      # @param result [Object] what the builder returned
      # @return [Diagram::Base] the diagram model
      def create_diagram(result)
        result
      end

      # Runs a grammar, raising ParseError with a positioned message.
      #
      # Uses Parslet's Deepest reporter. The outer `parse_failure_cause`
      # points at the statement boundary the grammar gave up on rather than
      # where the input actually stopped: for "graph TD\nA-->" it reports
      # line 2 column 1, while the deepest cause reports line 2 column 5.
      # The reporter has to be kept, because the exception still carries the
      # outer cause even when a Deepest reporter is in use.
      #
      # @param grammar [Parslet::Parser] the grammar to run
      # @param source [String] the source to parse
      # @return [Hash, Array] the parse tree — a Hash for a single
      #   captured node, an Array once a grammar repeats one
      # @raise [ParseError] with the failure position and context, or when
      #   the source's encoding cannot be read by the grammar
      def parse_with_grammar(grammar, source)
        reporter = Parslet::ErrorReporter::Deepest.new
        grammar.parse(source, reporter: reporter)
      rescue Parslet::ParseFailed => e
        cause = reporter.deepest_cause || e.parse_failure_cause
        raise ParseError, format_parse_error(cause, source)
      rescue EncodingError, ArgumentError => e
        raise ParseError, encoding_message(source, e)
      end

      # A grammar's Unicode rules refuse a binary-tagged string holding
      # non-ASCII bytes (EncodingError), and a UTF-8-tagged string with
      # invalid bytes fails in Parslet's StringScanner (ArgumentError)
      # before any rule runs.
      def encoding_message(source, error)
        "Parse error: source encoding #{source.encoding} cannot be read " \
          "as #{self.class.name.split('::').last} source (#{error.message})"
      end

      # Renders a failure's text without its position.
      #
      # Parslet's message is a String for some failures and an Array of
      # String and Slice parts for a literal mismatch. Interpolating the
      # array split the message across lines and printed a slice's byte
      # offset, while cause.to_s renders it properly but appends a
      # byte-counted position that contradicts the heading's column.
      #
      # @param cause [Parslet::Cause] the failure to describe
      # @return [String] the message alone
      def failure_message(cause)
        Array(cause.message).map { |part| message_part(part) }
          .join(EMPTY_SEPARATOR)
      end

      # Parslet quotes a Slice and leaves everything else alone. Quoting by
      # "not a String" instead would render a lookahead's symbol as
      # `"LINE_END"` where parslet writes `LINE_END`.
      #
      # A lookahead failure is the third case, and it is reachable: for
      # "graph TD\nstyle A fill:#f9f,,g" parslet builds an Entity part and
      # the message reads `Input should not start with HASHED_COMMA_GAP`.
      # Quoting it would have printed the symbol as a string literal.
      #
      # @param part [String, Parslet::Slice, Object] one piece of a message
      # @return [String] the piece as parslet would render it
      def message_part(part)
        part.respond_to?(:to_slice) ? part.str.inspect : part.to_s
      end

      # The last resort, when positioning itself blew up. NOT `#{cause}`:
      # `Parslet::Cause#to_s` joins its parts with a zero-argument join, so
      # a multi-part message is corrupted when the caller has set `$,`.
      #
      # @param cause [Parslet::Cause] the failure to describe
      # @return [String] the message with parslet's own position
      def fallback_message(cause)
        line, column = cause.source.line_and_column(cause.pos)
        "Parse error: #{failure_message(cause)} at line #{line} " \
          "char #{column}."
      end

      # Locates a failure as a 1-based line and CHARACTER column.
      #
      # Parslet counts bytes, so the line comes from Parslet's own cache
      # and the column is converted to characters by the shared geometry.
      #
      # @param cause [Parslet::Cause] the failure to locate
      # @param source [String] the source that was parsed
      # @return [Array(Integer, Integer)] 1-based line and character column
      def failure_position(cause, source)
        line, = cause.source.line_and_column(cause.pos)

        [line, ErrorFormatting.character_column(source, line,
                                                cause.pos.bytepos)]
      end

      # The one parse-error message: line, column, the source line and a
      # caret, with a fallback if positioning itself raises.
      #
      # @param cause [Parslet::Cause] the failure to describe
      # @param source [String] the source that was parsed
      # @return [String] the positioned, multi-line error message
      def format_parse_error(cause, source)
        line, column = failure_position(cause, source)
        ErrorFormatting.message(source, line, column, failure_message(cause),
                                fallback_message(cause))
      rescue StandardError
        fallback_message(cause)
      end
    end
  end
end
