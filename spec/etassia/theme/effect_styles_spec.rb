# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Theme::EffectStyles do
  let(:source) do
    File.expand_path("../../../lib/etassia/theme/effect_styles.rb", __dir__)
  end
  let(:styles) do
    Etassia::Theme.const_get(:EffectStyles).from_yaml("shadow_blur: 4.5")
  end

  before do
    stub_const("Etassia::Theme", Class.new)
    load source
  end

  it("loads and maps YAML after Theme exists") do
    expect(styles.shadow_blur).to eq(4.5)
  end
end
