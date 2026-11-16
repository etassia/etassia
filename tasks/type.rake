# frozen_string_literal: true

# `rake 'type:new[kanban]'` scaffolds a diagram type and registers it.
# Quote the task: unquoted brackets die in zsh.
namespace :type do
  desc "Scaffold a diagram type: files, specs and its TYPES row"
  task :new, [:name] do |_task, args|
    require "etassia"
    require_relative "support/type_generator"

    name = args[:name] or abort "usage: rake 'type:new[name]'"
    generator = Etassia::TypeGenerator.new(
      name,
      root: File.expand_path("..", __dir__),
      types: Etassia::Notation::Mermaid::TYPES,
    )
    puts generator.call
  rescue Etassia::TypeGenerator::Error => e
    abort "type:new failed: #{e.message}"
  end
end

namespace :notations do
  desc "Build the diagram-type coverage matrix (scoreboard/coverage.json + docs/COVERAGE.md)"
  task :coverage do
    require_relative "../scripts/coverage_matrix"
    paths = CoverageMatrix.write!
    puts "coverage matrix written: #{paths.join(', ')}"
  end
end
