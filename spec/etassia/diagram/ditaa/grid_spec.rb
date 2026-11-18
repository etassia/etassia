# frozen_string_literal: true

require "spec_helper"
require "etassia/diagram/ditaa"

# Unit pins for the ditaa grid and geometry helpers: one arm per example,
# asserted on the public pure pieces.
RSpec.describe Etassia::Diagram::Ditaa::Grid do
  def blank(width, height)
    described_class.new(Array.new(height) { " " * width })
  end

  it "reads an empty grid as zero wide" do
    expect(described_class.new([]).width).to eq(0)
  end

  it "ignores writes outside the buffer" do
    grid = blank(4, 4)
    [[-1, 0], [0, -1], [9, 0], [0, 9]].each do |col, row|
      grid.set(col, row, "x")
    end

    expect(grid.get(0, 0)).to eq(" ")
  end

  it "string_at refuses out-of-bounds reads" do
    expect(blank(4, 4).string_at(-1, 0, 2)).to be_nil
  end

  it "string_at refuses a row below the buffer" do
    expect(blank(4, 4).string_at(0, -1, 2)).to be_nil
  end

  it "string_at refuses a column past the buffer" do
    expect(blank(4, 4).string_at(4, 0, 2)).to be_nil
  end

  it "string_at refuses a row past the buffer" do
    expect(blank(4, 4).string_at(0, 4, 2)).to be_nil
  end

  it "leaves non-alphanumeric cells alone on type-on-line" do
    grid = described_class.from_lines(["-{-}-"])
    grid.replace_type_on_line

    expect(grid.get(3, 2)).to eq("{")
  end

  it "prefers + when a letter sits on both runs" do
    grid = described_class.from_lines([" | ", "-7-", " | "])
    grid.replace_type_on_line

    expect(grid.get(3, 3)).to eq("+")
  end

  it "writes - for a letter on a horizontal run only" do
    grid = described_class.from_lines(["-7-"])
    grid.replace_type_on_line

    expect(grid.get(2, 2)).to eq("-")
  end

  it "writes | for a marker on a vertical run only" do
    grid = described_class.from_lines(["|", "*", "|"])
    grid.replace_point_markers_on_line

    expect(grid.get(2, 3)).to eq("|")
  end

  it "skips unknown markup tags" do
    expect(described_class.from_lines(["{zz}"]).markup_tags).to be_empty
  end

  it "skips nil cells when copying" do
    source = described_class.from_lines(["-"])
    target = described_class.new([" ", " "])
    source.copy_cells_to(Etassia::Diagram::Ditaa::CellSet.new([[0, 9]]), target)

    expect(target.get(0, 9)).to be_nil
  end

  it "refuses to flood a cell already holding the fill" do
    grid = described_class.from_lines(["+--+"])
    grid.fill_continuous_area(0, 2, "*")

    expect(grid.fill_continuous_area(0, 2, "*").cells).to eq([])
  end

  it "refuses to flood outside the buffer" do
    grid = described_class.from_lines(["+--+"])

    expect(grid.fill_continuous_area(0, 9, "*").cells).to eq([])
  end

  it "skips nil chars inside a string run" do
    runs = described_class.new(["  ab"]).strings

    expect(runs.map(&:last)).to eq(["ab"])
  end

  it "follows a cross-on-line junction both ways" do
    grid = described_class.from_lines(["-+-"])

    expect(grid.follow_cell(3, 2).cells.sort).to eq([[2, 2], [4, 2]])
  end

  it "blocks a cross-on-line follow direction" do
    grid = described_class.from_lines(["-+-"])

    expect(grid.follow_cell(3, 2, [4, 2]).include?([4, 2])).to be(false)
  end

  it "follows a T junction out of its three arms" do
    grid = described_class.from_lines(["-+-", " |"])

    expect(grid.follow_cell(3, 2).cells.sort).to eq([[2, 2], [3, 3], [4, 2]])
  end

  it "treats a marker cell as untraceable" do
    grid = described_class.from_lines(["-*-"])

    expect(grid.follow_cell(3, 3)).to be_nil
  end

  it "follows a vertical cross-on-line junction" do
    grid = described_class.from_lines([" | ", " + ", " | "])

    expect(grid.follow_cell(3, 3).cells.sort).to eq([[3, 2], [3, 4]])
  end

  it "writes | for a marker with only vertical runs beside it" do
    marked = described_class.from_lines([" * ", " | ", " * "])
    marked.replace_point_markers_on_line

    expect(marked.get(3, 3)).to eq("|")
  end

  it "skips the bullet write when the run marker has no colour" do
    grid = described_class.from_lines(["- ab  "])
    runs = grid.strings

    expect(runs.map(&:last)).to eq(["- ab"])
  end

  it "blocks a follow direction at an intersection" do
    grid = described_class.from_lines(["-+-", " |"])

    expect(grid.follow_cell(3, 2, [3, 3]).cells.sort)
      .to eq([[2, 2], [4, 2]])
  end

  def grid(*lines)
    described_class.from_lines(lines)
  end

  it "writes | for a letter on a vertical run only" do
    marked = grid("|", "7", "|")
    marked.replace_type_on_line

    expect(marked.get(2, 3)).to eq("|")
  end

  it "writes | for a marker on a vertical run" do
    marked = grid("|", "*", "|")
    marked.replace_point_markers_on_line

    expect(marked.get(2, 3)).to eq("|")
  end

  it "refuses a nil cell as a boundary" do
    expect(grid("-").boundary?(9, 9)).to be(false)
  end

  it "skips strings that are not colour codes" do
    expect(grid("cxx0").color_codes).to be_empty
  end

  it "refuses boundary expansion from a nil cell" do
    expect(grid("x").boundaries_expanding_from(9, 9)).to be_empty
  end

  it "skips nil characters inside a string run" do
    expect(grid("ab").strings.map(&:last)).to eq(["ab"])
  end

  it "follows a corner4 junction" do
    expect(grid(" |", " +-+").follow_cell(3, 3).cells.sort)
      .to eq([[3, 2], [4, 3]])
  end
end
