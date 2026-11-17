# frozen_string_literal: true

require_relative "builder"
require_relative "text"
require_relative "arrow_style"
require_relative "new_parser/blocks"

module Etassia
  module Notation
    module PlantUML
      module Activity
        # Reads the new activity syntax: `start`, `:action;`, `if` ...
        # `endif`, `while`, `repeat`, `switch`, `fork`, partitions, swimlanes
        # and notes. The open ends of the flow are kept in `@ends` as
        # [node, label] pairs; a `stop` leaves none.
        class NewParser
          include Blocks

          SIMPLE = [
            [/\Astart\z/i, :on_start],
            [/\Astop\z/i, :on_stop],
            [/\Aend\z/i, :on_end],
            [/\Aend\s*group\z/i, :on_close_partition],
            [/\Akill\z/i, :on_kill],
            [/\Atitle\s+(.+)\z/i, :on_title],
            [/\A(?<colour>#\w+)?:(?<text>.*)\z/m, :on_action],
            [/\A-+(?:\[(?<spec>[^\]]*)\])?-*>\s*(?<text>.*)\z/m, :on_arrow],
            [/\A\|(?:(?<colour>#\w+)\|)?(?<name>[^|]+)\|\z/, :on_lane],
            [/\A(?:floating[ \t]+)?note[ \t]+(?:floating[ \t]+)?
              (?<side>left|right)[ \t]*(?:of[ \t]+\S+[ \t]*)?
              (?::(?<text>.*))?\z/xi, :on_note],
            [/\A(?:partition|group)\s+(?<name>.*?)(?:\s*\{)?\z/i,
             :on_partition],
            [/\A\}\z/, :on_close_partition],
          ].freeze
          STATEMENTS = (SIMPLE + Blocks::PATTERNS).freeze
          private_constant :SIMPLE, :STATEMENTS

          # @param entries [Array<Array(String, Integer)>] lines and numbers
          # @return [Diagram]
          def parse(entries)
            @builder = Builder.new
            @ends = []
            @frames = []
            @arrow = {}
            @entries = entries.each
            loop { statement(*@entries.next) }
            refuse("unclosed #{@frames.last[:kind]}", @line) if @frames.any?
            @builder.diagram
          end

          private

          def statement(line, number)
            @line = line
            @number = number
            construct = decoloured_construct(line)
            return send(*construct) if construct
            return skip_sprite(line) if SPRITE.match?(line)
            return if pragma?(line)

            match_statement(line) || match_statement(undecorated(line)) ||
              refuse("statement", line)
          end

          def pragma?(line)
            line.match?(/\A!pragma\b/)
          end

          # A `sprite $name <svg ...>...</svg>` defines an icon; its body
          # runs over several lines. Icons are dropped, the rest renders.
          SPRITE = /\Asprite[ \t]+\S+[ \t]*<svg/i
          SPRITE_REF = /<\$\w+>/
          private_constant :SPRITE, :SPRITE_REF

          def skip_sprite(line)
            until line.include?("</svg>")
              line = next_line
            end
          end

          def match_statement(line)
            STATEMENTS.each do |pattern, handler|
              match = pattern.match(line)
              next unless match

              send(handler, match)
              return true
            end
            nil
          end

          # The deprecated `#colour:` prefix on a construct line colours the
          # construct's node; the structure is what matters, so a coloured
          # construct gets its block handler with the colour dropped.
          def decoloured_construct(line)
            rest = line.match(/\A#\w+:[ \t]*(.*)\z/m)&.captures&.first
            return unless rest

            Blocks::PATTERNS.each do |pattern, handler|
              match = pattern.match(rest)
              return [handler, match] if match
            end
            nil
          end

          # A trailing `<<colour>>` on a branching line colours the arm's
          # arrow; it carries no structure, so decorated lines get a second
          # match without it.
          def undecorated(line)
            line.sub(/(?:[ \t]*<<[^<>]*>>)+\z/, "")
          end

          def on_start(_match)
            add(@builder.node(:start))
          end

          def on_stop(_match)
            add(@builder.node(:stop))
            @ends = []
          end

          # `end` ends the flow at a crossed circle.
          def on_end(_match)
            add(@builder.node(:end))
            @ends = []
          end

          # `kill` ends the flow at a cross, as `stop` ends it at a circle.
          def on_kill(_match)
            add(@builder.node(:kill))
            @ends = []
          end

          def on_title(match)
            @builder.title = clean(match[1])
          end

          def on_action(match)
            text = clean(collect(match[:text]))
            deprecate_colour(match[:colour]) if match[:colour]
            add(@builder.node(:action, text: text))
          end

          # PlantUML draws no colour from the old `#colour:` prefix; it
          # prints a notice that names the suffix to use instead.
          def deprecate_colour(colour)
            @builder.warn("This syntax is deprecated, you must add " \
                          "<<#{colour}>> at the end of the line, after " \
                          "the ';'")
          end

          def on_arrow(match)
            @arrow = ArrowStyle.parse(match[:spec], line: @number)
            text = match[:text]
            @arrow[:label] = text.empty? ? nil : clean(collect(text))
          end

          def on_lane(match)
            colour = match[:colour] && ArrowStyle.colour(match[:colour])
            @builder.lane(match[:name].strip, colour)
          end

          def on_note(match)
            text = match[:text] ? match[:text].strip : collect_note
            node = @builder.nodes.last
            refuse("note without a preceding activity", @line) unless node
            node.notes << Note.new(side: match[:side].downcase.to_sym,
                                   text: clean(text))
          end

          def on_partition(match)
            title = match[:name].gsub(/#\w+/, "").gsub(/<<.*?>>/, "")
              .delete('"').strip
            @builder.partition(title, line: @number, text: @line)
          end

          def on_close_partition(_match)
            @builder.partition(nil)
          end

          # Text that runs to the next line ending in `;`. A deprecated
          # `<<colour>>` decoration may follow the semicolon.
          TERMINATOR = /;[ \t]*(?:<<[^<>]*>>)*\z/
          private_constant :TERMINATOR

          def collect(first)
            text = first.dup
            text << "\n" << next_line until text.match?(TERMINATOR)
            text.sub(TERMINATOR, "")
          end

          def collect_note
            lines = []
            while (line = next_line) && !line.match?(/\Aend\s*note\z/i)
              lines << line
            end
            lines.join("\n")
          end

          def next_line
            @entries.next.first
          rescue StopIteration
            refuse("unterminated activity (missing `;`)", @line)
          end

          # Joins every open end to the new node, then makes it the only
          # open end.
          def add(node)
            @ends.each do |from, label|
              @builder.connect(from, node, **edge_options(label))
            end
            @arrow = {}
            @ends = [[node, nil]]
            node
          end

          def edge_options(label)
            { label: @arrow[:label] || label, colour: @arrow[:colour],
              style: @arrow[:style] }
          end

          def clean(text)
            stripped = text.gsub(SPRITE_REF, "")
            @builder.warn("sprite dropped from the label") if
              stripped != text
            Text.clean(stripped, line: @number)
          end

          def refuse(construct, text)
            raise UnsupportedConstructError.new(construct: construct,
                                                line: @number, text: text)
          end
        end
      end
    end
  end
end
