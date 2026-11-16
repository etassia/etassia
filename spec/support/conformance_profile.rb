# frozen_string_literal: true

# The operative svg_conform profile this repo's gates run against, and the
# place it is loaded -- never lib/: the runtime does not depend on
# svg_conform at all (spec/etassia/svg_no_runtime_remediation_spec.rb holds
# that line), and svg_conform 0.2.10 renamed its bundled metanorma.yml to a
# sample on purpose, because each consumer owns its operative profile.
# Ours lives at config/svg_conform/metanorma.yml.
module SpecSupport
  module ConformanceProfile
    PATH = File.expand_path("../../config/svg_conform/metanorma.yml",
                            __dir__).freeze

    module_function

    def call
      @call ||= SvgConform::Profile.load_from_file(PATH)
    end
  end
end
