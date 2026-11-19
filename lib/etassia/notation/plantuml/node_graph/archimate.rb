# frozen_string_literal: true

module Etassia
  module Notation
    module PlantUML
      module NodeGraph
        # `archimate #Layer "Name" as id <<archimate-type>>`. The layer name
        # is a colour in PlantUML, filled as the JAR 1.2026.6 fills it. The
        # type's icon is drawn the way the jar draws it, from the generated
        # vocabulary in {ArchimateSprites}; a type without an icon leaves a
        # plain box carrying its label.
        module Archimate
          LAYERS = {
            "business" => "#FFFFCC", "application" => "#C2F0FF",
            "technology" => "#C9FFC9", "physical" => "#97FF97",
            "motivation" => "#CCCCFF", "strategy" => "#F8E7C0",
            "implementation" => "#FFE0E0", "migration" => "#FFE0E0",
            "other" => "#FFFFFF"
          }.freeze

          SPRITE_ROOM = 20.0

          module_function

          # @param stereotype [String, nil] the `<<archimate-type>>` text,
          #   with or without the jar's `$archimate/` prefix
          # @return [Hash, nil] the type's sprite row — the icon path
          #   exactly as the jar emits it plus its placement geometry —
          #   when the type carries an icon
          def sprite(stereotype)
            name = stereotype.to_s.strip.downcase.delete_prefix("$archimate/")
            ArchimateSprites::TABLE[name]
          end

          # @param color [String, nil] a layer name or an ordinary colour
          # @return [String, nil] the colour the layer stands for, else
          #   `color` itself
          def color(color)
            LAYERS.fetch(color.to_s.downcase, color)&.delete_prefix("#")
          end
        end
      end
    end
  end
end
