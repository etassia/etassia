# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml/sequence"
require "open3"
require "rbconfig"

RSpec.describe Etassia::Notation::PlantUML::Sequence::Renderer do
  let(:lib) { File.expand_path("../../../../../lib", __dir__) }
  let(:source) { "@startuml\nA -> B : hi\nnote right : a note\n@enduml\n" }
  let(:script) do
    'require "etassia"; require "etassia/notation/plantuml"; ' \
      "print Etassia::Engine.new(notation: :plantuml).render(ARGV[0])"
  end
  let(:render_cold) do
    -> { Open3.capture2(RbConfig.ruby, "-I", lib, "-e", script, source).first }
  end

  it "gives a note the same id in two separate Ruby processes" do
    first = render_cold.call

    expect(render_cold.call).to eq(first)
  end
end
