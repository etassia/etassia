# frozen_string_literal: true

require "spec_helper"

# lib/etassia.rb used to carry a second `def self.render` written after
# `module Etassia`'s closing `end` -- syntactically outside the module, so
# it defined a singleton method on the real top-level `main` object shared
# by the whole process instead of on `Etassia`. It shadowed nothing (nobody
# calls bare `render` at the top level) and raised `NameError: uninitialized
# constant Engine` if anyone ever did, because `Engine` unqualified does not
# resolve to `Etassia::Engine` outside the module.
RSpec.describe Etassia do
  it "does not leak a render method onto the top-level main object" do
    expect(TOPLEVEL_BINDING.receiver.respond_to?(:render, true)).to be false
  end

  context "when loading the version file" do
    let(:source) { File.expand_path("../lib/etassia/version.rb", __dir__) }

    before do
      stub_const("Etassia", Module.new)
      load source
    end

    it "exposes its loaded version" do
      expect(Object.const_get(:Etassia).const_get(:VERSION)).to eq("0.1.0")
    end
  end
end
