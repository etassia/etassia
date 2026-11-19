# frozen_string_literal: true

# Compares the Rust runtime's SVG with the Ruby pipeline's for Mermaid corpus
# paths. Needs `etassia-native` loaded (see runtime_native_equality_spec.rb).
require "etassia/notation/plantuml" unless defined?(Etassia::Notation::PlantUML)

module NativeEquality
  CORPUS_ROOT = File.expand_path("../mermaid", __dir__)
  GIT_ROOT = File.expand_path("../plantuml/git", __dir__)

  # Corpus paths that Ruby renders, grouped by diagram type directory.
  def self.paths_by_type
    listing = File.join(CORPUS_ROOT, "corpus-renderable.txt")
    File.readlines(listing, chomp: true).group_by do |path|
      path.split("/").first
    end
  end

  # @return [Hash] :same count, :unported and :different path lists
  def self.compare(paths, root: CORPUS_ROOT)
    ruby = Etassia::Engine.new
    tally = { same: 0, unported: [], different: [] }
    paths.each { |path| record(tally, path, ruby, root) }
    tally
  end

  # The git ledger cohort, beside the mermaid corpus.
  def self.compare_git
    compare(Dir.glob(File.join(GIT_ROOT, "*.puml")).map do |path|
      path.delete_prefix("#{GIT_ROOT}/")
    end, root: GIT_ROOT)
  end

  def self.record(tally, path, ruby, root)
    source = File.read(File.join(root, path))
    if Etassia::Native.library.render(source).b == ruby.render(source).b
      tally[:same] += 1
    else
      tally[:different] << path
    end
  rescue Etassia::Native::Unported
    tally[:unported] << path
  end
  private_class_method :record
end
