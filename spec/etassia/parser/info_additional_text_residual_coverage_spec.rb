# frozen_string_literal: true

require "spec_helper"
require "etassia/parser/info"

RSpec.describe Etassia::Parser::Info do
  it "refuses additional header text, as Mermaid's lexer does" do
    expect { described_class.new.parse("info ignored words") }
      .to raise_error(Etassia::Parser::ParseError)
  end
end
