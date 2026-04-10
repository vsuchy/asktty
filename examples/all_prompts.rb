#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/asktty"

name = AskTTY::InputPrompt.ask(
  title: "Name",
  details: "Enter the name you want displayed on your badge.",
  placeholder: "Vlad"
) do |value|
  value.strip.length >= 3 || "Name must be at least 3 characters."
end

project = AskTTY::TextPrompt.ask(
  title: "Ruby Project",
  details: "Add the project name and a short description.",
  placeholder: "AskTTY\nTerminal prompts for Ruby"
) do |value|
  value.lines.reject { |line| line.strip.empty? }.length >= 2 || "Add at least two lines."
end

experience = AskTTY::SelectPrompt.ask(
  title: "Experience Level",
  details: "This workshop assumes prior Ruby experience.",
  options: [
    { label: "Beginner", value: :beginner },
    { label: "Intermediate", value: :intermediate },
    { label: "Advanced", value: :advanced }
  ],
  value: :intermediate
) do |value|
  value != :beginner || "Please choose Intermediate or Advanced."
end

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
) do |values|
  values.any? || "Select at least one topic."
end

confirmed = AskTTY::ConfirmPrompt.ask(
  title: "Confirmation",
  details: "Confirm that you plan to attend the event.",
  value: false
) do |value|
  value || "Please confirm that you plan to attend."
end

puts
puts "Name: #{name}"
puts "Ruby Project: #{project.inspect}"
puts "Experience: #{experience}"
puts "Topics: #{topics.join(', ')}"
puts "Confirmed: #{confirmed}"
