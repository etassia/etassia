# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Layout::Gantt do
  subject(:scene) do
    diagram = Etassia::Parser::Gantt.new.parse(source)
    described_class.new.call(diagram, today: Date.new(2026, 10, 11))
  end

  # The fixture's JS-template damage (${expectedTitle} and friends) sits in
  # its accessibility lines and does not touch the task; the date lines
  # survived the corpus unescape, so the layout reads the real 30-day span.
  let(:source) do
    File.read(
      File.join(__dir__, "../../mermaid/gantt/" \
                         "should_handle_a_dateformat_definition-16cdb290.mmd"),
    )
  end

  it "reads the task's 30-day span" do
    task = scene.sections.first.tasks.first

    expect([task.start_date, task.end_date])
      .to eq([Date.new(2014, 1, 1), Date.new(2014, 1, 31)])
  end

  it "ticks the axis every two days across the span" do
    expect(scene.timeline.labels.map(&:text).first(3))
      .to eq(["2014-01-01", "2014-01-03", "2014-01-05"])
  end

  it "ends the axis at the task's last day" do
    expect(scene.timeline.labels.map(&:text).last).to eq("2014-01-31")
  end
end
