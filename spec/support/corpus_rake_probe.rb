# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"

# Asks tasks/corpus.rake for its answers in a child process.
# corpus_tasks_spec.rb
# loads that file into the suite unconditionally, so a second in-process load
# would redefine its constants and append every rake action twice.
module CorpusRakeProbe
  PROBE = <<~RUBY
    require "json"
    require "rake"
    require "etassia"
    load "tasks/corpus.rake"
    answers = [Etassia::Corpus.types,
               Etassia::Corpus.registry_type("gitgraph"),
               Etassia::Corpus.registry_type("unknown")]
    Etassia::CorpusTypeNames.send(:remove_const, :DIRECTORIES)
    Etassia::CorpusTypeNames.const_set(:DIRECTORIES, { "gitgraph" => :pie })
    puts JSON.dump(answers << Etassia::Corpus.registry_type("gitgraph"))
  RUBY

  def corpus_rake_answers
    out, err, status = Open3.capture3(RbConfig.ruby, "-Ilib", "-e", PROBE)
    raise "corpus.rake probe failed: #{err}" unless status.success?

    JSON.parse(out)
  end
end
