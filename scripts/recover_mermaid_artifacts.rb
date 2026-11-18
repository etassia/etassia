# frozen_string_literal: true

# Recovers the damaged corpus cases (#454): cases whose source is known
# extraction damage - an uninterpolated ${...} JS template, a truncated
# concatenation, or HTML-entity-escaped text. The upstream test file that
# built the source is in the pinned mermaid checkout; tools/js-recovery/
# recover-templates.mjs parses that file with acorn and evaluates every
# template literal and string concatenation against the file's own const
# bindings and describe.each parameters, so a recovery uses JavaScript's
# own semantics, not a guess. This script matches the evaluated values
# back to the damaged cases, decodes the entity-escaped HTML fixtures with
# CGI.unescapeHTML, and - with --write - replaces the corpus sources that
# a recovery renders.
#
#   ruby scripts/recover_mermaid_artifacts.rb [--checkout DIR] [--write]
#
# An "indented frontmatter closer" case is upstream-verbatim text that
# mermaid's own browser tests accept and mmdc refuses; those keep their
# artifact verdicts, as do cases with no candidate that renders.
require "cgi"
require "digest"
require "json"
require "open3"
require "optparse"
require "tmpdir"
require "yaml"
require "rexml/document"

require_relative "corpus_case_identity"
require_relative "hardened_mmdc"

module ArtifactRecovery
  UPSTREAM = File.expand_path("~/src/etassia/mermaid-upstream")
  RECOVERY = File.expand_path("tools/js-recovery/recover-templates.mjs",
                              "~/src/etassia")
  CORPUS = File.expand_path("spec/mermaid", "#{__dir__}/..")
  VERDICTS = File.join(CORPUS, "corpus-verdicts.yml")

  class Error < StandardError; end

  module_function

  def artifact_cases
    rows = YAML.load_file(VERDICTS)
    rows = rows.fetch("verdicts") if rows.is_a?(Hash)
    rows.select { |row| row.is_a?(Hash) && row["verdict"] == "artifact" }
  end

  def meta_for(case_id)
    JSON.parse(File.read(File.join(CORPUS, "#{case_id}.meta.json")))
  end

  def upstream_path(source_file)
    File.join(UPSTREAM, "/#{source_file.split('mermaid-js/')[-1]}")
  end

  # Evaluated sources of one upstream file, via the acorn harness.
  def evaluated_of(path)
    out, status = Open3.capture2("node", RECOVERY, path)
    raise Error, "node harness failed on #{path}" unless status.success?

    JSON.parse(out)
  end

  # A candidate only becomes a case when mmdc renders it: a recovery mmdc
  # still refuses keeps the damaged case and its artifact verdict.
  def renders?(source)
    dir = Dir.mktmpdir
    input = File.join(dir, "recovered.mmd")
    output = File.join(dir, "recovered.svg")
    File.write(input, source)
    HardenedMmdc.run_mmdc(input, output)
    well_formed_svg?(output)
  end

  def well_formed_svg?(path)
    return false unless File.file?(path) && File.size?(path)

    root = REXML::Document.new(File.read(path)).root
    root&.name == "svg"
  rescue REXML::ParseException
    false
  end

  # Rename a damaged case to its recovered identity: the recovered source
  # under the recomputed id, an updated meta, and the stale files gone.
  def write_recovery(case_id, meta, candidate)
    new_id = new_id(meta, meta.fetch("type"), candidate)
    old_base = File.join(CORPUS, case_id)
    new_base = File.join(CORPUS, new_id)
    File.write("#{new_base}.mmd", candidate)
    File.write("#{new_base}.meta.json",
               "#{recovered_meta(meta, new_id, candidate)}\n")
    Dir.glob("#{old_base}.*").each { |path| File.delete(path) }
    "#{case_id} -> #{new_id}"
  end

  def recovered_meta(meta, new_id, candidate)
    JSON.pretty_generate(
      meta.merge("id" => new_id,
                 "source_sha256" => Digest::SHA256.hexdigest(candidate),
                 "recovered" => true),
    )
  end

  # The new case id for a recovered source: the same identity scheme the
  # extractor uses, with the recovered source in the digest.
  def new_id(meta, type, source)
    test_name = meta.dig("metadata", "test_name")
    occurrence = meta.fetch("name", "").sub(/\A.*_(\d+)\z/, '\1').to_i
    CorpusCaseIdentity.id_for(
      type: type,
      upstream_path: meta.fetch("source_file"),
      title: test_name,
      occurrence: occurrence,
      source: source,
    )
  end

  # The candidate for one case: an evaluated source whose every line the
  # damaged source's static parts match (each removed ${...} acts as a
  # wildcard between the parts). Ties go to the candidate built nearest
  # the recorded line.
  def candidate_for(meta, damaged)
    path = upstream_path(meta.fetch("source_file"))
    return entity_candidate(path, meta) if path.end_with?(".html")

    matches = matching_candidates(path, damaged)
    return if matches.empty?

    line = meta.fetch("line_number", 1).to_i
    matches.min_by { |candidate_line, _| (candidate_line - line).abs }[1]
  end

  def matching_candidates(path, damaged)
    evaluated_of(path).filter_map do |entry|
      [entry["line"], entry["value"]] if full_match?(entry["value"], damaged)
    end
  end

  # Each damaged line must be matched by some evaluated line, with each
  # removed ${...} acting as a wildcard between the line's static parts.
  def full_match?(evaluated, damaged)
    evaluated_lines = evaluated.lines.map(&:strip)
    damaged_lines(damaged).all? do |raw|
      pattern = line_pattern(raw)
      pattern.nil? || evaluated_lines.any? { |line| pattern.match?(line) }
    end
  end

  def damaged_lines(damaged)
    damaged.lines.map(&:strip).reject(&:empty?)
  end

  def line_pattern(raw)
    parts = raw.gsub(/\$\{[^}]*\}/, " ").split
      .map { |part| Regexp.escape(part.strip) }.reject(&:empty?)
    return if parts.empty?

    # A removed ${...} may sit at either end of the line, so the static
    # parts match anywhere within it, in order.
    /\A.*#{parts.join('.*')}.*\z/
  end

  # A cypress platform fixture: the browser hands mermaid the <pre> text
  # with its entities decoded, so the true source is the decoded block.
  def entity_candidate(path, meta)
    text = File.read(path)
    line = meta.fetch("line_number", 1).to_i
    block = text.lines[(line - 1)..].join[/^[^\n]*\n(.*?)(<\/pre>)/m, 1]
    return unless block

    "#{CGI.unescapeHTML(block).sub(/^.*?\n/, '').sub(/[ \t]*\z/, '')}\n"
  end
