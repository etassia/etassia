# frozen_string_literal: true

require "date"
require_relative "../../../diagram/gantt"
require_relative "../unsupported_construct_error"

module Etassia
  module Notation
    module PlantUML
      module Gantt
        # Reads PlantUML gantt source into the Gantt model Etassia already
        # schedules.
        #
        # A task is a `[Name]` followed by clauses: `requires` or `lasts` a
        # duration, `starts at` a date or at another task's end, `ends at` a
        # date, `happens at` a date, or `is N% completed`. `[A] -> [B]` makes
        # B follow A, `then [B] ...` makes B follow the task before it, and
        # `-- Title --` opens a section. A task with no start follows
        # nothing and begins on the project's first day. Weeks count seven
        # days, as PlantUML counts them. A line outside this subset raises
        # {UnsupportedConstructError}.
        class Reader
          DATE = /\d{4}-\d{2}-\d{2}/
          SLASH_DATE = /\d{4}\/\d{2}\/\d{2}/
          ENGLISH = /(\d{1,2})(?:st|nd|rd|th)?[ \t]+of[ \t]+
                     (january|february|march|april|may|june|july|august|
                      september|october|november|december)
                     (?:[ \t]+(\d{4}))?/ix
          STAMP = /(?:the[ \t]+)?(?:#{DATE}|#{ENGLISH})/ix
          TIME = /[ \tT]\d{1,2}:\d{2}(?::\d{2})?\b/ix
          UNIT = /(?:day|week)s?/
          SPAN = /(\d+)[ \t]+(#{UNIT})(?:[ \t]+and[ \t]+(\d+)[ \t]+(#{UNIT}))?/
          REF = /\[([^\]]+)\]/
          PROJECT = /\AProject[ \t]+starts[ \t]+(?:the[ \t]+|on[ \t]+)?
                     (?:the[ \t]+)?(#{DATE}|#{ENGLISH})\z/ix
          SECTION = /\A--+[ \t]*(.*?)[ \t]*--+\z/
          ARROW = /\A#{REF}[ \t]*-+>[ \t]*#{REF}\z/
          TASK = /\A(then[ \t]+)?#{REF}(?:[ \t]+as[ \t]+#{REF})?
                   (?:[ \t]+(.*))?\z/ix
          SKIPPED = /\A(?:title|header|footer|caption|legend|skinparam|
                     scale|printscale|ganttscale|projectscale|language|hide|
                     show|labels[ \t]+on|!\$|today[ \t]+is|(?:mon|tues|
                     wednes|thurs|fri|satur|sun)day[ \t]+(?:is|are)|
                     From[ \t]+\d{1,2}:\d{2}[ \t]+to[ \t]+\d{1,2}:\d{2}|
                     (?:#{SLASH_DATE}|#{DATE}).*[ \t](?:is|are)\b|
                     then[ \t]+\d+[ \t]+days?[ \t]+(?:is|are)[ \t]+colored|
                     #{DATE}[ \t]+is)\b/xi
          NOTE_OPEN = /\Anote[ \t]+\S+\z/i
          STYLE_OPEN = %r{\A<style>\z}i
          NOTE_CLOSE = /\Aend[ \t]+note\z/i
          STYLE_CLOSE = %r{\A</style>\z}i
          CLAUSES = [
            [/\Aon[ \t]+\{[^}]*\}/i, :ignored],
            [/\Adisplays[ \t]+on[ \t]+same[ \t]+row[ \t]+as[ \t]+#{REF}/i,
             :ignored],
            [/\Aoccurs[ \t]+from[ \t]+#{REF}[ \t]+to[ \t]+#{REF}/i, :occurs],
            [/\A(?:requires|lasts)[ \t]+#{SPAN}/i, :duration],
            [/\Astarts(?:[ \t]+at|[ \t]+on)?[ \t]+#{REF}'s[ \t]+(start|end)/i,
             :follow],
            [/\Ahappens(?:[ \t]+at)?[ \t]+#{REF}'s[ \t]+(start|end)/i,
             :happens_ref],
            [/\Ahappens[ \t]+#{SPAN}[ \t]+after[ \t]+#{REF}'s[ \t]+
              (start|end)/ix, :happens_offset],
            [/\Ahappens[ \t]+#{SPAN}[ \t]+after[ \t]+start\z/i,
             :happens_offset],
            [/\Astarts(?:[ \t]+at|[ \t]+on)?[ \t]+(#{STAMP})
             (?:#{TIME})?/ix, :start],
            [/\Aends(?:[ \t]+at|[ \t]+on)?[ \t]+(#{STAMP})
             (?:#{TIME})?/ix, :finish],
            [/\Ahappens(?:[ \t]+at|[ \t]+on)?[ \t]+(#{STAMP})
             (?:#{TIME})?/ix, :happens],
            [/\Ais[ \t]+\d+%[ \t]+complete(?:d)?/i, :ignored],
            [/\Ais[ \t]+colored[ \t]+in[ \t]+\S+/i, :ignored],
            [/\AT?\d{1,2}:\d{2}(?::\d{2})?\z/i, :ignored],
          ].freeze
          ANCHOR = "2000-01-01"
          private_constant :DATE, :SLASH_DATE, :ENGLISH, :STAMP, :TIME, :UNIT,
                           :SPAN, :REF, :PROJECT, :SECTION, :ARROW, :TASK,
                           :SKIPPED, :NOTE_OPEN, :STYLE_OPEN, :NOTE_CLOSE,
                           :STYLE_CLOSE, :CLAUSES, :ANCHOR

          # @param source [String] PlantUML source
          # @return [Array(Etassia::Diagram::Gantt, Boolean)] the model, and
          #   whether the source named the project's first day
          # @raise [UnsupportedConstructError] on a line outside the subset
          def parse(source)
            @model = Etassia::Diagram::Gantt.new
            @section = nil
            @tasks = {}
            @last = nil
            @start = nil
            @closing = nil
            @deferred = []
            lines(source).each { |text, number| read(text, number) }
            [finish, !@start.nil?]
          end

          private

          def lines(source)
            body = numbered_lines(source).drop_while do |line, _|
              !line.start_with?("@start")
            end
            body.drop(1).take_while { |line, _| !line.start_with?("@end") }
              .reject { |line, _| line.empty? || line.start_with?("'") }
          end

          def numbered_lines(source)
            text = source.dup.force_encoding(Encoding::UTF_8).scrub
            text.lines.map.with_index { |line, index| [line.strip, index + 1] }
          end

          def read(text, number)
            return close_block(text) if @closing
            return open_block(text) if block_open?(text)
            return if SKIPPED.match?(text)
            return @start = stamp(PROJECT.match(text)) if PROJECT.match?(text)
            return open_section(SECTION.match(text)[1]) if SECTION.match?(text)

            read_task(text, number)
          end

          # `<style>` and `note <position>` bodies carry presentation only;
          # the reader steps over them.
          def block_open?(text)
            STYLE_OPEN.match?(text) || NOTE_OPEN.match?(text)
          end

          def open_block(text)
            @closing = STYLE_OPEN.match?(text) ? STYLE_CLOSE : NOTE_CLOSE
          end

          def close_block(text)
            @closing = nil if @closing.match?(text)
          end

          def read_task(text, number)
            return follow(*ARROW.match(text).captures) if ARROW.match?(text)
            return task(TASK.match(text)) if TASK.match?(text)

            raise UnsupportedConstructError.new(
              construct: "gantt statement", line: number, text: text,
            )
          end

          def open_section(name)
            @section = Etassia::Diagram::GanttSection.new(name)
            @model.sections << @section
          end

          def task(match)
            then_, name, alias_name, rest = match.captures
            current = lookup(name, alias_name)
            current.after_task = @last.id if then_ && @last
            clauses(current, rest.to_s, name)
            @last = current
          end

          def clauses(task, rest, name)
            until rest.empty?
              kind, found = CLAUSES.lazy.filter_map do |pattern, symbol|
                match = pattern.match(rest)
                [symbol, match] if match
              end.first
              raise unsupported(name, rest) unless kind

              apply(task, kind, found)
              rest = found.post_match.sub(/\A[ \t]+(?:and[ \t]+)?/i, "")
            end
          end

          def unsupported(name, rest)
            UnsupportedConstructError.new(
              construct: "gantt clause", line: 0, text: "[#{name}] #{rest}",
            )
          end

          ISO_ONLY = /\A#{DATE}\z/
          private_constant :ISO_ONLY

          def apply(task, kind, match)
            case kind
            when :duration then task.duration = "#{days(match)}d"
            when :follow then follow_task(task, match)
            else apply_date(task, kind, match)
            end
          end

          def apply_date(task, kind, match)
            case kind
            when :start then task.start_date = stamp(match)
            when :finish then finish_on(task, stamp(match))
            when :happens then happen(task, stamp(match))
            else apply_point(task, kind, match)
            end
          end

          def apply_point(task, kind, match)
            case kind
            when :occurs then occurs(task, match)
            when :happens_ref then happen_at(task, match)
            when :happens_offset then happen_offset(task, match)
            end
          end

          # A point clause naming a task that has no date yet resolves after
          # the defaults are in, or not at all.
          def defer_point(task, kind, match)
            @deferred << [task, kind, match]
          end

          # @return [String] the ISO date a captured stamp holds: `2020-10-15`
          #   or `29th of September 2018`
          def stamp(match)
            text = match[1]
            return text if text.match?(ISO_ONLY)

            english = ENGLISH.match(text)
            month = Date::MONTHNAMES.index(english[2].downcase.capitalize)
            year = english[3] || ANCHOR[0, 4]
            Date.new(year.to_i, month, english[1].to_i).iso8601
          end

          # `happens at [A]'s end`: the milestone sits where A finishes.
          def happen_at(task, match)
            point = lookup(match[1], nil)
            return defer_point(task, :happens_ref, match) unless
              point.start_date

            happen(task, (Date.iso8601(point.start_date) +
                          point.duration.to_i).iso8601)
          end

          # `happens 150 days after [A]'s end` or `happens 150 days after
          # start`.
          def happen_offset(task, match)
            date = offset_date(match)
            return defer_point(task, :happens_offset, match) unless date

            task.start_date = date
            task.duration = "0d"
            task.tags << "milestone"
          end

          def offset_date(match)
            return from_project_start(match) unless match[5]

            point = lookup(match[5], nil)
            return unless point.start_date

            (shifted(point, match) + span_days(match[1], match[2])).iso8601
          end

          def from_project_start(match)
            return unless @start

            (Date.iso8601(@start) + span_days(match[1], match[2])).iso8601
          end

          def shifted(point, match)
            date = Date.iso8601(point.start_date)
            match[6].casecmp?("end") ? date + point.duration.to_i : date
          end

          # `[A] occurs from [P_start] to [P_end]`: the task spans between
          # two point tasks. A point whose date is unknown leaves the span
          # at the default.
          def occurs(task, match)
            from = lookup(match[1], nil)
            to = lookup(match[2], nil)
            unless from.start_date && to.start_date
              return defer_point(task, :occurs, match)
            end

            task.start_date = from.start_date
            task.duration = "#{span_between(from, to)}d"
          end

          def span_between(from, to)
            [Date.iso8601(to.start_date) - Date.iso8601(from.start_date), 0]
              .max
          end

          def days(match)
            first = span_days(match[1], match[2])
            return first unless match[3]

            first + span_days(match[3], match[4])
          end

          def span_days(count, unit)
            count.to_i * (unit.downcase.start_with?("w") ? 7 : 1)
          end

          def follow_task(task, match)
            unless match[2].match?(/\A(?:start|end)\z/i)
              raise unsupported(task.description,
                                "starts at [#{match[1]}]'s #{match[2]}")
            end

            add_predecessor(task, lookup(match[1], nil))
          end

          def finish_on(task, date)
            from = Date.iso8601(task.start_date || @start || ANCHOR)
            span = (Date.iso8601(date) - from).to_i
            task.duration = "#{[span, 0].max}d"
          end

          def happen(task, date)
            task.start_date = date
            task.duration = "0d"
            task.tags << "milestone"
          end

          def follow(from, to)
            add_predecessor(lookup(to, nil), lookup(from, nil))
          end

          def add_predecessor(task, predecessor)
            task.after_task = [task.after_task,
                               predecessor.id].compact.join(" ")
          end

          # Tasks are created on first mention, in a section made on demand.
          def lookup(name, alias_name)
            found = @tasks[name] || @tasks[alias_name]
            found ||= create(name)
            @tasks[alias_name] = found if alias_name
            found
          end

          def create(name)
            open_section(nil) unless @section
            Etassia::Diagram::GanttTask.new.tap do |task|
              task.description = name
              task.id = "task#{@tasks.values.uniq.length + 1}"
              task.duration = "1d"
              @tasks[name] = task
              @section.tasks << task
            end
          end

          # A task with nothing to follow starts on the project's first day;
          # then the point clauses that referenced a dateless task get their
          # best-effort resolution.
          def finish
            apply_defaults
            @deferred.each do |task, kind, match|
              apply_point(task, kind, match)
            end
            @model
          end

          def apply_defaults
            first = @start || ANCHOR
            @model.sections.flat_map(&:tasks).each do |task|
              task.start_date ||= first unless task.after_task
            end
          end
        end
      end
    end
  end
end
