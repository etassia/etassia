# frozen_string_literal: true

require "spec_helper"
require "etassia"

RSpec.describe Etassia::Runtime do
  let(:document) do
    Etassia::Dim::Document.new(
      notation: "generic",
      graph: Etassia::Dim::Graph.new(
        id: "root",
        children: [Etassia::Dim::Node.new(
          id: "a", width: 100, height: 40,
          content: [Etassia::Dim::ContentBlock.new(text: "Person",
                                                   role: "title")]
        )],
      ),
    )
  end

  let(:dim_source) { document.to_json }

  def load_native
    require "etassia/native"
  rescue LoadError
    nil
  end

  def with_runtime(name)
    previous = ENV.fetch("ETASSIA_RUNTIME", nil)
    ENV["ETASSIA_RUNTIME"] = name
    yield
  ensure
    ENV["ETASSIA_RUNTIME"] = previous
    Etassia::Runtime.reset!
  end

  after { described_class.reset! }

  it "routes a DIM document to the native engine" do
    load_native
    skip "etassia-native is absent" unless described_class.native?

    svg = Etassia.render(dim_source)
    expect(svg).to include("Person")
  end

  it "refuses with the reason when the native gem is absent" do
    skip "the etassia-native gem is installed here" if described_class.native?

    expect { Etassia.render(dim_source) }
      .to raise_error(Etassia::Engine::PipelineError, /etassia-native/)
  end

  it "refuses the same way with the runtime forced to rust" do
    skip "the etassia-native gem is installed here" if described_class.native?

    with_runtime("rust") do
      expect { Etassia.render(dim_source) }
        .to raise_error(Etassia::Engine::PipelineError, /etassia-native/)
    end
  end

  it "declines through parse when the runtime is forced to ruby" do
    with_runtime("ruby") do
      expect { Etassia.render(dim_source) }
        .to raise_error(/etassia-native/)
    end
  end

  it "surfaces a foreign DIM version from the engine" do
    load_native
    skip "etassia-native is absent" unless described_class.native?

    foreign = dim_source.sub('"dim":"0.1"', '"dim":"9.9"')
    expect { Etassia.render(foreign) }
      .to raise_error(an_object_having_attributes(error_class: "Unsupported"))
  end

  it "declines in parse with the reason" do
    expect { Etassia::Notation::Dim.parse(dim_source) }
      .to raise_error(Etassia::Engine::PipelineError, /etassia-native/)
  end

  it "validates the document before parse declines" do
    expect { Etassia::Notation::Dim.parse('{"dim": "9.9"}') }
      .to raise_error(Etassia::Dim::UnsupportedError)
  end
end
