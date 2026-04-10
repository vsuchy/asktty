# frozen_string_literal: true

module AskTTY
  class TextPrompt
    def self.ask(title:, details: nil, placeholder: nil, value: nil, &validator)
      new(title: title, details: details, placeholder: placeholder, value: value, validator: validator).ask
    end

    def initialize(title:, details: nil, placeholder: nil, value: nil, validator: nil)
      @title = title.to_s
      @details = details&.to_s
      @placeholder = placeholder&.to_s
      @value = value.to_s
      @validator = validator
    end

    def ask
      value = @value.dup
      validation_active = false

      Internal::Terminal.open do |session|
        loop do
          session.render(
            render(
              value,
              width: session.width,
              show_cursor: true,
              error_message: validation_message(value, validation_active)
            )
          )

          key = session.read_key

          case key
          when :enter
            validation_active = true
            next if validation_message(value, validation_active)

            session.render(submitted_render(value, width: session.width))
            return value
          when :shift_enter, :ctrl_j
            value << "\n"
            validation_active = true
          when :backspace
            updated_value = Internal::Rendering.chop_grapheme(value)
            validation_active ||= updated_value != value
            value = updated_value
          when String
            next unless printable?(key)

            value << key
            validation_active = true
          end
        end
      end
    end

    private

    def render(value, width:, show_cursor:, error_message: nil)
      content_width = Internal::Rendering.content_width(width)

      lines = header_lines(content_width)
      lines.concat(body_lines(value, content_width: content_width, show_cursor: show_cursor))
      lines.concat(footer_lines(content_width, error_message: error_message))

      Internal::Rendering.frame(lines)
    end

    def submitted_render(value, width:)
      Internal::Rendering.submitted_frame(@title, value.tr("\n", " "), width: width)
    end

    def header_lines(content_width)
      lines = Internal::Rendering.wrap(@title, content_width).map { |line| Internal::ANSIStyle.title(line) }

      return lines unless @details

      lines + Internal::Rendering.wrap(@details, content_width).map { |line| Internal::ANSIStyle.muted(line) }
    end

    def body_lines(value, content_width:, show_cursor:)
      return placeholder_lines(content_width) if @placeholder && value.empty? && show_cursor

      lines = value.split("\n", -1)
      lines = [""] if lines.empty?

      lines.each_with_index.flat_map do |line, index|
        prefix = index.zero? ? Internal::ANSIStyle.prompt("> ") : "  "
        wrap_width = [content_width - 2, 1].max
        wrapped = Internal::Rendering.wrap_exact(line, wrap_width)
        wrapped = [""] if wrapped.empty?

        if show_cursor && index == lines.length - 1 && Internal::Rendering.display_width(wrapped.last) >= wrap_width
          wrapped << ""
        end

        wrapped.each_with_index.map do |part, wrapped_index|
          current_prefix = wrapped_index.zero? ? prefix : "  "
          current_line = current_prefix + Internal::ANSIStyle.text(part)

          if show_cursor && index == lines.length - 1 && wrapped_index == wrapped.length - 1
            current_line << Internal::ANSIStyle.cursor
          end

          current_line
        end
      end
    end

    def placeholder_lines(content_width)
      wrapped = Internal::Rendering.wrap_exact(@placeholder, [content_width - 2, 1].max)
      wrapped = [""] if wrapped.empty?

      wrapped.each_with_index.map do |line, index|
        current_prefix = index.zero? ? Internal::ANSIStyle.prompt("> ") : "  "
        text = index.zero? ? Internal::Rendering.placeholder_with_cursor(line) : Internal::ANSIStyle.muted(line)

        current_prefix + text
      end
    end

    def footer_lines(content_width, error_message:)
      Internal::Rendering.footer_lines(
        error_message: error_message,
        help_line: Internal::Rendering.help_line(
          ["enter (submit)", "shift+enter/ctrl+j (new line)"], width: content_width
        ),
        width: content_width
      )
    end

    def printable?(character)
      character.length == 1 && character >= " "
    end

    def validation_message(value, validation_active)
      Internal::Validation.message_for(value, @validator, active: validation_active)
    end
  end
end
