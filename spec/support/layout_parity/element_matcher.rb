# frozen_string_literal: true

module SpecSupport
  module LayoutParity
    # Matches the elements of two figures by the identity contract in
    # TODO.foundation/14. Geometry is deliberately left to the comparator.
    class ElementMatcher
      def self.match(reference:, etassia:)
        new(reference, etassia).match
      end

      def initialize(reference, etassia)
        @reference = reference
        @etassia = etassia
      end

      def match
        result = aggregate(scopes.map { |scope| match_scope(scope) })

        {
          pairs: order_pairs(result[:pairs]),
          ambiguous_count: result[:ambiguous_count],
          failures: result[:failures],
        }
      end

      private

      attr_reader :reference, :etassia

      def scopes
        elements = reference.elements + etassia.elements
        elements.map { |element| scope_of(element) }.uniq
      end

      def scope_of(element)
        [element.kind, element.parent]
      end

      def match_scope(scope)
        reference_elements = in_scope(reference, scope)
        etassia_elements = in_scope(etassia, scope)
        match_by = match_mode(reference_elements, etassia_elements)
        reference_groups = group(reference_elements, match_by)
        etassia_groups = group(etassia_elements, match_by)

        group_results(scope, match_by, reference_groups, etassia_groups)
      end

      def in_scope(figure, scope)
        figure.elements.select { |element| scope_of(element) == scope }
      end

      def match_mode(reference_elements, etassia_elements)
        elements = reference_elements + etassia_elements
        elements.all? { |element| element.identity == :id } ? :id : :label
      end

      def group(elements, match_by)
        elements.group_by do |element|
          match_by == :id ? element.key : element.label
        end
      end

      def group_results(scope, match_by, reference_groups, etassia_groups)
        keys = (reference_groups.keys + etassia_groups.keys).uniq
        results = keys.map do |key|
          match_group(scope, key, match_by, reference_groups, etassia_groups)
        end
        aggregate(results)
      end

      def match_group(scope, key, match_by, reference_groups, etassia_groups)
        reference_group = reference_groups.fetch(key, [])
        etassia_group = etassia_groups.fetch(key, [])
        pairs = reference_group.zip(etassia_group).first(
          common_count(reference_group, etassia_group),
        )

        {
          pairs: pairs,
          ambiguous_count: ambiguity_count(
            reference_group, etassia_group, pairs
          ),
          failures: failure(
            scope, key, match_by, reference_group, etassia_group
          ),
        }
      end

      def common_count(reference_group, etassia_group)
        [reference_group.length, etassia_group.length].min
      end

      def ambiguous?(reference_group, etassia_group)
        reference_group.length > 1 || etassia_group.length > 1
      end

      def ambiguity_count(reference_group, etassia_group, pairs)
        ambiguous?(reference_group, etassia_group) ? pairs.length : 0
      end

      def failure(scope, key, match_by, reference_group, etassia_group)
        reference_count = reference_group.length
        etassia_count = etassia_group.length
        return [] if reference_count == etassia_count

        type = reference_count > etassia_count ? :missing : :extra
        [{
          type: type, group: [*scope, key], match_by: match_by,
          count: (reference_count - etassia_count).abs,
          reference_count: reference_count, etassia_count: etassia_count
        }]
      end

      def aggregate(results)
        results.each_with_object(empty_result) do |result, aggregate|
          aggregate[:pairs].concat(result[:pairs])
          aggregate[:ambiguous_count] += result[:ambiguous_count]
          aggregate[:failures].concat(result[:failures])
        end
      end

      def empty_result
        { pairs: [], ambiguous_count: 0, failures: [] }
      end

      def order_pairs(pairs)
        positions = reference.elements.each_with_index.to_h
        pairs.sort_by do |reference_element, _etassia_element|
          positions.fetch(reference_element)
        end
      end
    end
  end
end
