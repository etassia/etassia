# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml/sequence/arrow_syntax"

RSpec.describe Etassia::Notation::PlantUML::Sequence::ArrowSyntax do
  it("rejects a bare shaft") { expect(described_class.read("-")).to be_nil }
end
