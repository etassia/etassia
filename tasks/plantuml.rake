# frozen_string_literal: true

require_relative "../scripts/plantuml_scoreboard"

desc "Measure the PlantUML corpus; writes scoreboard/plantuml.json"
task :plantuml do
  require "etassia"
  rows = PlantumlScoreboard.fresh_rows(PlantumlScoreboard.load_scoreboard)
  PlantumlScoreboard.write_scoreboard(rows)
  rows.each { |row| puts "#{row['type']}: #{row['status']}" }
end

namespace :plantuml do
  desc "Diff a fresh PlantUML measurement against scoreboard/plantuml.json"
  task :check do
    require "etassia"
    PlantumlScoreboard.check!
  end
end
