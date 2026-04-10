# frozen_string_literal: true

module AskTTY
  class InputPrompt
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
      Internal::Rendering.submitted_frame(@title, value, width: width)
    end

    def header_lines(content_width)
      lines = Internal::Rendering.wrap(@title, content_width).map { |line| Internal::ANSIStyle.title(line) }

      return lines unless @details

      lines + Internal::Rendering.wrap(@details, content_width).map { |line| Internal::ANSIStyle.muted(line) }
    end

    def body_lines(value, content_width:, show_cursor:)
      return placeholder_lines(content_width) if @placeholder && value.empty? && show_cursor
      return [empty_line(show_cursor: show_cursor)] if value.empty?

      typed_value_lines(value, content_width: content_width, show_cursor: show_cursor)
    end

    def empty_line(show_cursor:)
      line = +Internal::ANSIStyle.prompt("> ")
      line << Internal::ANSIStyle.cursor if show_cursor
      line
    end

    def placeholder_lines(content_width)
      segments = Internal::Rendering.wrap_exact(@placeholder.to_s, [content_width - 2, 1].max)
      segments = [""] if segments.empty?

      segments.each_with_index.map do |segment, index|
        prefix = index.zero? ? Internal::ANSIStyle.prompt("> ") : "  "
        text = index.zero? ? Internal::Rendering.placeholder_with_cursor(segment) : Internal::ANSIStyle.muted(segment)

        prefix + text
      end
    end

    def typed_value_lines(value, content_width:, show_cursor:)
      wrap_width = [content_width - 2, 1].max
      segments = Internal::Rendering.wrap_exact(value, wrap_width)
      segments << "" if show_cursor && Internal::Rendering.display_width(segments.last) >= wrap_width

      render_segments(
        segments,
        first_prefix: Internal::ANSIStyle.prompt("> "),
        continuation_prefix: "  ",
        style: Internal::ANSIStyle.method(:text),
        show_cursor: show_cursor
      )
    end

    def footer_lines(content_width, error_message:)
      Internal::Rendering.footer_lines(
        error_message: error_message,
        help_line: Internal::Rendering.help_line(["enter (submit)"], width: content_width),
        width: content_width
      )
    end

    def render_segments(segments, first_prefix:, continuation_prefix:, style:, show_cursor: false)
      segments = [""] if segments.empty?

      segments.each_with_index.map do |segment, index|
        line = (index.zero? ? first_prefix : continuation_prefix) + style.call(segment)
        line << Internal::ANSIStyle.cursor if show_cursor && index == segments.length - 1
        line
      end
    end

    def printable?(character)
      character.length == 1 && character >= " "
    end

    def validation_message(value, validation_active)
      Internal::Validation.message_for(value, @validator, active: validation_active)
    end
  end
end
