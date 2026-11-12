# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "Etassia" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:gemspec) { Gem::Specification.load(File.join(root, "etassia.gemspec")) }

  it "loads the public entry point in a fresh Ruby process",
     :aggregate_failures do
    output, status = Open3.capture2e(
      RbConfig.ruby, "-I#{root}/lib", "-retassia", "-e", "puts Etassia::VERSION"
    )

    expect(status).to be_success, output
    expect(output).to include(Etassia::VERSION)
  end

  it "renders a diagram through the renamed API" do
    svg = Etassia.render("pie\n  \"a\" : 1\n")

    expect(svg).to include("<svg", "</svg>")
  end

  it "defines the version" do
    expect(Etassia::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  it "publishes the renamed gem and homepage", :aggregate_failures do
    expect(gemspec.name).to eq("etassia")
    expect(gemspec.homepage).to eq("https://github.com/etassia/etassia")
    expect(gemspec.version.to_s).to eq(Etassia::VERSION)
  end

  it "ships the renamed executable", :aggregate_failures do
    expect(File.executable?(File.join(root, "exe/etassia"))).to be(true)
    expect(gemspec.executables).to include("etassia")
  end

  it "does not define the former Ruby module when required" do
    output, status = Open3.capture2e(
      RbConfig.ruby, "-I#{root}/lib", "-retassia", "-e",
      "abort 'legacy module defined' if Object.const_defined?(:Sirena)"
    )

    expect(status).to be_success, output
  end
end
