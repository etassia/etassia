# frozen_string_literal: true

module Etassia
  module Diagram
    # The model behind PlantUML's `@startgit` panels: an ASCII git-log
    # drawing where a `*` marks a commit on its rail, `|` continues a rail,
    # and `/` and `\` switch rails. The reader keeps every line's rail
    # positions; the layout turns consecutive positions into the curves.
    class GitLog
      Commit = Struct.new(:name, :rail, :line, keyword_init: true)

      attr_reader :lines, :commits

      # @param lines [Array<Hash>] per source line: {rails: [Integer] the
      #   columns occupied, star: Integer or nil the commit column,
      #   name: String or nil}
      # @param commits [Array<Commit>]
      def initialize(lines:, commits:)
        @lines = lines
        @commits = commits
        freeze
      end

      NAME_STRIP = /[-.*|\/\\]/
      private_constant :NAME_STRIP

      # Reads the body lines of an `@startgit` block.
      #
      # @param body_lines [Array<String>]
      # @return [GitLog]
      def self.parse(body_lines)
        lines = body_lines.each_with_index.map do |line, index|
          read_line(line.chomp, index)
        end
        commits = lines.filter_map do |line|
          next unless line[:star]

          Commit.new(name: commit_name(line[:raw]), rail: line[:star],
                     line: line[:number])
        end
        new(lines: lines, commits: commits)
      end

      def self.read_line(raw, number = 0)
        star = raw.index("*")
        rails = raw.each_char.with_index
          .select { |char, _| "|*\\".include?(char) || char == "/" }
          .map(&:last)
        { raw: raw, number: number, star: star, rails: rails.uniq.sort }
      end

      # The commit name: everything after the `*` with the drawing
      # characters stripped, up to the first space.
      def self.commit_name(raw)
        after_star = raw[raw.index("*")..]
        cleaned = after_star.gsub(NAME_STRIP, "").strip
        space = cleaned.index(" ")
        space ? cleaned[0...space] : cleaned
      end
    end
  end
end
