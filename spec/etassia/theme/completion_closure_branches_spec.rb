# frozen_string_literal: true

require "spec_helper"
require "etassia/theme/completion"

RSpec.describe Etassia::Theme::Completion do
  let(:default) { Etassia::Theme::Registry.get(:default) }
  let(:theme) do
    Etassia::Theme.new(
      name: "mine", colors: { radar_palette: [], background: "" },
    )
  end

  it "treats an empty palette as unset and fills it from the default" do
    completed = described_class.call(theme)

    expect(completed.colors.radar_palette)
      .to eq(default.colors.radar_palette)
  end

  it "treats an empty single colour as unset" do
    expect(described_class.call(theme).colors.background).to be_nil
  end
end
