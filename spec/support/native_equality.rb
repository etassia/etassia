# frozen_string_literal: true

# Compares the Rust runtime's SVG with the Ruby pipeline's for Mermaid corpus
# paths. Needs `etassia-native` loaded (see runtime_native_equality_spec.rb).
require "etassia/notation/plantuml"
# The external notations ride the registry opt-in, not the require.
Etassia::Notation.register(Etassia::Notation::PlantUML) unless
  Etassia::Notation.send(:entries).key?(:plantuml)

module NativeEquality
  CORPUS_ROOT = File.expand_path("../mermaid", __dir__)
  GIT_ROOT = File.expand_path("../plantuml/git", __dir__)
  DITAA_ROOT = File.expand_path("../plantuml/ditaa", __dir__)
  COMPONENT_ROOT = File.expand_path("../plantuml/component", __dir__)
  USECASE_ROOT = File.expand_path("../plantuml/usecase", __dir__)
  TIMING_ROOT = File.expand_path("../plantuml/timing", __dir__)
  GANTT_ROOT = File.expand_path("../plantuml/gantt", __dir__)
  MINDMAP_ROOT = File.expand_path("../plantuml/mindmap", __dir__)
  ACTIVITY_ROOT = File.expand_path("../plantuml/activity", __dir__)
  STATE_ROOT = File.expand_path("../plantuml/state", __dir__)
  CLASS_ROOT = File.expand_path("../plantuml/class", __dir__)
  SEQUENCE_ROOT = File.expand_path("../plantuml/sequence", __dir__)

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

  # The ditaa ledger cohort, beside the mermaid corpus.
  def self.compare_ditaa
    compare(Dir.glob(File.join(DITAA_ROOT, "*.puml")).map do |path|
      path.delete_prefix("#{DITAA_ROOT}/")
    end, root: DITAA_ROOT)
  end

  # The archimate ledger cohort, beside the mermaid corpus.
  def self.compare_component
    paths = Dir.glob(File.join(COMPONENT_ROOT, "archimate.*.puml"))
    compare(paths.map { |path| path.delete_prefix("#{COMPONENT_ROOT}/") },
            root: COMPONENT_ROOT)
  end

  # The use case ledger cohort, beside the mermaid corpus.
  def self.compare_usecase
    paths = Dir.glob(File.join(USECASE_ROOT, "*.puml"))
    compare(paths.map { |path| path.delete_prefix("#{USECASE_ROOT}/") },
            root: USECASE_ROOT)
  end

  # The timing ledger cohort, beside the mermaid corpus.
  def self.compare_timing
    paths = Dir.glob(File.join(TIMING_ROOT, "*.puml"))
    compare(paths.map { |path| path.delete_prefix("#{TIMING_ROOT}/") },
            root: TIMING_ROOT)
  end

  GANTT_ERROR_CASE = "resources.vega.xgantt.gantt2--e5ccf8ad316d.puml"

  # The gantt ledger cohort, beside the mermaid corpus. The gantt2 case is
  # left out: its trailing `and foo` makes both pipelines raise
  # {Etassia::Notation::PlantUML::UnsupportedConstructError}, so there are
  # no SVG bytes to compare.
  def self.compare_gantt
    paths = Dir.glob(File.join(GANTT_ROOT, "*.puml")).reject do |path|
      File.basename(path) == GANTT_ERROR_CASE
    end
    compare(paths.map { |path| path.delete_prefix("#{GANTT_ROOT}/") },
            root: GANTT_ROOT)
  end

  # The mindmap ledger cohort, beside the mermaid corpus.
  def self.compare_mindmap
    paths = Dir.glob(File.join(MINDMAP_ROOT, "*.puml"))
    compare(paths.map { |path| path.delete_prefix("#{MINDMAP_ROOT}/") },
            root: MINDMAP_ROOT)
  end

  # The activity ledger cohort, beside the mermaid corpus.
  def self.compare_activity
    paths = Dir.glob(File.join(ACTIVITY_ROOT, "*.puml"))
    compare(paths.map { |path| path.delete_prefix("#{ACTIVITY_ROOT}/") },
            root: ACTIVITY_ROOT)
  end

  # The class ledger cohort, beside the mermaid corpus. The `+package` and
  # `set namespaceSeparator` cases are left out: the Ruby reader raises
  # {Etassia::Notation::PlantUML::UnsupportedConstructError} for both, so
  # there are no SVG bytes to compare (the Rust port refuses them too).
  CLASS_ERROR_CASES = [
    "resources.vega.nonreg.group2846.bug--3c78f8407a42.puml",
    "resources.vega.nonreg.simple.NamespaceSeparatorColon001--" \
    "c4bc36daba29.puml",
  ].freeze

  def self.compare_class
    paths = Dir.glob(File.join(CLASS_ROOT, "*.puml")).reject do |path|
      CLASS_ERROR_CASES.include?(File.basename(path))
    end
    compare(paths.map { |path| path.delete_prefix("#{CLASS_ROOT}/") },
            root: CLASS_ROOT)
  end

  # The state ledger cohort, beside the mermaid corpus.
  def self.compare_state
    paths = Dir.glob(File.join(STATE_ROOT, "*.puml"))
    compare(paths.map { |path| path.delete_prefix("#{STATE_ROOT}/") },
            root: STATE_ROOT)
  end

  # The sequence ledger cohort, beside the mermaid corpus.
  def self.compare_sequence
    paths = Dir.glob(File.join(SEQUENCE_ROOT, "*.puml"))
    compare(paths.map { |path| path.delete_prefix("#{SEQUENCE_ROOT}/") },
            root: SEQUENCE_ROOT)
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
