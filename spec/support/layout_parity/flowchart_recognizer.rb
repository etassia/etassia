# frozen_string_literal: true

module SpecSupport
  module LayoutParity
    # Flowchart elements for both sides (contract section 1):
    #   reference: g.node id="flowchart-<id>-<n>", g.cluster id="<id>"
    #   Etassia:    g id="node-<id>",               g id="cluster-<id>"
    # The label group (reference g.label, g.cluster-label) is excluded from a
    # bbox: mermaid draws an attribute-less placeholder rect in it.
    class FlowchartRecognizer
      LABEL_CLASSES = %w[label cluster-label].freeze
      REFERENCE_NODE = /\Aflowchart-(.+)-\d+\z/
      ETASSIA_NODE = /\Anode-(.+)\z/
      ETASSIA_CLUSTER = /\Acluster-(.+)\z/

      def container_kinds
        [:cluster]
      end

      def elements(extractor, doc)
        doc.xpath("//g[@id]").filter_map do |g|
          kind, key = identify(g)
          next unless kind

          box = extractor.bbox(g, exclude: LABEL_CLASSES)
          next unless box

          Element.new(kind: kind, key: key, bbox: box,
                      label: extractor.label(g))
        end
      end

      private

      def identify(group)
        id = group["id"]
        classes = group["class"].to_s.split
        reference_kind(reference_id(group), classes) || etassia_kind(id)
      end

      def reference_id(group)
        root_id = group.document.root["id"].to_s
        group["id"].delete_prefix("#{root_id}-")
      end

      def reference_kind(id, classes)
        return [:node, id[REFERENCE_NODE, 1] || id] if classes.include?("node")

        [:cluster, id] if classes.include?("cluster")
      end

      def etassia_kind(id)
        if (key = id[ETASSIA_NODE, 1])
          [:node, key]
        elsif (key = id[ETASSIA_CLUSTER, 1])
          [:cluster, key]
        end
      end
    end
  end
end
