# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Notation::Mermaid do
  let(:layer) { stub_const("MissingMermaidLayer", Module.new) }
  let(:message) do
    "No MissingMermaidLayer::Pie class for diagram type: pie"
  end

  it "raises the requested layer error when the type's class is absent" do
    expect do
      described_class.layer_class(layer, :pie, Etassia::Layout::LayoutError)
    end.to raise_error(Etassia::Layout::LayoutError, message)
  end
end
