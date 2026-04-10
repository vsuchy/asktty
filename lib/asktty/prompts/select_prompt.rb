# frozen_string_literal: true

module AskTTY
  class SelectPrompt
    UNSET = Object.new

    def self.ask(title:, options:, details: nil, value: UNSET, &validator)
      new(title: title, details: details, options: options, value: value, validator: validator).ask
    end

    def initialize(title:, options:, details: nil, value: UNSET, validator: nil)
      @title = title.to_s
      @details = details&.to_s
      @options = Internal::Options.normalize(options)
      @index = index_for(value)
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
            return selected_option.value
          when :up, "k"
            previous_value = selected_option.value
            move(-1)
            validation_active ||= selected_option.value != previous_value
          when :down, "j"
            previous_value = selected_option.value
            move(1)
            validation_active ||= selected_option.value != previous_value
          end
        end
      end
    end

    private

    def render(width:, error_message: nil)
      Internal::Rendering.prompt_frame(
        title: @title, details: @details, help_items: help_items, error_message: error_message, width: width
      ) do |content_width|
        option_lines(content_width)
      end
    end

    def submitted_render(width:)
      Internal::Rendering.submitted_frame(@title, selected_option.label, width: width)
    end

    def option_lines(content_width)
      @options.each_with_index.flat_map do |option, index|
        prefix = index == @index ? Internal::ANSIStyle.prompt("> ") : "  "
        style = index == @index ? Internal::ANSIStyle.method(:selected) : Internal::ANSIStyle.method(:text)

        wrap_option(option.label, prefix: prefix, width: content_width, &style)
      end
    end

    def help_items
      ["enter (submit)", "up/down (select item)"]
    end

    def index_for(value)
      return 0 if value.equal?(UNSET)

      @options.index { |option| option.value == value } ||
        raise(AskTTY::Error, "value is not a valid option value")
    end

    def move(offset)
      @index = (@index + offset) % @options.length
    end

    def selected_option
      @options[@index]
    end

    def validation_message(validation_active)
      Internal::Validation.message_for(selected_option.value, @validator, active: validation_active)
    end

    def wrap_option(label, prefix:, width:, &style)
      wrapped = Internal::Rendering.wrap(label, [width - 2, 1].max)

      wrapped.each_with_index.map do |line, index|
        current_prefix = index.zero? ? prefix : "  "
        current_prefix + style.call(line)
      end
    end
  end
end
