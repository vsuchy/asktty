# frozen_string_literal: true

require "test_helper"

class TestAskTTY < Minitest::Test
  def test_input_prompt_returns_the_entered_text
    execution = run_asktty(
      <<~RUBY,
        AskTTY::InputPrompt.ask(title: "Name", details: "Enter your name.", placeholder: "Ada")
      RUBY
      tty: true,
      input_chunks: ["V", "l", "a", "d", "\r"]
    )

    assert_successful_run(execution)
    assert_equal "Vlad", execution.value
  end

  def test_text_prompt_returns_multiline_text
    execution = run_asktty(
      <<~RUBY,
        AskTTY::TextPrompt.ask(title: "Notes")
      RUBY
      tty: true,
      input_chunks: ["T", "e", "s", "t", "\n", "1", "2", "3", "\r"]
    )

    assert_successful_run(execution)
    assert_equal "Test\n123", execution.value
  end

  def test_select_prompt_returns_the_selected_value
    execution = run_asktty(
      <<~RUBY,
        AskTTY::SelectPrompt.ask(
          title: "Level",
          options: [
            { label: "Beginner", value: :beginner },
            { label: "Intermediate", value: :intermediate },
            { label: "Advanced", value: :advanced }
          ]
        )
      RUBY
      tty: true,
      input_chunks: ["\e[B", "\r"]
    )

    assert_successful_run(execution)
    assert_equal :intermediate, execution.value
  end

  def test_multi_select_prompt_returns_the_selected_values
    execution = run_asktty(
      <<~RUBY,
        AskTTY::MultiSelectPrompt.ask(
          title: "Topics",
          options: [
            { label: "Rails", value: :rails },
            { label: "Testing", value: :testing },
            { label: "CLI", value: :cli }
          ],
          values: [:testing]
        )
      RUBY
      tty: true,
      input_chunks: [" ", "\e[B", " ", "\e[B", " ", "\r"]
    )

    assert_successful_run(execution)
    assert_equal %i[rails cli], execution.value
  end

  def test_confirm_prompt_returns_the_selected_boolean
    execution = run_asktty(
      <<~RUBY,
        AskTTY::ConfirmPrompt.ask(title: "Confirm", value: false)
      RUBY
      tty: true,
      input_chunks: ["\e[D", "\r"]
    )

    assert_successful_run(execution)
    assert execution.value
  end

  def test_input_prompt_requires_tty_input_and_output
    execution = run_asktty(
      <<~RUBY
        AskTTY::InputPrompt.ask(title: "Name")
      RUBY
    )

    assert_public_error(
      execution, class_name: "AskTTY::Error", message: "interactive prompts require a TTY input and output"
    )
  end

  def test_input_prompt_shows_validation_message_and_accepts_retry
    execution = run_asktty(
      <<~RUBY,
        AskTTY::InputPrompt.ask(title: "Name") do |value|
          value.length >= 3 || "too short"
        end
      RUBY
      tty: true,
      input_chunks: ["V", "l", "\r", "a", "d", "\r"]
    )

    assert_successful_run(execution)
    assert_includes execution.output, "too short"
    assert_equal "Vlad", execution.value
  end

  def test_input_prompt_rejects_invalid_validator_return_values
    execution = run_asktty(
      <<~RUBY,
        AskTTY::InputPrompt.ask(title: "Name", value: "Vlad") do |_value|
          :invalid
        end
      RUBY
      tty: true,
      input_chunks: ["\r"]
    )

    assert_public_error(
      execution, class_name: "AskTTY::Error", message: "validator must return true or an error message"
    )
  end

  def test_select_prompt_rejects_an_unknown_initial_value
    execution = run_asktty(
      <<~RUBY
        AskTTY::SelectPrompt.ask(title: "Level", options: [{ label: "Beginner", value: :beginner }], value: :advanced)
      RUBY
    )

    assert_public_error(execution, class_name: "AskTTY::Error", message: "value is not a valid option value")
  end

  def test_multi_select_prompt_rejects_unknown_initial_values
    execution = run_asktty(
      <<~RUBY
        AskTTY::MultiSelectPrompt.ask(title: "Topics", options: [{ label: "Rails", value: :rails }], values: [:cli])
      RUBY
    )

    assert_public_error(execution, class_name: "AskTTY::Error", message: "values contain unknown option values")
  end

  def test_confirm_prompt_rejects_non_boolean_initial_values
    execution = run_asktty(
      <<~RUBY
        AskTTY::ConfirmPrompt.ask(title: "Confirm", value: nil)
      RUBY
    )

    assert_public_error(execution, class_name: "AskTTY::Error", message: "value must be true or false")
  end
end
