# frozen_string_literal: true

module AskTTY
  class ConfirmPrompt
    def self.ask(title:, details: nil, value: false)
      new(title: title, details: details, value: value).ask
    end

    def initialize(title:, details: nil, value: false)
      @title = title.to_s
      @details = details&.to_s
      @value = !!value
    end

    def ask
      Internal::Terminal.open do |session|
        loop do
          session.render(render(width: session.width))

          case session.read_key
          when :enter
            session.render(render(width: session.width))
            return @value
          when :left, "h"
            @value = true
          when :right, "l"
            @value = false
          end
        end
      end
    end

    private

    def render(width:)
      content_width = Internal::Rendering.content_width(width)

      lines = header_lines(content_width)
      lines << "" unless lines.empty?
      lines.concat(button_lines(content_width))

      Internal::Rendering.frame(lines)
    end

    def header_lines(content_width)
      lines = Internal::Rendering.wrap(@title, content_width).map { |line| Internal::ANSIStyle.title(line) }

      return lines unless @details

      lines + Internal::Rendering.wrap(@details, content_width).map { |line| Internal::ANSIStyle.muted(line) }
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
  end
end
