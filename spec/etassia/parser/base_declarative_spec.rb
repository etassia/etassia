# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Parser::Base do
  describe "parsers declared as a grammar and builder pair" do
    # Valid input, the diagram class it must produce, and an input whose
    # failure is on line 2 of a source that otherwise starts correctly.
    declared = {
      Etassia::Parser::C4 => ["C4Context\ntitle My System", Etassia::Diagram::C4,
                              "C4Context\n???"],
      Etassia::Parser::Info => ["info", Etassia::Diagram::Info,
                                "info\n???"],
      Etassia::Parser::Pie => ["pie\n  \"Apples\" : 42", Etassia::Diagram::Pie,
                               "pie\n???"],
      Etassia::Parser::Quadrant => ["quadrantChart\n  title T", Etassia::Diagram::Quadrant,
                                    "quadrantChart\n???"],
      Etassia::Parser::Sequence => ["sequenceDiagram\nAlice->>Bob: Hello",
                                    Etassia::Diagram::Sequence,
                                    "sequenceDiagram\n???"],
      Etassia::Parser::Gantt => ["gantt\n  title T", Etassia::Diagram::Gantt,
                                 "gantt\n???"],
      Etassia::Parser::Sankey => ["sankey-beta\nA,B,10", Etassia::Diagram::Sankey,
                                  "sankey-beta\n???"],
      Etassia::Parser::Timeline => ["timeline\n  title T\n  2002 : LinkedIn",
                                    Etassia::Diagram::Timeline,
                                    "timeline\n:"],
      Etassia::Parser::Error => ["error", Etassia::Diagram::Error,
                                 "error\n???"],
      Etassia::Parser::ErDiagram => [
        "erDiagram\nCUSTOMER ||--o{ ORDER : places",
        Etassia::Diagram::ErDiagram,
        "erDiagram\n???",
      ],
    }

    declared.each do |parser_class, (valid, diagram_class, invalid)|
      describe parser_class do
        it "parses valid input to #{diagram_class}" do
          expect(parser_class.new.parse(valid)).to be_a(diagram_class)
        end

        it "reports a syntax error with line, column and the source line" do
          source_line = Regexp.escape(invalid.lines[1])
          expect { parser_class.new.parse(invalid) }.to raise_error(
            Etassia::Parser::ParseError,
            /\AParse error at line 2, column \d+:\n#{source_line}\n/,
          )
        end
      end
    end
  end

  describe ".grammar and .builder" do
    it "inherits the builder from the parent parser" do
      expect(Class.new(Etassia::Parser::Pie).builder)
        .to eq(Etassia::Parser::Builders::Pie)
    end

    it "has no builder when nothing in the chain declares one" do
      expect(described_class.builder).to be_nil
    end

    it "raises NotImplementedError when a subclass declares nothing" do
      expect { Class.new(described_class).new.parse("x") }
        .to raise_error(NotImplementedError, /must declare grammar and builder/)
    end
  end
end
