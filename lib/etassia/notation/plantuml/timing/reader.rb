# frozen_string_literal: true

require "date"
require_relative "../state/reader"
require_relative "../unsupported_construct_error"
require_relative "model"

module Etassia
  module Notation
    module PlantUML
      module Timing
        # Reads a timing diagram: participants, `@time` sections holding
        # state changes and messages, highlights and `scale`. A time is a
        # number, `+number` (after the previous `@`) or a `YYYY/MM/DD` date.
        # A line outside this subset raises {UnsupportedConstructError}.
        class Reader
          # A source line and its number.
          Line = Struct.new(:number, :text)

          ID = /[A-Za-z_]\w*/
          KINDS = "robust|concise|clock|binary|analog"
          TIME = %r{\+?\d+(?:\.\d+)?|\d{4}/\d{2}/\d{2}}
          NUMBER = /\d+(?:\.\d+)?/
          CLOCK =
            /(?:[ \t]+with[ \t]+period[ \t]+(?<period>#{NUMBER})
              (?:[ \t]+pulse[ \t]+(?<pulse>#{NUMBER}))?
              (?:[ \t]+(?:and[ \t]+)?offset[ \t]+(?<offset>#{NUMBER}))?)?/xo
          STYLE_OPEN = %r{\A<style>\z}i
          STYLE_CLOSE = %r{\A</style>\z}i
          RULES = [
            [/\A(?<kind>#{KINDS})[ \t]+(?:"(?<title>[^"]+)"[ \t]+as[ \t]+
              (?<id>#{ID})|(?<bare>#{ID}))#{CLOCK}\z/xio, :participant],
            [/\A@(?<time>#{TIME})\z/o, :at],
            [/\A@(?<anchor>#{ID})\z/o, :at_participant],
            [/\A(?<id>#{ID})[ \t]+is[ \t]+(?<state>.+)\z/o, :change],
            [/\A(?<from>#{ID})[ \t]*->[ \t]*(?<to>#{ID})
              (?:@(?<arrives>#{TIME}))?
              (?:[ \t]*:[ \t]*(?<label>.*))?\z/xo, :message],
            [/\Ahighlight[ \t]+(?<from>#{TIME})[ \t]+to[ \t]+(?<to>#{TIME})
              (?:[ \t]+(?<colour>\#\S+))?
              (?:[ \t]*:[ \t]*(?<caption>.*))?\z/xo, :highlight],
            [/\Ascale[ \t]+(?<units>\d+)[ \t]+as[ \t]+(?<pixels>\d+)[ \t]+
              pixels\z/xi, :scale],
          ].freeze
          # `@T <-> @+N : {..}` states a duration constraint between two
          # anchors; the model has no slot for it, so the line steps over.
          CONSTRAINT = /\A@#{TIME}[ \t]*<->/xo
          SKIPPED = /\A(?:title|hide|skinparam|header|footer|caption)\b/i
          private_constant :Line, :ID, :KINDS, :TIME, :NUMBER, :CLOCK,
                           :STYLE_OPEN, :STYLE_CLOSE, :RULES, :CONSTRAINT,
                           :SKIPPED

          # @param source [String] PlantUML source
          # @return [Diagram]
          # @raise [UnsupportedConstructError] on a line outside the subset
          def parse(source)
            @diagram = Diagram.new(participants: {}, changes: [],
                                   messages: [], highlights: [], dated: false)
            @now = 0
            @closing = nil
            State::Reader.lines_of(source).each do |text, number|
              read(Line.new(number, text))
            end
            @diagram
          end

          private

          def read(line)
            return close_style(line.text) if @closing
            return open_style(line.text) if STYLE_OPEN.match?(line.text)
            return if skippable?(line)

            rule = match_rule(line)
            raise refused(line) unless rule

            send(rule.first, line, rule.last)
          end

          def skippable?(line)
            SKIPPED.match?(line.text) || CONSTRAINT.match?(line.text)
          end

          def match_rule(line)
            RULES.each do |pattern, handler|
              match = pattern.match(line.text)
              if match
                return [handler,
                        match.named_captures.transform_keys(&:to_sym)]
              end
            end
            nil
          end

          # A `<style>` body carries presentation only; the reader steps
          # over it.
          def open_style(_text)
            @closing = STYLE_CLOSE
          end

          def close_style(text)
            @closing = nil if STYLE_CLOSE.match?(text)
          end

          def refused(line)
            UnsupportedConstructError.new(construct: "timing statement",
                                          line: line.number, text: line.text)
          end

          def participant(line, fields)
            kind = fields[:kind].downcase
            raise refused(line) if kind == "clock" && fields[:period].to_i <= 0

            id = fields[:id] || fields[:bare]
            @diagram.participants[id] = Participant.new(
              id: id, title: fields[:title] || id, kind: kind, **clock(fields),
            )
          end

          def clock(fields)
            period = fields[:period].to_f
            { period: period, pulse: fields[:pulse]&.to_f || (period / 2),
              offset: fields[:offset].to_f }
          end

          def at(_line, fields)
            @now = moment(fields[:time], @now)
          end

          # `@WU` anchors time where WU last changed, or 0 before that.
          def at_participant(line, fields)
            id = fields[:anchor]
            known(line, id)
            @now = @diagram.changes.select { |change| change.id == id }
              .map(&:time).max || 0
          end

          def change(line, fields)
            known(line, fields[:id])
            rest = fields[:state]
            fill, stroke = colours(rest[/\s+(#\S+)\z/, 1])
            @diagram.changes << Change.new(
              id: fields[:id], time: @now, state: state_name(rest),
              fill: fill, stroke: stroke
            )
          end

          def state_name(rest)
            rest.sub(/\s+#\S+\z/, "").strip.delete_prefix('"')
              .delete_suffix('"')
          end

          def message(line, fields)
            known(line, fields[:from])
            known(line, fields[:to])
            @diagram.messages << Message.new(
              from: fields[:from], to: fields[:to], time: @now,
              arrives: fields[:arrives]&.to_f, text: fields[:label].to_s
            )
          end

          def highlight(_line, fields)
            fill, stroke = colours(fields[:colour])
            @diagram.highlights << Highlight.new(
              from: moment(fields[:from], 0), to: moment(fields[:to], 0),
              fill: fill, stroke: stroke, caption: fields[:caption]&.strip
            )
          end

          def scale(_line, fields)
            @diagram.scale_units = fields[:units].to_i
            @diagram.pixels_per_unit =
              fields[:pixels].to_f / fields[:units].to_i
          end

          def known(line, id)
            return if @diagram.participants.key?(id)

            raise refused(line)
          end

          # `#fill;line:colour` into [fill, line], each a CSS colour or nil.
          def colours(spec)
            return [nil, nil] unless spec

            fill, stroke = spec.delete_prefix("#").split(";line:", 2)
            [css(fill), css(stroke)]
          end

          def css(name)
            return if name.nil? || name.empty?
            return "##{name}" if name.match?(/\A\h{3}(?:\h{3})?\z/)

            name if name.match?(/\A[A-Za-z]+\z/)
          end

          def moment(text, base)
            return date_seconds(text) if text.include?("/")

            value = text.to_f
            text.start_with?("+") ? base + value : value
          end

          def date_seconds(text)
            @diagram.dated = true
            days = Date.strptime(text, "%Y/%m/%d") - Date.new(1970, 1, 1)
            days.to_i * 86_400.0
          rescue Date::Error
            raise refused(Line.new(0, text))
          end
        end
      end
    end
  end
end
