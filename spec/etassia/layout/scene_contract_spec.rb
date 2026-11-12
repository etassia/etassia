# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Layout::Scene do
  let(:fixture_dir) { File.expand_path("../../fixtures/contract", __dir__) }

  def scene_for(type)
    source = File.read(File.join(fixture_dir, "#{type}.mmd"))
    diagram = Etassia::Parser.for(type).parse(source)
    Etassia::Layout.for(type).call(diagram)
  end

  Etassia::Notation::Mermaid::TYPES.each_key do |type|
    it "builds a bounded Scene for #{type}" do
      expect(scene_for(type)).to be_a(described_class)
        .and have_attributes(
          width: be_between(Float::MIN, Float::MAX),
          height: be_between(Float::MIN, Float::MAX),
        )
    end
  end
end
