# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecSupport::LayoutParity::RadarGraticuleGeometry do
  let(:source_name) { "radar_spec-9dd39c75" }

  def reference_svg
    File.read("spec/fixtures_mermaid/radar/#{source_name}.svg")
  end

  def etassia_svg
    source = File.read("spec/mermaid/radar/#{source_name}.mmd")
    Etassia.render(source)
  end

  def circle_svg(attributes, reference:)
    marker = reference ? 'class="radarGraticule"' : 'fill="none"'
    "<svg><circle #{marker} #{attributes}/></svg>"
  end

  def real_pair_actual
    comparisons = described_class.compare(reference: reference_svg,
                                          etassia: etassia_svg)
    [described_class.extract(reference_svg),
     described_class.extract(etassia_svg), comparisons.map(&:error)]
  end

  def real_pair_expected
    [[60.0, 120.0, 180.0, 240.0, 300.0],
     [60.0, 120.0, 180.0, 240.0, 300.0],
     Array.new(5) { be_within(0.000_001).of(0.0) }]
  end

  def transformed_svg
    <<~SVG
      <svg><g transform="translate(30 40)"><g transform="rotate(90) scale(2)">
        <circle class="radarGraticule" cx="5" cy="7" r="10"/>
      </g></g></svg>
    SVG
  end

  def zero_reference_errors
    zero = circle_svg('r="0"', reference: true)
    candidates = [circle_svg('r="0"', reference: false),
                  circle_svg('r="5"', reference: false)]
    candidates.map do |candidate|
      described_class.compare(reference: zero, etassia: candidate).first.error
    end
  end

  def mismatched_graticules
    <<~SVG
      <svg>
        <circle class="radarGraticule" r="10"/>
        <circle class="radarGraticule" r="20"/>
      </svg>
    SVG
  end

  def mismatch_action
    etassia = circle_svg('r="10"', reference: false)
    lambda do
      described_class.compare(reference: mismatched_graticules,
                              etassia: etassia)
    end
  end

  it "pairs a real reference and Etassia graticules by radius order" do
    expect(real_pair_actual).to match(real_pair_expected)
  end

  it "composes ancestor translation, rotation, and scale" do
    expect(described_class.extract(transformed_svg)).to contain_exactly(20.0)
  end

  it "defines zero-reference analog errors" do
    expect(zero_reference_errors).to eq([0.0, Float::INFINITY])
  end

  it "refuses to drop an unmatched graticule" do
    expect(&mismatch_action).to raise_error(ArgumentError,
                                            "graticule counts differ")
  end
end
