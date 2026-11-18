# frozen_string_literal: true

require "spec_helper"
require "etassia/diagram/ditaa"

# Cell-set algebra pins: classification, fills, scaling and the mixed
# boundary's leg tracing.
RSpec.describe Etassia::Diagram::Ditaa::CellSet do
  let(:box_grid) do
    Etassia::Diagram::Ditaa::Grid.from_lines(["+---+", "|   |", "+---+"])
  end

  it "classifies a singleton as open" do
    set = described_class.new([[2, 2]])

    expect(set.type(box_grid)).to eq(described_class::TYPE_OPEN)
  end

  it "classifies a two-cell set by trace" do
    set = described_class.new([[2, 2], [3, 2]])

    expect(set.type(box_grid)).to eq(described_class::TYPE_OPEN)
  end

  it "classifies an empty set as open" do
    expect(described_class.new.type(box_grid))
      .to eq(described_class::TYPE_OPEN)
  end

  it "keeps an open set when its fill equivalent hits the edge" do
    set = described_class.new([[2, 2], [3, 2]])

    expect(set.filled_equivalent(box_grid).size).to eq(2)
  end

  it "stops a leg at a line end and records it" do
    set = described_class.new([[2, 2], [3, 2]])
    parts = set.break_truly_mixed(box_grid)

    expect(parts.first.size).to eq(2)
  end

  it "stamps a star-on-line cell with the full footprint" do
    star = Etassia::Diagram::Ditaa::Grid.from_lines(["-*-", " | ", " * "])
    cells = star.all_boundaries
    buffer = Etassia::Diagram::Ditaa::AbstractCell.stamp_buffer(star, cells)

    expect(buffer.all_non_blank.size).to be_positive
  end

  it "skips blank cells when stamping" do
    star = Etassia::Diagram::Ditaa::Grid.from_lines(["-*-"])
    buffer = Etassia::Diagram::Ditaa::AbstractCell.stamp_buffer(
      star, described_class.new([[0, 0]])
    )

    expect(buffer.all_non_blank).to be_empty
  end

  it "records a leg end reached by tracing" do
    grid = Etassia::Diagram::Ditaa::Grid.from_lines(["-----", "     ", "     "])
    set = described_class.new([[2, 2], [3, 2], [4, 2]])

    expect(set.break_truly_mixed(grid).first.size).to eq(3)
  end

  it "classifies a marker-start set as open" do
    star_grid = Etassia::Diagram::Ditaa::Grid.from_lines(["* *"])
    set = described_class.new([[2, 2], [4, 2]])

    expect(set.type(star_grid)).to eq(described_class::TYPE_OPEN)
  end

  it "resolves an undetermined junction to open by fill" do
    cross = Etassia::Diagram::Ditaa::Grid.from_lines([" | ", "-+-", " | "])
    set = described_class.new(
      [[3, 2], [3, 3], [3, 4], [2, 3], [4, 3]],
    )

    expect(set.type(cross)).to eq(described_class::TYPE_OPEN)
  end
end
