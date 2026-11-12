# frozen_string_literal: true

require_relative "../error"

module Etassia
  # Raised by {Etassia::Notation.register} when a plugin breaks the notation
  # contract: a malformed member, a duplicate id, or an extension another
  # notation already claims.
  class NotationRegistrationError < Etassia::Error; end
end
