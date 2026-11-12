# frozen_string_literal: true

require_relative "../error"

module Etassia
  module Renderer
    # Error raised during rendering. A Etassia::Error so Engine#render can
    # let it propagate unwrapped instead of collapsing it into
    # PipelineError.
    class RenderError < Etassia::Error; end
  end
end
