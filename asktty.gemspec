# frozen_string_literal: true

require_relative "lib/asktty/version"

Gem::Specification.new do |spec|
  spec.name = "asktty"
  spec.version = AskTTY::VERSION
  spec.authors = ["Vlad Suchy"]
  spec.summary = "Terminal prompts for Ruby."

  spec.homepage = "https://github.com/vsuchy/asktty"
  spec.license = "MIT"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]

  spec.metadata["rubygems_mfa_required"] = "true"

  spec.required_ruby_version = ">= 3.3.0"
end
