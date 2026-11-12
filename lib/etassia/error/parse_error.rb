# frozen_string_literal: true

require_relative "../error"

module Etassia
  module Parser
    # Error raised during parsing. A Etassia::Error so Engine#render can let
    # it propagate unwrapped instead of collapsing it into PipelineError.
    class ParseError < Etassia::Error; end
  end
end
