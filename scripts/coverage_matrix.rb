# frozen_string_literal: true

require "json"
require "fileutils"

# Builds the coverage matrix issue #430 asks for: every diagram type of
# both families against its reference-corpus status, written to
# scoreboard/coverage.json and docs/COVERAGE.md.
#
# The matrix is DERIVED, never hand-edited: Mermaid rows come from the
# notation's live type table and scoreboard/corpus.json; PlantUML rows
# from the notation's type table and scoreboard/plantuml.json; the gap
# rows list the reference tools' types elkrb does not carry yet (the
# plantuml.jar diagram kinds and the mermaid-cli set beyond the
# notation's table).
module CoverageMatrix
  ROOT = File.expand_path("..", __dir__)
  MERMAID_CORPUS = File.join(ROOT, "scoreboard/corpus.json")
  MERMAID_VERDICTS = File.join(ROOT, "spec/mermaid/corpus-verdicts.yml")
  PLANTUML_SCOREBOARD = File.join(ROOT, "scoreboard/plantuml.json")
  MATRIX_JSON = File.join(ROOT, "scoreboard/coverage.json")
  MATRIX_MD = File.join(ROOT, "docs/COVERAGE.md")

  # Verdicts that mark a case un-scoreable: the pinned oracle rejects the
  # source, or the source is known extraction damage (an uninterpolated
  # template, a truncation). Neither can be held against the renderer.
  UNSCOREABLE_VERDICTS = %w[invalid artifact].freeze

  # The reference tools' diagram kinds beyond what the notations carry.
  # Updating these lists is a deliberate act: each addition is a row
  # somebody promises to port or explicitly declines.
  PLANTUML_JAR_UNCARRIED = %w[
    archimate bpmn deployment json salt wbs yaml
  ].freeze
  MERMAID_CLI_UNCARRIED = %w[
    flowchart-elk
  ].freeze

  module_function

  def build
    { "mermaid" => mermaid_rows, "plantuml" => plantuml_rows,
      "reference-gaps" => gap_rows }
  end

  def write!
    matrix = build
    FileUtils.mkdir_p(File.dirname(MATRIX_JSON))
    File.write(MATRIX_JSON, "#{JSON.pretty_generate(matrix)}\n")
    File.write(MATRIX_MD, markdown(matrix))
    [MATRIX_JSON, MATRIX_MD]
  end

  def mermaid_rows
    require "etassia"
    by_type = accumulate_corpus
    Etassia::Notation::Mermaid::TYPES.map do |key, row|
      mermaid_row(key, row[:keyword], by_type[key.to_s])
    end
  end

  def accumulate_corpus
    empty = Hash.new do |h, k|
      h[k] = { cases: 0, scoreable: 0, scoreable_passing: 0 }
    end
    corpus_rows.each_with_object(empty) do |row, by_type|
      count_into(by_type, row)
    end
  end

  def count_into(by_type, row)
    stats = stats_for(by_type, row)
    return unless stats

    stats[:cases] += 1
    return if unscoreable?(row["case"])

    stats[:scoreable] += 1
    stats[:scoreable_passing] += 1 if row["pass"]
  end

  def stats_for(by_type, row)
    require "etassia"
    directory = row["case"].to_s.split("/").first
    family = Etassia::CorpusTypeNames.registry_type(directory)
    family && by_type[family.to_s]
  end

  def unscoreable?(case_path)
    UNSCOREABLE_VERDICTS.include?(verdicts[case_path])
  end

  def verdicts
    require "yaml"
    @verdicts ||=
      YAML.load_file(MERMAID_VERDICTS).to_h { |v| [v["case"], v["verdict"]] }
  end

  def mermaid_row(key, keyword, stats)
    damaged = stats[:cases] - stats[:scoreable]
    {
      "type" => key.to_s,
      "keyword" => keyword,
      "carried" => true,
      "corpus_cases" => stats[:cases],
      "scoreable_cases" => stats[:scoreable],
      "corpus_passing" => stats[:scoreable_passing],
      "status" => mermaid_status(stats, damaged),
    }
  end

  def mermaid_status(stats, damaged)
    return "no corpus cases" if stats[:cases].zero?
    if stats[:scoreable].zero?
      return "all #{stats[:cases]} cases damaged or rejected"
    end

    base = format("%<p>d/%<s>d scoreable passing",
                  p: stats[:scoreable_passing], s: stats[:scoreable])
    damaged.positive? ? "#{base}; #{damaged} damaged or rejected" : base
  end

  def corpus_rows
    return [] unless File.exist?(MERMAID_CORPUS)

    JSON.parse(File.read(MERMAID_CORPUS))
  end

  def plantuml_rows
    require "etassia"
    # the PlantUML family loads behind its opt-in require
    require "etassia/notation/plantuml"
    by_type = scoreboard_rows.to_h { |r| [r["type"], r] }
    Etassia::Notation::PlantUML.types.map { |key| plantuml_row(key, by_type) }
  end

  def plantuml_row(key, by_type)
    plain = key.to_s.gsub("_diagram", "")
    scoreboard = by_type[plain] || by_type[plain.tr("_", "-")]
    return declared_row(key) unless scoreboard

    {
      "type" => key.to_s, "carried" => true,
      "corpus_cases" => scoreboard["cases"],
      "oracle_valid" => scoreboard["oracle_valid"],
      "corpus_passing" => scoreboard["passing"],
      "status" => scoreboard["status"]
    }
  end

  def declared_row(key)
    { "type" => key.to_s, "carried" => true, "corpus_cases" => 0,
      "status" => "declared; no corpus yet" }
  end

  def scoreboard_rows
    return [] unless File.exist?(PLANTUML_SCOREBOARD)

    JSON.parse(File.read(PLANTUML_SCOREBOARD))
  end

  def gap_rows
    {
      "plantuml-jar" => PLANTUML_JAR_UNCARRIED.map do |t|
        { "type" => t, "carried" => false }
      end,
      "mermaid-cli" => MERMAID_CLI_UNCARRIED.map do |t|
        { "type" => t, "carried" => false }
      end,
    }
  end

  def markdown(matrix)
    table_rows(matrix) + gap_lines(matrix)
  end

  def table_rows(matrix)
    lines = header_lines(matrix)
    matrix["mermaid"].each do |row|
      lines << mermaid_line(row)
    end
    lines.concat(plantuml_header)
    matrix["plantuml"].each do |row|
      lines << plantuml_line(row)
    end
    lines
  end

  def mermaid_line(row)
    cells = [row["type"], escape(row["keyword"]), row["corpus_cases"],
             row["scoreable_cases"], row["corpus_passing"], row["status"]]
    "| #{cells.join(' | ')} |"
  end

  def plantuml_line(row)
    cells = [row["type"], row["corpus_cases"], row["oracle_valid"] || "-",
             row["corpus_passing"] || "-", row["status"]]
    "| #{cells.join(' | ')} |"
  end

  def header_lines(matrix)
    [
      "# Coverage matrix",
      "",
      "Every diagram type of both families against its reference-corpus",
      "status (issue #430). DERIVED by `rake notations:coverage` — never",
      "hand-edited; the source of truth is the live notations plus the",
      "scoreboards.",
      "",
      "## Mermaid (#{matrix['mermaid'].size} carried)",
      "",
      "| Type | Keyword | Corpus | Scoreable | Passing | Status |",
      "|---|---|---|---|---|---|",
    ]
  end

  def plantuml_header
    [
      "",
      "## PlantUML",
      "",
      "| Type | Corpus | Oracle-valid | Passing | Status |",
      "|---|---|---|---|---|",
    ]
  end

  def gap_lines(matrix)
    jar = matrix["reference-gaps"]["plantuml-jar"].map do |r|
      r["type"]
    end.join(", ")
    cli = matrix["reference-gaps"]["mermaid-cli"].map do |r|
      r["type"]
    end.join(", ")
    [
      "",
      "## Reference gaps (not carried)",
      "",
      "### plantuml.jar kinds",
      "",
      jar,
      "",
      "### mermaid-cli kinds",
      "",
      cli,
      "",
    ]
  end

  def escape(text)
    text.to_s.gsub("|", '\|')
  end
end
