# frozen_string_literal: true

module AskTTY
  class ConfirmPrompt
    def self.ask(title:, details: nil, value: false, &validator)
      new(title: title, details: details, value: value, validator: validator).ask
    end

    def initialize(title:, details: nil, value: false, validator: nil)
      @title = title.to_s
      @details = details&.to_s

      raise AskTTY::Error, "value must be true or false" unless [true, false].include?(value)

      @value = value
      @validator = validator
    end

    def ask
      validation_active = false

      Internal::Terminal.open do |session|
        loop do
          session.render(render(width: session.width, error_message: validation_message(validation_active)))

          case session.read_key
          when :enter
            validation_active = true
            next if validation_message(validation_active)

            session.render(submitted_render(width: session.width))
            return @value
          when :left, "h"
            previous_value = @value
            @value = true
            validation_active ||= @value != previous_value
          when :right, "l"
            previous_value = @value
            @value = false
            validation_active ||= @value != previous_value
          end
        end
      end
    end

    private

    def render(width:, error_message: nil)
      Internal::Rendering.prompt_frame(
        title: @title,
        details: @details,
        help_items: help_items,
        error_message: error_message,
        width: width,
        gap_before_body: true
      ) do |content_width|
        button_lines(content_width)
      end
    end

    def submitted_render(width:)
      Internal::Rendering.submitted_frame(@title, @value ? "Yes" : "No", width: width)
    end

    def button_lines(content_width)
      yes_button = @value ? Internal::ANSIStyle.focused_button("Yes") : Internal::ANSIStyle.blurred_button("Yes")
      no_button = @value ? Internal::ANSIStyle.blurred_button("No") : Internal::ANSIStyle.focused_button("No")

      row = "#{yes_button} #{no_button}"

      return [row] if Internal::Rendering.display_width(row) <= content_width

      button_width = [
        Internal::Rendering.display_width(yes_button),
        Internal::Rendering.display_width(no_button)
      ].max

      raise AskTTY::Error, "terminal is too narrow for confirmation prompt" if button_width > content_width

      [yes_button, no_button]
    end

    def help_items
      ["enter (submit)", "left/right (select option)"]
    end

    def validation_message(validation_active)
      Internal::Validation.message_for(@value, @validator, active: validation_active)
    end
  end
end
