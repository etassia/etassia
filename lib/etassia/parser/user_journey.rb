# frozen_string_literal: true

require_relative "base"
require_relative "../error/score_error"
require_relative "native/builders/user_journey"
require_relative "../diagram/user_journey"

module Etassia
  module Parser
    # User Journey diagram parser. The native artifact lane is the ONLY
    # parse path: the journey grammar is baked into mermaid.parg and the
    # compiled engine is REQUIRED (Native.parse!), never a fallback that
    # silently switches parsers. A journey parse without a working engine
    # raises Native::EngineUnavailableError, telling the consumer to
    # install a parsanol native gem.
    class UserJourney < Base
      native :user_journey, builder: Native::Builders::UserJourney

      # Encoding failures the engine or a builder slice operation raises
      # mid-parse are normalized into ParseError, the one contract this
      # parser promises its callers.
      def parse(source)
        entry, builder = self.class.native
        builder.new.apply(Native.parse!(entry, source))
      rescue EncodingError, ArgumentError => e
        raise ParseError, "Parse error: #{e.message}"
      end
    end
  end
end
