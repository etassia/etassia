# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Parser::Builders::CaptureString do
  # Parslet captures an empty quoted string as `[]`; each row feeds one
  # through a parser and reads back the label the builder produced.
  rows = [
    ["class label falls back to the id",
     Etassia::Parser::ClassDiagram,
     "classDiagram\n  class C1[\"\"]\n",
     ->(d) { d.entities.first.name }, "C1"],
    ["c4 element label is empty",
     Etassia::Parser::C4,
     "C4Context\n  Person(p, \"\")\n",
     ->(d) { d.elements.first.label }, ""],
    ["pie slice label is empty and the slice is kept",
     Etassia::Parser::Pie,
     "pie\n  \"\" : 1\n  \"b\" : 2\n",
     ->(d) { d.slices.map(&:label) }, ["", "b"]],
    ["quadrant axis label is empty",
     Etassia::Parser::Quadrant,
     "quadrantChart\n  x-axis \"\" --> R\n",
     :x_axis_left.to_proc, ""],
  ]

  rows.each do |name, parser, source, reader, expected|
    it name do
      expect(reader.call(parser.new.parse(source))).to eq(expected)
    end
  end
end
