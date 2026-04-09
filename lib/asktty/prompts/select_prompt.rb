# frozen_string_literal: true

module AskTTY
  class SelectPrompt
    UNSET = Object.new

    def self.ask(title:, options:, details: nil, value: UNSET)
      new(title: title, details: details, options: options, value: value).ask
    end

    def initialize(title:, options:, details: nil, value: UNSET)
      @title = title.to_s
      @details = details&.to_s
      @options = Internal::Options.normalize(options)
      @index = index_for(value)
    end

    def ask
      Internal::Terminal.open do |session|
        loop do
          session.render(render(width: session.width))

          case session.read_key
          when :enter
            session.render(submitted_render(width: session.width))
            return selected_option.value
          when :up, "k"
            move(-1)
          when :down, "j"
            move(1)
          end
        end
      end
    end

    private

    def render(width:)
      content_width = Internal::Rendering.content_width(width)

      lines = header_lines(content_width)
      lines.concat(option_lines(content_width))
      lines.concat(help_lines(content_width))

      Internal::Rendering.frame(lines)
    end

    def submitted_render(width:)
      Internal::Rendering.submitted_frame(@title, selected_option.label, width: width)
    end

    def header_lines(content_width)
      lines = Internal::Rendering.wrap(@title, content_width).map { |line| Internal::ANSIStyle.title(line) }

      return lines unless @details

      lines + Internal::Rendering.wrap(@details, content_width).map { |line| Internal::ANSIStyle.muted(line) }
    end

    def option_lines(content_width)
      @options.each_with_index.flat_map do |option, index|
        prefix = index == @index ? Internal::ANSIStyle.prompt("> ") : "  "
        style = index == @index ? Internal::ANSIStyle.method(:selected) : Internal::ANSIStyle.method(:text)

        wrap_option(option.label, prefix: prefix, width: content_width, &style)
      end
    end

    def help_lines(content_width)
      ["", Internal::Rendering.help_line(["enter (submit)", "up/down (select item)"], width: content_width)]
    end

    def wrap_option(label, prefix:, width:, &style)
      wrapped = Internal::Rendering.wrap(label, [width - 2, 1].max)

      wrapped.each_with_index.map do |line, index|
        current_prefix = index.zero? ? prefix : "  "
        current_prefix + style.call(line)
      end
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
  end
end
