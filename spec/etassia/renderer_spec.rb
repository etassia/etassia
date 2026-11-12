# frozen_string_literal: true

require "spec_helper"

RSpec.describe Etassia::Renderer do
  {
    Etassia::Renderer::Gantt => Etassia::Layout::Gantt::Scene,
    Etassia::Renderer::XyChart => Etassia::Layout::XyChart::Scene,
    Etassia::Renderer::Timeline => Etassia::Layout::Timeline::Scene,
  }.each do |renderer_class, scene_class|
    it "makes #{renderer_class} reject non-#{scene_class} input" do
      message = "expected #{scene_class}, got Hash"

      expect { renderer_class.new.render({}) }
        .to raise_error(Etassia::Renderer::RenderError, message)
    end
  end
end
