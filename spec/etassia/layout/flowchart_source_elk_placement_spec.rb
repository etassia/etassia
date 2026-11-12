# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Layout::Flowchart do
  let(:body) do
    <<~MERMAID
      a[hello] --> b[world]
      b --> c{test}
      c --> one
      c --> two
      c --> three
    MERMAID
  end

  def observe_directed_calls
    calls = 0
    allow(Etassia::Layout::Flowchart::DirectedPlacement).to receive(:apply)
      .and_wrap_original do |original, *arguments, **keywords|
        calls += 1
        original.call(*arguments, **keywords)
      end
    -> { calls }
  end

  def observe_elk_spacing
    spacing = nil
    allow(Etassia::Layout::ElkPlacement).to receive(:apply)
      .and_wrap_original do |original, graph|
        options = graph.fetch(:layoutOptions)
        spacing = [options.fetch(Etassia::Layout::Base::ElkOptions::NODE_NODE_SPACING),
                   options.fetch(Etassia::Layout::Base::ElkOptions::LAYER_SPACING)]
        original.call(graph)
      end
    -> { spacing }
  end

  it "uses direct 35px ELK placement for the flowchart-elk header" do
    directed_calls = observe_directed_calls
    spacing = observe_elk_spacing
    Etassia.render("flowchart-elk\n#{body}")
    expect([directed_calls.call, spacing.call]).to eq([0, [35, 35]])
  end

  it "keeps ordinary flowcharts on dagre-compatible placement" do
    expect(directed_placement_calls("flowchart TD\n#{body}")).to eq(1)
  end

  it "keeps an explicit caller engine ahead of the source header" do
    calls = directed_placement_calls(
      "flowchart-elk\n#{body}", layout_engine: :elk
    )

    expect(calls).to eq(1)
  end

  def directed_placement_calls(source, **options)
    calls = observe_directed_calls
    Etassia.render(source, **options)
    calls.call
  end
end
