# frozen_string_literal: true

module AskTTY
  class InputPrompt
    def self.ask(title:, details: nil, placeholder: nil, value: nil)
      new(title: title, details: details, placeholder: placeholder, value: value).ask
    end

    def initialize(title:, details: nil, placeholder: nil, value: nil)
      @title = title.to_s
      @details = details&.to_s
      @placeholder = placeholder&.to_s
      @value = value.to_s
    end

    def ask
      value = @value.dup

      Internal::Terminal.open do |session|
        loop do
          session.render(render(value, width: session.width, show_cursor: true))

          key = session.read_key

          case key
          when :enter
            session.render(render(value, width: session.width, show_cursor: false))
            return value
          when :backspace
            value = Internal::Rendering.chop_grapheme(value)
          when String
            value << key if printable?(key)
          end
        end
      end
    end

    private

    def render(value, width:, show_cursor:)
      content_width = Internal::Rendering.content_width(width)

      lines = header_lines(content_width)
      lines.concat(body_lines(value, content_width: content_width, show_cursor: show_cursor))

      Internal::Rendering.frame(lines)
    end

    def header_lines(content_width)
      lines = Internal::Rendering.wrap(@title, content_width).map { |line| Internal::ANSIStyle.title(line) }

      return lines unless @details

      lines + Internal::Rendering.wrap(@details, content_width).map { |line| Internal::ANSIStyle.muted(line) }
    end

    def body_lines(value, content_width:, show_cursor:)
      return placeholder_lines(content_width, show_cursor: show_cursor) if @placeholder && value.empty? && show_cursor
      return [empty_line(show_cursor: show_cursor)] if value.empty?

      typed_value_lines(value, content_width: content_width, show_cursor: show_cursor)
    end

    def empty_line(show_cursor:)
      line = +Internal::ANSIStyle.prompt("> ")
      line << Internal::ANSIStyle.cursor if show_cursor
      line
    end

    def placeholder_lines(content_width, show_cursor:)
      prefix_width = show_cursor ? 3 : 2
      first_prefix = +Internal::ANSIStyle.prompt("> ")
      first_prefix << Internal::ANSIStyle.cursor if show_cursor

      render_segments(
        Internal::Rendering.wrap_exact(@placeholder.to_s, [content_width - prefix_width, 1].max),
        first_prefix: first_prefix,
        continuation_prefix: " " * prefix_width,
        style: Internal::ANSIStyle.method(:muted)
      )
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
  end
end