end

if __FILE__ == $PROGRAM_NAME
  options = { write: false }
  OptionParser.new do |parser|
    parser.on("--checkout DIR") { |value| options[:checkout] = value }
    parser.on("--write") { options[:write] = true }
  end.parse!

  if options[:checkout]
    ArtifactRecovery.const_set(:UPSTREAM, File.expand_path(options[:checkout]))
  end

  stats = Hash.new(0)
  renames = []
  unresolved = []
  ArtifactRecovery.artifact_cases.each do |record|
    case_id = record["case"].delete_suffix(".mmd")
    meta = ArtifactRecovery.meta_for(case_id)
    damaged = File.read(File.join(ArtifactRecovery::CORPUS, "#{case_id}.mmd"))
    if record["evidence"] == "indented frontmatter closer"
      stats[:frontmatter_kept] += 1
      next
    end

    candidate = ArtifactRecovery.candidate_for(meta, damaged)
    if candidate.nil?
      stats[:unresolved] += 1
      unresolved << case_id
      next
    end
    stats[:resolved] += 1
    next unless options[:write]

    unless ArtifactRecovery.renders?(candidate)
      stats[:recovered_but_refused] += 1
      next
    end

    renames << ArtifactRecovery.write_recovery(case_id, meta, candidate)
  end

  puts stats.inspect
  renames.first(5).each { |rename| puts "  #{rename}" }
  puts "  ... #{renames.size} renames" if renames.size > 5
  unresolved.first(10).each { |case_id| puts "  unresolved: #{case_id}" }
end
