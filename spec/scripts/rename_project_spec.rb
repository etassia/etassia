# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"

module RenameProject
  SCRIPT_PATH = File.expand_path("../../scripts/rename_project.py", __dir__)
  WORKFLOW_PATH = ".github/workflows/links.yml"
end

RSpec.describe RenameProject, type: :task do
  let(:root) { Dir.mktmpdir("rename-project") }
  let(:workflow) do
    <<~YAML
      args: >-
        --remap 'https://claricle.github.io/sirena/ file://site/'
        --remap 'https://www.claricle.org/sirena/ file://site/'
      # project token: sirena
    YAML
  end
  let(:migration_result) do
    _stdout, stderr, status = Open3.capture3(
      "python3", described_class::SCRIPT_PATH, "sirena", "etassia",
      "--paths", ".github/workflows", chdir: root
    )
    [status.success?, stderr,
     File.read(File.join(root, described_class::WORKFLOW_PATH))]
  end
  let(:expected_workflow) do
    workflow.sub("project token: sirena", "project token: etassia")
  end

  before do
    path = File.join(root, described_class::WORKFLOW_PATH)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, workflow)
    system("git", "init", "--quiet", root, exception: true)
    system(
      "git", "-C", root, "add", described_class::WORKFLOW_PATH,
      exception: true
    )
  end

  after { FileUtils.remove_entry(root, true) }

  it "preserves deployed-site remaps while renaming other tokens" do
    expect(migration_result).to eq([true, "", expected_workflow])
  end
end
