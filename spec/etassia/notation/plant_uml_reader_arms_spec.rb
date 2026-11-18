# frozen_string_literal: true

require "spec_helper"
require "etassia/notation/plantuml"

# Unit pins for the constructs the corpus growth made readable: each arm the
# parity wave added to a reader, asserted on the model it builds.
RSpec.describe Etassia::Notation::PlantUML do
  def wrap(*lines)
    "@startuml\n#{lines.join("\n")}\n@enduml\n"
  end

  def gantt(*lines)
    "@startgantt\n#{lines.join("\n")}\n@endgantt\n"
  end

  def timing(*lines)
    "@starttiming\n#{lines.join("\n")}\n@endtiming\n"
  end

  def gantt_parse(*lines)
    Etassia::Notation::PlantUML::Gantt::Reader.new.parse(gantt(*lines)).first
  end

  def task_of(model, name)
    model.sections.flat_map(&:tasks)
      .find { |candidate| candidate.description == name }
  end

  def dates_of(model)
    model.sections.flat_map(&:tasks)
      .to_h { |candidate| [candidate.description, candidate.start_date] }
  end

  def state_model(*lines)
    Etassia::Notation::PlantUML::State::Reader.new.parse(wrap(*lines))
  end

  def timing_parse(*lines)
    Etassia::Notation::PlantUML::Timing::Reader.new.parse(timing(*lines))
  end

  def activity_model(*lines)
    Etassia::Notation::PlantUML::Activity::Parser.new.parse(wrap(*lines))
  end

  def class_model(*lines)
    Etassia::Notation::PlantUML::Parser.new.parse(wrap(*lines))
  end

  describe "state reader" do
    it "reads a spot style after the name" do
      expect(state_model("state Faulted $fault", "state Idle")
        .states.map(&:id)).to eq(%w[Faulted Idle])
    end

    it "reads a quoted name without an alias" do
      expect(state_model('state "count_val[3:0]"').states.first.label)
        .to eq("count_val[3:0]")
    end

    it "attaches a named note to the last declared state" do
      model = state_model("state module {", "}", "note as PARAMETERS",
                          "localparam MAX_VAL 10", "end note")

      expect(model.notes.first.target_id).to eq("module")
    end

    it "keeps the named note's text" do
      model = state_model("state module {", "}", "note as PARAMETERS",
                          "localparam MAX_VAL 10", "end note")

      expect(model.notes.first.text).to include("MAX_VAL")
    end

    it "refuses a named note before any state exists" do
      expect { state_model("note as PARAMETERS", "end note") }
        .to raise_error(Etassia::Notation::PlantUML::UnsupportedConstructError,
                        /note as/)
    end

    it "steps over remove, restore and pragma lines" do
      expect(state_model("!pragma layout smetana", "state A",
                         "remove $x", "restore $y").states.map(&:id))
        .to eq(["A"])
    end
  end

  describe "gantt reader" do
    it "reads an English project date" do
      model = gantt_parse("Project starts the 20th of september 2018",
                          "[A] lasts 2 days")

      expect(task_of(model, "A").start_date).to eq("2018-09-20")
    end

    it "reads an English date in happens" do
      model = gantt_parse("Project starts 2024-01-01",
                          "[A] happens at the 5th of February 2024")

      expect(task_of(model, "A").start_date).to eq("2024-02-05")
    end

    it "reads a datetime start" do
      model = gantt_parse("Project starts 2024-09-22",
                          "[A] starts 2024-09-22 10:30:46")

      expect(task_of(model, "A").start_date).to eq("2024-09-22")
    end

    it "creates a task from a bare time clause" do
      model = gantt_parse("Project starts 2024-09-22", "[B] T10:30:46")

      expect(task_of(model, "B")).not_to be_nil
    end

    it "steps over colored and named calendar lines" do
      source = "Project starts 2024-01-01\n" \
               "2024/02/01 to 2024/02/10 are colored in red\n" \
               "2024-02-05 to 2024-02-09 are named [Closed]\n" \
               "then 10 days are colored in lightgreen\n[A] lasts 2 days"

      expect(task_of(gantt_parse(source), "A")).not_to be_nil
    end

    def working_hours_source
      "Project starts 2024-01-01\n" \
        "From 8:00 to 12:00 are working hours\n" \
        "projectscale weekly\n" \
        "labels on first column and left aligned\n" \
        "!$PRIMARY_LIGHT = \"#33b2e2\"\n[A] lasts 2 days"
    end

    it "steps over working hours, projectscale, labels and variables" do
      expect(task_of(gantt_parse(working_hours_source), "A")).not_to be_nil
    end

    it "steps over style and note blocks" do
      model = gantt_parse("Project starts 2024-01-01",
                          "<style>", "ganttDiagram {", "}", "</style>",
                          "note bottom", "long note", "end note",
                          "[A] lasts 2 days")

      expect(task_of(model, "A")).not_to be_nil
    end

    it "spans a task between two point tasks with occurs" do
      model = gantt_parse("project starts on 2020-07-01",
                          "[P_start] happens 2020-07-03",
                          "[P_end] happens 2020-07-13",
                          "[Design] occurs from [P_start] to [P_end]")

      expect(task_of(model, "Design").start_date).to eq("2020-07-03")
    end

    it "gives the occurs span the points' distance" do
      model = gantt_parse("project starts on 2020-07-01",
                          "[P_start] happens 2020-07-03",
                          "[P_end] happens 2020-07-13",
                          "[Design] occurs from [P_start] to [P_end]")

      expect(task_of(model, "Design").duration).to eq("10/1d")
    end

    it "places a milestone at another task's end" do
      model = gantt_parse("Project starts 2024-01-01", "[A] lasts 5 days",
                          "[B] happens at [A]'s end")

      expect(dates_of(model)["B"]).to eq("2024-01-06")
    end

    it "places a milestone an offset after another task's end" do
      model = gantt_parse("Project starts 2024-01-01", "[A] lasts 5 days",
                          "[C] happens 3 days after [A]'s end")

      expect(dates_of(model)["C"]).to eq("2024-01-09")
    end

    it "places a milestone an offset after the project start" do
      model = gantt_parse("Project starts 2024-01-01",
                          "[D] happens 2 days after start")

      expect(dates_of(model)["D"]).to eq("2024-01-03")
    end

    it "follows another task's start" do
      model = gantt_parse("Project starts 2024-01-01",
                          "[A] lasts 4 days",
                          "[B] starts at [A]'s start and lasts 2 days")

      expect(task_of(model, "B").after_task).to include(task_of(model, "A").id)
    end

    it "reads a milestone at N days after start" do
      model = gantt_parse("Project starts 2024-01-01",
                          "[End] happens 150 days after start")

      expect(task_of(model, "End").start_date).to eq("2024-05-30")
    end

    it "leaves a task at its default when occurs points have no date" do
      model = gantt_parse("Project starts 2024-01-01",
                          "[A] occurs from [X] to [Y]")

      expect(task_of(model, "A")).not_to be_nil
    end

    it "ignores the on-clause" do
      model = gantt_parse("[T1] on {def:50%} lasts 5 days")

      expect(task_of(model, "T1").duration).to eq("5d")
    end

    it "ignores the same-row display clause" do
      model = gantt_parse("[T1] lasts 1 day",
                          "[M1] displays on same row as [T1]")

      expect(task_of(model, "M1")).not_to be_nil
    end
  end

  describe "timing reader" do
    it "reads decimal clock periods and offsets" do
      model = timing_parse(
        'clock "MyClock" as Clk with period 12.5 offset 0.1',
      )

      expect(model.participants["Clk"].period).to eq(12.5)
    end

    it "reads the decimal offset" do
      model = timing_parse(
        'clock "MyClock" as Clk with period 12.5 offset 0.1',
      )

      expect(model.participants["Clk"].offset).to eq(0.1)
    end

    it "reads an arrival with a plus offset" do
      model = timing_parse("robust \"DNS\" as DNS",
                           "concise \"WB\" as WB",
                           "@0", "WB is idle",
                           "WB -> DNS@+50 : Resolve URL")

      expect(model.messages.last.arrives).to eq(50.0)
    end

    it "anchors time at a participant's last change" do
      model = timing_parse("robust \"DNS\" as DNS",
                           "@10", "DNS is up",
                           "@DNS")

      expect(model.changes.last.time).to eq(10.0)
    end

    it "refuses an unknown participant anchor" do
      expect { timing_parse("@WU") }
        .to raise_error(Etassia::Notation::PlantUML::UnsupportedConstructError)
    end

    it "steps over style blocks and constraint lines" do
      source = "<style>\narrow {\n}\n</style>\n" \
               "robust \"DNS\" as DNS\n" \
               "@200 <-> @+150 : {150 ms}\n@0\nDNS is idle"

      expect(timing_parse(source).changes.last.state).to eq("idle")
    end
  end

  describe "activity reader" do
    it "reads a deprecated coloured construct" do
      model = activity_model("#red:if (c?) then (yes)", ":A;", "else (no)",
                             ":B;", "endif")

      expect(model.nodes.count { |node| node.kind == :decision }).to eq(1)
    end

    it "reads a trailing-decoration arm" do
      model = activity_model("switch (x?)", "case (a)", ":A; <<#palegreen>>",
                             "case (b)", ":B;", "endswitch")

      expect(model.nodes.count { |node| node.kind == :decision }).to eq(1)
    end

    it "reads repeat with a backward action" do
      model = activity_model("repeat :R;", ":A;", "repeat while (more?)")

      expect(model.nodes.map(&:kind)).to include(:action)
    end

    def sprite_source
      "sprite $foo <svg width=\"1\" height=\"1\"></svg>\n:see <$foo>;"
    end

    it "skips sprite definitions and sprite references" do
      model = activity_model(sprite_source)
      action = model.nodes.find { |node| node.text&.include?("see") }

      expect(action.text).not_to include("$foo")
    end

    it "reads group partitions closed by end group" do
      model = activity_model("group G", ":A;", "end group")

      expect(model.nodes).not_to be_empty
    end

    it "reads a floating note beside the last activity" do
      model = activity_model(":A;", "floating note left: This is a note")
      action = model.nodes.find { |node| node.text == "A" }

      expect(action.notes).not_to be_empty
    end

    it "steps over pragma lines" do
      model = activity_model("!pragma svgparser sax", ":A;")

      expect(model.nodes.map(&:text)).to include("A")
    end
  end

  describe "class reader" do
    it "draws a rectangle container as a frame" do
      model = class_model("rectangle foo <<foo>> <<boo>> {", "class B", "}")

      expect(model.packages.first.shape).to eq(:frame)
    end

    it "draws a quoted rectangle container by its title" do
      model = class_model('rectangle "System in focus" <<Module>> {',
                          "class B", "}")

      expect(model.packages.first.title).to eq("System in focus")
    end

    it "draws an unknown package stereotype as a folder" do
      model = class_model("package bar <<boo>> {", "class A", "}")

      expect(model.packages.first.shape).to eq(:folder)
    end

    it "steps over a root style block" do
      model = class_model("<style>", "root {", ".highlight {",
                          "BackGroundColor LightGray", "}", "}",
                          "</style>", "class A <<highlight>>")

      expect(model.classes.map(&:name)).to eq(["A"])
    end
  end
end
