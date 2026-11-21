# frozen_string_literal: true

module Etassia
  module Parser
    # The geometry of the one parse-error message: a line, a character
    # column, the source line and a caret under the character the column
    # names. Both parse lanes share it -- Parser::Base for the Ruby
    # grammars, Parser::Native.parse! for the compiled engine -- so a
    # caller sees the same shape whichever lane answered.
    module ErrorFormatting
      LINE_SEPARATOR = "\n"
      EMPTY_SEPARATOR = ""
      private_constant :LINE_SEPARATOR, :EMPTY_SEPARATOR

      module_function

      # The 1-based CHARACTER column of a byte offset on its line.
      #
      # A lane's line cache counts bytes, so a line holding any multibyte
      # character reports a column further right than the caret should
      # sit -- the message would then underline the wrong character.
      #
      # #lines keeps each line's terminator, so the preceding lines join
      # with no separator: the bytesize must count each terminator once.
      #
      # @param source [String] the parsed source
      # @param line [Integer] 1-based line, as the lane's cache located it
      # @param byte_offset [Integer] the failure's byte offset into +source+
      # @return [Integer] 1-based character column
      def character_column(source, line, byte_offset)
        lines = source.lines(LINE_SEPARATOR)
        preceding = lines[0, line - 1].to_a.join(EMPTY_SEPARATOR)
        within_line = byte_offset - preceding.bytesize

        lines[line - 1].to_s.byteslice(0, within_line).to_s.length + 1
      end

      # The one parse-error message: line, column, the source line and a
      # caret, with a fallback if the assembly itself blows up.
      #
      # @param source [String] the parsed source
      # @param line [Integer] 1-based line
      # @param column [Integer] 1-based character column
      # @param failure_text [String] the failure's message, position aside
      # @param fallback [String] what to return if the assembly raises
      # @return [String] the positioned, multi-line error message
      def message(source, line, column, failure_text, fallback)
        lines = source.lines(LINE_SEPARATOR)
        [
          "Parse error at line #{line}, column #{column}:",
          source_line(lines, line),
          caret_for(lines[line - 1], column),
          failure_text,
        ].join(LINE_SEPARATOR)
      rescue StandardError
        fallback
      end

      # The caret has to sit under the character the column names once the
      # message is printed. Padding with spaces put it eight columns early
      # on a tab-indented line, so the prefix is carried through with its
      # tabs intact and everything else blanked.
      #
      # @param line [String, nil] the source line being pointed at
      # @param column [Integer] 1-based character column
      # @return [String] the padding and the caret
      def caret_for(line, column)
        "#{line.to_s[0, column - 1].to_s.gsub(/[^\t]/, ' ')}^"
      end

      # @param lines [Array<String>] the source's lines
      # @param line_num [Integer] 1-based line number
      # @return [String] the line without its terminator, or a marker
      def source_line(lines, line_num)
        in_range = line_num.positive? && line_num <= lines.length
        return "(end of input)" unless in_range

        lines[line_num - 1].chomp(LINE_SEPARATOR)
      end
    end
  end
end
