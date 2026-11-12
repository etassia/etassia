# frozen_string_literal: true

module SpecSupport
  module LayoutParity
    # Logical class nodes shared by mmdc references and Etassia renders.
    class ClassDiagramRecognizer
      REFERENCE_NODE = /\A(?:my-svg-)?classId-(.+)-\d+\z/
      ETASSIA_NODE = /\Aclass-(.+)\z/

      def container_kinds
        []
      end

      def elements(extractor, doc)
        doc.xpath("//g[@id]").filter_map do |group|
          key = key_for(group["id"])
          next unless key

          box = extractor.bbox(group)
          next unless box

          Element.new(kind: :class, key: key, bbox: box,
                      label: extractor.label(group))
        end
      end

      private

      def key_for(id)
        id[REFERENCE_NODE, 1] || id[ETASSIA_NODE, 1]
      end
    end
  end
end
