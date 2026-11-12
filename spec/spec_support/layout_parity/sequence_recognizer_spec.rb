# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecSupport::LayoutParity::SequenceRecognizer do
  include SpecSupport::LayoutParity::FigureHelpers

  subject(:recognizer) { described_class.new }

  let(:participant_tops) do
    [
      [:"participant-top", "Alice", "Alice"],
      [:"participant-top", "Bob", "Bob"],
    ]
  end

  let(:stick_reference) do
    reference_svg("sequence/sequencediagram_spec-28d5e36c.svg")
  end
  let(:stick_etassia) do
    Etassia.render("sequenceDiagram\n  actor A\n  actor B\n")
  end

  def recognized(svg)
    extract(svg, recognizer).elements.map do |element|
      [element.kind, element.key, element.label]
    end.sort_by { |kind, key, _label| [kind, key] }
  end

  def failure_identities(reference, etassia)
    figures = [reference, etassia].map { |svg| extract(svg, recognizer) }
    match = SpecSupport::LayoutParity::ElementMatcher.match(
      reference: figures.first, etassia: figures.last,
    )
    match[:failures].map { |failure| failure.values_at(:type, :group) }
  end

  it "maps a real pair to the same semantic participants" do
    reference, etassia = sequence_sides

    expect([recognized(reference), recognized(etassia)])
      .to eq([participant_tops, participant_tops])
  end

  it "keeps participant-set differences visible" do
    reference, = sequence_sides
    alice = Etassia.render("sequenceDiagram\n  Alice->>Alice: Hi\n")

    expect(failure_identities(reference, alice))
      .to eq([[:missing, [:"participant-top", nil, "Bob"]]])
  end

  it "recognizes stick-figure participants the way it recognizes boxes" do
    expect([recognized(stick_reference), recognized(stick_etassia)]).to eq(
      [[[:"participant-top", "A", "A"], [:"participant-top", "B", "B"]],
       [[:"participant-top", "A", "A"], [:"participant-top", "B", "B"]]],
    )
  end
end
