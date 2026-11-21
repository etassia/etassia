# frozen_string_literal: true

require "spec_helper"

# user_journey retired its Ruby lane (issue #481): the native artifact lane
# is the ONLY parse path. The lane's contract: a missing or switched-off
# engine raises Native::EngineUnavailableError -- never a silent answer
# from another parser -- while everything the engine does answer for keeps
# the builder's ScoreError.
RSpec.describe Etassia::Parser::Native do
  let(:parser) { Etassia::Parser::UserJourney.new }
  let(:source) { "journey\nsection S\nT: 3: Me\n" }

  # The engine cannot load: a leg without a parsanol native gem.
  def without_engine
    previous = ENV.fetch("ETASSIA_NATIVE_PARSER", nil)
    ENV.delete("ETASSIA_NATIVE_PARSER")
    described_class.reset!
    allow(described_class).to receive(:require).with("parsanol")
      .and_raise(LoadError)
    yield
  ensure
    ENV["ETASSIA_NATIVE_PARSER"] = previous
    described_class.reset!
  end

  def expect_unavailable(journey_source, message)
    expect { parser.parse(journey_source) }
      .to raise_error(Etassia::Parser::Native::EngineUnavailableError,
                      message)
  end

  describe "with the engine absent" do
    it "raises Native::EngineUnavailableError instead of a Ruby answer" do
      without_engine { expect_unavailable(source, /parsanol native gem/) }
    end

    it "raises it before any builder runs" do
      without_engine do
        expect_unavailable("journey\n  A: 6: me", /parsanol native gem/)
      end
    end
  end

  describe "with the engine switched off by the environment" do
    it "raises Native::EngineUnavailableError naming the switch" do
      NativeParity.with_native(false) do
        expect_unavailable(source, /ETASSIA_NATIVE_PARSER/)
      end
    end
  end

  describe "the builder's score check on the native lane" do
    [
      "journey\n  A: 0",
      "journey\n  A: 6: me",
      "journey\n  A: 3\n  B: 99",
    ].each do |score_source|
      it "raises ScoreError for #{score_source.inspect}" do
        skip "parsanol engine absent" unless described_class.available?

        expect { parser.parse(score_source) }
          .to raise_error(Etassia::Parser::ScoreError,
                          /Score must be between 1 and 5/)
      end
    end
  end
end
