# frozen_string_literal: true

require "spec_helper"
require "etassia/cli"
require "etassia/commands/batch"
require "etassia/commands/types"
require "etassia/commands/version"

RSpec.describe Etassia::Cli do
  it "tells Thor command failures require a nonzero exit" do
    expect(described_class.exit_on_failure?).to be(true)
  end

  [
    ["types", Etassia::Commands::TypesCommand],
    ["batch", Etassia::Commands::BatchCommand],
    ["version", Etassia::Commands::VersionCommand],
  ].each do |name, command_class|
    context "with the #{name} command" do
      let(:command) { instance_double(command_class) }

      before do
        allow(command_class).to receive(:new).and_return(command)
        allow(command).to receive(:run).and_raise(ArgumentError, "broken")
      end

      it "reports a failure and exits one" do
        expect { described_class.start([name]) }
          .to output("Error: broken\n").to_stderr
          .and raise_error(SystemExit) do |error|
            raise "expected exit status 1" unless error.status == 1
          end
      end
    end
  end
end
