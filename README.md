# AskTTY

A Ruby gem for interactive terminal prompts.

## Installation

Install it globaly:

```sh
gem install asktty
```

or, add it to your application gemfile:

```sh
bundle add asktty
```

## Usage

```ruby
require "asktty"
```

### Input Prompt

```ruby
name = AskTTY::InputPrompt.ask(
  title: "Name",
  details: "Enter the name you want displayed on your badge.",
  placeholder: "Vlad"
)
```

### Text Prompt

```ruby
notes = AskTTY::TextPrompt.ask(
  title: "Ruby Project",
  placeholder: "AskTTY\nTerminal prompts for Ruby"
)
```

### Select Prompt

```ruby
drink = AskTTY::SelectPrompt.ask(
  title: "Experience Level",
  options: [
    { label: "Beginner", value: :beginner },
    { label: "Intermediate", value: :intermediate },
    { label: "Advanced", value: :advanced }
  ],
  value: :intermediate
)
```

### MultiSelect Prompt

```ruby
toppings = AskTTY::MultiSelectPrompt.ask(
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
```

### Confirm Prompt

```ruby
confirmed = AskTTY::ConfirmPrompt.ask(
  title: "Confirmation",
  details: "Confirm that you plan to attend the event.",
  value: true
)
```

### Validation

Pass a block that returns `true` when the current value is valid, or an error message when it is not:

```ruby
name = AskTTY::InputPrompt.ask(title: "Name") do |value|
  value.length >= 3 || "Name must be at least 3 characters"
end
```

## Examples

Run the interactive example from the project root:

```sh
ruby examples/all_prompts.rb
```

## Credit

The prompt UI in AskTTY is based on [huh?](https://github.com/charmbracelet/huh).
