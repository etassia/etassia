# frozen_string_literal: true

module Etassia
  # Base class for every Etassia::Error subclass across the pipeline (parser,
  # transform, renderer, engine). Its own file -- like version.rb -- so a
  # component's base.rb can require_relative it directly and load standalone
  # (`require "etassia/parser"` etc.) without first loading the whole
  # lib/etassia.rb require chain.
  class Error < StandardError; end
end
