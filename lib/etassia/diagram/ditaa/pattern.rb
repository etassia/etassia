# frozen_string_literal: true

module Etassia
  module Diagram
    class Ditaa
      # The 3x3 grid patterns behind shape recognition: a verbatim port of
      # ascii2image's GridPattern DSL.
      #
      # `.` any - `!` not a boundary - `|` vertical run - `-` horizontal run -
      # `[` not vertical - `~` any - `(` horizontal-ish boundary - `^`
      # vertical-ish boundary - `s` straight boundary - `S` diagonal - digits
      # the entry-point sets - `%n` their negations - `+`, `\`, `/` literal.
      # Only three tokens per row are read (the jar stops there too).
      class Pattern
        CLASSES = {
          "." => ".",
          "[" => "[^|:]",
          "|" => "[|:]",
          "-" => "[-=]",
          "!" => '[^-=\/\\\\+|:]',
          "b" => '[-=\/\\\\+|:]',
          "^" => '[\/\\\\+|:]',
          "(" => '[-=\/\\\\+]',
          "~" => ".",
          "+" => '\+',
          "\\" => "\\\\",
          "/" => "/",
          "s" => "[-=+|:]",
          "S" => '[\/\\\\]',
          "*" => '\*',
          "1" => '[\\\\]',
          "2" => '[|:+\/\\\\]',
          "3" => '[\/]',
          "4" => '[-=+\/\\\\]',
          "5" => '[\\\\]',
          "6" => '[|:+\/\\\\]',
          "7" => '[\/]',
          "8" => '[-=+\/\\\\]',
          "%1" => '[^\\\\]',
          "%2" => '[^|:+\/\\\\]',
          "%3" => '[^\/]',
          "%4" => '[^-=+\/\\\\]',
          "%5" => '[^\\\\]',
          "%6" => '[^|:+\/\\\\]',
          "%7" => '[^\/]',
          "%8" => '[^|:+\/\\\\]',
        }.freeze

        TOKEN_LIMIT = 3
        private_constant :TOKEN_LIMIT

        def initialize(row1, row2, row3)
          @rows = [row1, row2, row3]
          @regexps = @rows.map { |row| Regexp.new("\\A#{to_regexp(row)}\\z") }
        end

        def to_regexp(pattern)
          source = +""
          token = 0
          cursor = 0
          while cursor < pattern.length && token < TOKEN_LIMIT
            consumed = append_token(source, pattern, cursor)
            cursor += consumed
            token += 1
          end
          source
        end

        # Returns how many pattern characters the token consumed.
        def append_token(source, pattern, cursor)
          two = pattern[cursor, 2]
          if CLASSES.key?(two)
            source << CLASSES[two]
            2
          else
            single_token(source, pattern, cursor)
          end
        end

        def single_token(source, pattern, cursor)
          char = pattern[cursor]
          source << if CLASSES.key?(char)
                      CLASSES[char]
                    else
                      # The jar falls through to a literal for anything unknown.
                      Regexp.escape(char)
                    end
          1
        end

        def matched_by?(grid)
          @regexps.each_with_index.all? do |regexp, row|
            regexp.match?(grid.rows[row] || "")
          end
        end
      end

      # The named criteria groups, in the jar's exact rows and composition.
      module PatternGroup
        module_function

        def group(*patterns) = patterns.freeze

        CROSS = group(Pattern.new(".6.", "4+8", ".2.")).freeze
        K = group(Pattern.new(".6.", "%4+8", ".2.")).freeze
        INVERSE_K = group(Pattern.new(".6.", "4+%8", ".2.")).freeze
        T = group(Pattern.new(".%6.", "4+8", ".2.")).freeze
        INVERSE_T = group(Pattern.new(".6.", "4+8", ".%2.")).freeze

        NORMAL_CORNER1 = group(Pattern.new(".[.", "~+(", ".^.")).freeze
        NORMAL_CORNER2 = group(Pattern.new(".[.", "(+~", ".^.")).freeze
        NORMAL_CORNER3 = group(Pattern.new(".^.", "(+~", ".[.")).freeze
        NORMAL_CORNER4 = group(Pattern.new(".^.", "~+(", ".[.")).freeze

        ROUND_CORNER1 = group(Pattern.new(".[.", "~/4", ".2.")).freeze
        ROUND_CORNER2 = group(Pattern.new(".[.", "4\\~", ".2.")).freeze
        ROUND_CORNER3 = group(Pattern.new(".6.", "4/~", ".[.")).freeze
        ROUND_CORNER4 = group(Pattern.new(".6.", "~\\8", ".[.")).freeze

        STUB = group(
          Pattern.new("!^!", "!+!", ".!."),
          Pattern.new("!^!", "!+!", ".-."),
          Pattern.new("!!.", "(+!", "!!."),
          Pattern.new("!!.", "(+|", "!!."),
          Pattern.new(".!.", "!+!", "!^!"),
          Pattern.new(".-.", "!+!", "!^!"),
          Pattern.new(".!!", "!+(", ".!!"),
          Pattern.new(".!!", "|+(", ".!!"),
        ).freeze

        VERTICAL_LINES_END = group(
          Pattern.new(".^.", ".|.", ".!."),
          Pattern.new(".^.", ".|.", ".-."),
          Pattern.new(".!.", ".|.", ".^."),
          Pattern.new(".-.", ".|.", ".^."),
        ).freeze

        HORIZONTAL_LINES_END = group(
          Pattern.new("...", "(-!", "..."),
          Pattern.new("...", "(-|", "..."),
          Pattern.new("...", "!-(", "..."),
          Pattern.new("...", "|-(", "..."),
        ).freeze

        HORIZONTAL_CROSS_ON_LINE = group(Pattern.new("...", "(+(",
                                                     "...")).freeze
        VERTICAL_CROSS_ON_LINE = group(Pattern.new(".^.", ".+.", ".^.")).freeze

        HORIZONTAL_STAR_ON_LINE = group(
          Pattern.new("...", "(*(", "..."),
          Pattern.new("...", "!*(", "..."),
          Pattern.new("...", "(*!", "..."),
        ).freeze
        VERTICAL_STAR_ON_LINE = group(
          Pattern.new(".^.", ".*.", ".^."),
          Pattern.new(".!.", ".*.", ".^."),
          Pattern.new(".^.", ".*.", ".!."),
        ).freeze

        LONE_DIAGONAL = group(
          Pattern.new(".%6%7", "%4/%8", "%3%2."),
          Pattern.new("%1%6.", "%4\\%8", ".%2%5"),
        ).freeze

        NORMAL_CORNER = (
          NORMAL_CORNER1 + NORMAL_CORNER2 + NORMAL_CORNER3 + NORMAL_CORNER4
        ).freeze
        ROUND_CORNER = (
          ROUND_CORNER1 + ROUND_CORNER2 + ROUND_CORNER3 + ROUND_CORNER4
        ).freeze
        CORNER1 = (NORMAL_CORNER1 + ROUND_CORNER1).freeze
        CORNER2 = (NORMAL_CORNER2 + ROUND_CORNER2).freeze
        CORNER3 = (NORMAL_CORNER3 + ROUND_CORNER3).freeze
        CORNER4 = (NORMAL_CORNER4 + ROUND_CORNER4).freeze
        CORNER = (NORMAL_CORNER + ROUND_CORNER).freeze
        INTERSECTION = (CROSS + K + T + INVERSE_K + INVERSE_T).freeze
        CROSS_ON_LINE =
          (HORIZONTAL_CROSS_ON_LINE + VERTICAL_CROSS_ON_LINE).freeze
        STAR_ON_LINE =
          (HORIZONTAL_STAR_ON_LINE + VERTICAL_STAR_ON_LINE).freeze
        LINES_END = (HORIZONTAL_LINES_END + VERTICAL_LINES_END + STUB).freeze
      end

      module PatternGroupMatching
        def matches_group?(pattern_group)
          pattern_group.any? { |pattern| pattern.matched_by?(self) }
        end
      end

      Grid.include(PatternGroupMatching)
    end
  end
end
