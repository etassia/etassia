# frozen_string_literal: true

require_relative "../error"

module Etassia
  module Layout
    # Error raised during layout. A Etassia::Error so Engine#render
    # can let it propagate unwrapped instead of collapsing it into
    # PipelineError.
    class LayoutError < Etassia::Error; end
  end
end
