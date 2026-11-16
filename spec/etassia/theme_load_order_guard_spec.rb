# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Theme do
  describe "its files' load-order guard" do
    # Every theme file refuses to load without the enclosing Etassia::Theme
    # (the `raise NameError ... unless defined?` guard). The suite always
    # has the namespace defined, so the raise arm is otherwise unreachable;
    # these examples load each file with it hidden.
    sources = %w[color_palette typography spacing_config
                 shape_styles].map do |name|
      [name,
       File.expand_path("../../lib/etassia/theme/#{name}.rb", __dir__)]
    end

    sources.each do |name, path|
      it "refuses to load #{name}.rb without Etassia::Theme" do
        hide_const("Etassia::Theme")

        expect { load path }
          .to raise_error(NameError, /uninitialized constant Etassia::Theme/)
      end
    end
  end
end
