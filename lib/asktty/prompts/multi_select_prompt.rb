# frozen_string_literal: true

module AskTTY
  class MultiSelectPrompt
    def self.ask(title:, options:, details: nil, values: nil, &validator)
      new(title: title, details: details, options: options, values: values, validator: validator).ask
    end

    def initialize(title:, options:, details: nil, values: nil, validator: nil)
      @title = title.to_s
      @details = details&.to_s
      @options = Internal::Options.normalize(options)
      @selected_values = Array(values).uniq
      @validator = validator

      option_values = Internal::Options.values(@options)

      unknown_values = @selected_values - option_values
      raise AskTTY::Error, "values contain unknown option values" unless unknown_values.empty?

      @index = first_selected_index || 0
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
            return selected_results
          when :up, "k"
            move(-1)
          when :down, "j"
            move(1)
          when " "
            previous_results = selected_results
            toggle_current
            validation_active ||= selected_results != previous_results
          end
        end
      end
    end

    private

    def render(width:, error_message: nil)
      content_width = Internal::Rendering.content_width(width)

      lines = header_lines(content_width)
      lines.concat(option_lines(content_width))
      lines.concat(footer_lines(content_width, error_message: error_message))

      Internal::Rendering.frame(lines)
    end

    def submitted_render(width:)
      labels = selected_options.map(&:label).join(", ")

      Internal::Rendering.submitted_frame(@title, labels, width: width)
    end

    def header_lines(content_width)
      lines = Internal::Rendering.wrap(@title, content_width).map { |line| Internal::ANSIStyle.title(line) }

      return lines unless @details

      lines + Internal::Rendering.wrap(@details, content_width).map { |line| Internal::ANSIStyle.muted(line) }
    end

    def option_lines(content_width)
      @options.each_with_index.flat_map do |option, index|
        cursor = index == @index ? Internal::ANSIStyle.prompt("> ") : "  "
        selected = @selected_values.include?(option.value)
        prefix = selected ? Internal::ANSIStyle.selected("[•] ") : Internal::ANSIStyle.text("[ ] ")
        style = selected ? Internal::ANSIStyle.method(:selected) : Internal::ANSIStyle.method(:text)

        wrap_option(option.label, cursor: cursor, prefix: prefix, width: content_width, &style)
      end
    end

    def footer_lines(content_width, error_message:)
      Internal::Rendering.footer_lines(
        error_message: error_message,
        help_line: Internal::Rendering.help_line(
          ["enter (submit)", "up/down (select item)", "space (toggle item)"], width: content_width
        ),
        width: content_width
      )
    end

    def wrap_option(label, cursor:, prefix:, width:, &style)
      prefix_width = Internal::Rendering.display_width(cursor + prefix)
      wrapped = Internal::Rendering.wrap(label, [width - prefix_width, 1].max)

      wrapped.each_with_index.map do |line, index|
        current_prefix = index.zero? ? cursor + prefix : (" " * prefix_width)
        current_prefix + style.call(line)
      end
    end

    def first_selected_index
      @options.index { |option| @selected_values.include?(option.value) }
    end

    def selected_options
      @options.select { |option| @selected_values.include?(option.value) }
    end

    def selected_results
      selected_options.map(&:value)
    end

    def move(offset)
      @index = (@index + offset) % @options.length
    end

    def toggle_current
      value = @options[@index].value

      if @selected_values.include?(value)
        @selected_values.delete(value)
      else
        @selected_values << value
      end
    end

    def validation_message(validation_active)
      Internal::Validation.message_for(selected_results, @validator, active: validation_active)
    end
  end
end
