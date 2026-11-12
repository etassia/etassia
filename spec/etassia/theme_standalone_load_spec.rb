# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Theme do
  %w[color_palette effect_styles shape_styles spacing_config
     typography].each do |name|
    it "refuses to load theme/#{name} without Etassia::Theme defined" do
      hide_const("Etassia::Theme")
      path = File.expand_path("../../lib/etassia/theme/#{name}.rb", __dir__)

      expect { load path }.to raise_error(NameError, /Etassia::Theme/)
    end
  end
end
