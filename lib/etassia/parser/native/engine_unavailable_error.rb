# frozen_string_literal: true

require_relative "../../error"

module Etassia
  module Parser
    module Native
      # Raised when a parser without a Ruby lane needs the compiled engine
      # and the engine cannot serve a parse: parsanol or its compiled
      # artifact did not load, or the ETASSIA_NATIVE_PARSER switch turned
      # the engine off. The remedy is on the consumer's side -- install a
      # parsanol native gem for this platform (or clear the switch). There
      # is no parser to fall back to, by design: a silent switch would
      # change both the parse cost and the tree shape.
      class EngineUnavailableError < Etassia::Error; end
    end
  end
end
