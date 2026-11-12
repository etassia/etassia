# frozen_string_literal: true

require_relative "message"

module Etassia
  module Notation
    module PlantUML
      module Sequence
        # A message written after `&`: it is drawn on the row of the item
        # before it.
        class ParallelMessage < Message
          def parallel?
            true
          end
        end
      end
    end
  end
end
