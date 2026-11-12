# frozen_string_literal: true

require_relative "../error"

module Etassia
  class Engine
    # Error raised during pipeline execution
    class PipelineError < Etassia::Error; end
  end
end
