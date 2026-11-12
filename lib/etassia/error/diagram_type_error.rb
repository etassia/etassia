# frozen_string_literal: true

require_relative "../error"

module Etassia
  class Engine
    # Error raised when diagram type cannot be detected
    class DiagramTypeError < Etassia::Error; end
  end
end
