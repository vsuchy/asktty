# frozen_string_literal: true

module AskTTY
  class TextPrompt
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
          when :shift_enter, :ctrl_j
            value << "\n"
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
      prefix = ">  "
      first_prefix = Internal::ANSIStyle.prompt("> ") + Internal::ANSIStyle.cursor
      continuation_prefix = " " * prefix.length
      wrapped = Internal::Rendering.wrap_exact(@placeholder, [content_width - prefix.length, 1].max)

      wrapped.each_with_index.map do |line, index|
        current_prefix = index.zero? ? first_prefix : continuation_prefix
        current_prefix + Internal::ANSIStyle.muted(line)
      end
    end

    def printable?(character)
      character.length == 1 && character >= " "
    end
  end
end
