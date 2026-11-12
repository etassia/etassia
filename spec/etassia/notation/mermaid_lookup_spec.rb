# frozen_string_literal: true

require "spec_helper"

# Parser.for, Layout.for and Renderer.for: three cases each, and every layer
# raises its own error class when a known type's class does not resolve.
RSpec.describe Etassia::Notation::Mermaid do
  let(:types_with_misnamed_pie) do
    types = Etassia::Notation::Mermaid::TYPES
    types.merge(pie: types.fetch(:pie).merge(name: "NoSuchClass"))
  end

  {
    Etassia::Parser => [Etassia::Parser::Pie, Etassia::Parser::ParseError],
    Etassia::Layout => [Etassia::Layout::Pie, Etassia::Layout::LayoutError],
    Etassia::Renderer => [Etassia::Renderer::Pie, Etassia::Renderer::RenderError],
  }.each do |layer, (pie_class, layer_error)|
    describe "#{layer}.for" do
      it "raises DiagramTypeError for a type not in TYPES" do
        expect { layer.for(:no_such_type) }
          .to raise_error(Etassia::Engine::DiagramTypeError)
      end

      it "returns an instance of the convention-resolved class" do
        expect(layer.for(:pie).class).to be(pie_class)
      end

      it "returns a different object on every call" do
        expect(layer.for(:pie).object_id).not_to eq(layer.for(:pie).object_id)
      end

      it "raises #{layer_error} for a known type whose class is missing" do
        stub_const("Etassia::Notation::Mermaid::TYPES", types_with_misnamed_pie)

        expect { layer.for(:pie) }.to raise_error(layer_error, /NoSuchClass/)
      end
    end
  end

  it "gives the renderer the theme" do
    theme = Etassia::Theme::Registry.get(:dark)

    expect(Etassia::Renderer.for(:pie, theme: theme).theme).to be(theme)
  end

  it "resolves :xychart to XyChart through its row's name" do
    expect(Etassia::Layout.for(:xychart)).to be_a(Etassia::Layout::XyChart)
  end

  # A misnamed layout must fail the render, not draw an unlaid-out diagram.
  # Only the layout is missing, so the parser and renderer still resolve.
  it "fails a render whose layout constant does not resolve" do
    hide_const("Etassia::Layout::Pie")

    expect { Etassia.render("pie\n\"a\": 1") }
      .to raise_error(Etassia::Layout::LayoutError, /Layout::Pie/)
  end
end
