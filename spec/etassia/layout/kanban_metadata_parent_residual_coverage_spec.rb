# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Layout::Kanban do
  subject(:scene) { described_class.new.call(board) }

  let(:board) do
    Etassia::Diagram::Kanban.new.tap { |diagram| diagram.add_column(column) }
  end

  let(:column) do
    Etassia::Diagram::KanbanColumn.new(id: "todo", title: "Todo").tap do |item|
      item.add_card(card("owned", assigned: "Alice"))
      item.add_card(card("plain"))
    end
  end

  def card(id, **metadata)
    Etassia::Diagram::KanbanCard.new({ id: id, text: id, **metadata })
  end

  it "keeps one card's metadata off its sibling" do
    evidence = scene.cards.to_h { |item| [item.id, item.metadata.map(&:text)] }
    expect(evidence).to eq("owned" => ["Alice"], "plain" => [])
  end
end
