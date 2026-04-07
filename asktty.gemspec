# frozen_string_literal: true

require_relative "lib/asktty/version"

Gem::Specification.new do |spec|
  spec.name = "asktty"
  spec.version = AskTTY::VERSION
  spec.authors = ["Vlad Suchy"]
  spec.summary = "Terminal prompts for Ruby."

  spec.description = <<~DESC
    AskTTY is a Ruby library for interactive terminal prompts in CLI applications and scripts.
    It provides input, text, select, multi-select and confirm prompts
    through a small, direct API with a polished terminal UI.
  DESC
  spec.homepage = "https://github.com/vsuchy/asktty"
  spec.license = "MIT"

  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]

  spec.required_ruby_version = ">= 3.3.0"
  spec.add_dependency "unicode-display_width", "~> 3.2"
end
