#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/asktty"

name = AskTTY::InputPrompt.ask(
  title: "Name",
  details: "Enter the name you want displayed on your badge.",
  placeholder: "Vlad"
)

project = AskTTY::TextPrompt.ask(
  title: "Ruby Project",
  placeholder: "AskTTY\nTerminal prompts for Ruby"
)

experience = AskTTY::SelectPrompt.ask(
  title: "Experience Level",
  options: [
    { label: "Beginner", value: :beginner },
    { label: "Intermediate", value: :intermediate },
    { label: "Advanced", value: :advanced }
  ],
  value: :intermediate
)

topics = AskTTY::MultiSelectPrompt.ask(
  title: "Topics",
  details: "Select all topics you are interested in.",
  options: [
    { label: "Rails", value: :rails },
    { label: "Metaprogramming", value: :metaprogramming },
    { label: "API development", value: :api_development },
    { label: "Background jobs", value: :background_jobs },
    { label: "Testing", value: :testing }
  ],
  values: [:metaprogramming]
)

confirmed = AskTTY::ConfirmPrompt.ask(
  title: "Confirmation",
  details: "Confirm that you plan to attend the event.",
  value: false
)

puts
puts "Name: #{name}"
puts "Ruby Project: #{project.inspect}"
puts "Experience: #{experience}"
puts "Topics: #{topics.join(', ')}"
puts "Confirmed: #{confirmed}"
