# frozen_string_literal: true

module AskTTY
  module Internal
    module ANSIStyle
      module_function

      def style(text, foreground: nil, background: nil)
        codes = []
        codes << "38;5;#{foreground}" if foreground
        codes << "48;5;#{background}" if background

        return text.to_s if codes.empty?

        "\e[#{codes.join(';')}m#{text}\e[0m"
      end

      def title(text)
        style(text, foreground: 6)
      end

      def muted(text)
        style(text, foreground: 8)
      end

      def prompt(text)
        style(text, foreground: 3)
      end

      def text(text)
        style(text, foreground: 7)
      end

      def selected(text)
        style(text, foreground: 2)
      end

      def focused_button(text)
        style("  #{text}  ", foreground: 0, background: 2)
      end

      def blurred_button(text)
        style("  #{text}  ", foreground: 7, background: 0)
      end

      def cursor(text = " ")
        style(text, foreground: 7, background: 2)
      end

      def error(text)
        style(text, foreground: 9)
      end
    end
  end
end
