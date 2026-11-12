# frozen_string_literal: true

module SpecSupport
  module LayoutParity
    # Immutable evidence for one reference/candidate parity comparison.
    CaseResult = Data.define(
      :case_id,
      :type,
      :reference,
      :etassia_status,
      :invariants,
      :geometry,
      :reproduce,
    ) do
      def to_h
        {
          case: case_id,
          type: type,
          reference: reference,
          etassia_status: etassia_status,
          invariants: invariants,
          geometry: geometry,
          reproduce: reproduce,
        }
      end

      def hard_failure?
        etassia_status != "rendered" || invariants.any? || unmatched_nonempty?
      end

      private

      def unmatched_nonempty?
        geometry.fetch(:matched).zero? && !both_figures_empty?
      end

      def both_figures_empty?
        geometry.fetch(:reference_elements).zero? &&
          geometry.fetch(:etassia_elements).zero?
      end
    end
  end
end
