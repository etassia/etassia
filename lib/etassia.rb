# frozen_string_literal: true

# Etassia is the new name of the project formerly published as the
# `sirena` gem (ἐκτάσσω — drawn up in formation). This shim keeps
# `require "etassia"` working while the in-code rename
# (Sirena → Etassia, lib/sirena → lib/etassia) progresses — see the
# rename cascade issue in the repository tracker.
require_relative "sirena"

Etassia = Sirena
