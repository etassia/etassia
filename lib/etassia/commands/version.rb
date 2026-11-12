# frozen_string_literal: true

module Etassia
  module Commands
    # Command to display the gem version.
    class VersionCommand
      attr_reader :options

      # Creates a new version command.
      #
      # @param options [Hash] command options
      def initialize(options = {})
        @options = options
      end

      # Executes the version command.
      #
      # @return [void]
      def run
        puts "etassia version #{Etassia::VERSION}"
      end
    end
  end
end
