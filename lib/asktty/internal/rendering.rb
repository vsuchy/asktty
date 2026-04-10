# frozen_string_literal: true

require "unicode/display_width"

module AskTTY
  module Internal
    module Rendering
      module_function

      def chop_grapheme(text)
        graphemes(text.to_s)[0...-1].join
      end

      def content_width(width)
        [width.to_i - 2, 1].max
      end

      def display_width(text)
        Unicode::DisplayWidth.of(text.to_s.gsub(/\e\[[\d;]*m/, ""), ambiguous: 1)
      end

      def frame(lines)
        content_lines = Array(lines).flat_map { |line| split_lines(line.to_s) }
        border = ANSIStyle.muted("┃")

        content_lines.map { |line| "#{border} #{line}" }.join("\n")
      end

      def submitted_frame(title, value, width:)
        prefix = "#{title}:"
        summary = value.to_s.empty? ? prefix : "#{prefix} #{value}"
        lines = wrap(summary, content_width(width))

        frame(style_submitted_lines(lines, title_length: graphemes(prefix).length))
      end

      def footer_lines(error_message:, help_line:, width:)
        lines = []

        if error_message && !error_message.empty?
          lines.concat(wrap(error_message, width).map do |line|
            ANSIStyle.error(line)
          end)
        end

        lines << help_line if help_line && !help_line.empty?

        return [] if lines.empty?

        [""] + lines
      end

      def help_line(items, width:)
        items = Array(items).map(&:to_s).reject(&:empty?)
        return "" if items.empty?

        line = +""
        total_width = 0

        items.each do |item|
          segment = total_width.zero? ? item : " • #{item}"
          segment_width = display_width(segment)

          tail, add_segment = help_line_tail(total_width, segment_width, width)

          unless add_segment
            line << tail
            break
          end

          line << segment
          total_width += segment_width
        end

        ANSIStyle.muted(line)
      end

      def placeholder_with_cursor(text)
        first_grapheme, *rest = graphemes(text.to_s)
        return ANSIStyle.cursor unless first_grapheme

        ANSIStyle.style(first_grapheme, foreground: 8, background: 2) + ANSIStyle.muted(rest.join)
      end

      def wrap(text, width)
        split_lines(text.to_s).flat_map { |line| wrap_line(line, width) }
      end

      def wrap_exact(text, width)
        split_lines(text.to_s).flat_map { |line| wrap_exact_line(line, width) }
      end

      def graphemes(text)
        text.scan(/\X/)
      end

      def help_line_tail(total_width, segment_width, width)
        if width.to_i.positive? && total_width + segment_width > width && (total_width + display_width(" …") < width)
          return [" …", false]
        end

        ["", true]
      end

      def split_lines(text)
        return [""] if text.empty?

        text.split("\n", -1)
      end

      def style_submitted_lines(lines, title_length:)
        remaining_title_length = title_length

        lines.map do |line|
          line_graphemes = graphemes(line)

          if remaining_title_length >= line_graphemes.length
            remaining_title_length -= line_graphemes.length
            ANSIStyle.title(line)
          elsif remaining_title_length.positive?
            title_text = line_graphemes[0, remaining_title_length].join
            value_text = line_graphemes[remaining_title_length..].to_a.join
            remaining_title_length = 0

            ANSIStyle.title(title_text) + ANSIStyle.text(value_text)
          else
            ANSIStyle.text(line)
          end
        end
      end

      def wrap_line(line, width)
        return [""] if line.empty?

        lines = []
        remaining = graphemes(line)

        until remaining.empty?
          segment, last_whitespace_index = take_segment(remaining, width)

          if segment.length == remaining.length
            lines << segment.join
            break
          end

          if last_whitespace_index&.positive?
            lines << segment[0...last_whitespace_index].join.rstrip
            remaining = remaining[(last_whitespace_index + 1)..] || []
            remaining = remaining.drop_while { |grapheme| grapheme.match?(/\s/) }
          else
            lines << segment.join
            remaining = remaining[segment.length..] || []
          end
        end

        lines
      end

      def wrap_exact_line(line, width)
        return [""] if line.empty?

        lines = []
        remaining = graphemes(line)

        until remaining.empty?
          segment, = take_segment(remaining, width)
          lines << segment.join
          remaining = remaining[segment.length..] || []
        end

        lines
      end

      def take_segment(graphemes, width)
        segment = []
        segment_width = 0
        last_whitespace_index = nil

        graphemes.each_with_index do |grapheme, index|
          grapheme_width = display_width(grapheme)

          if segment_width.zero? && grapheme_width > width
            return [[grapheme], grapheme.match?(/\s/) ? 0 : nil]
          end

          break if segment_width.positive? && segment_width + grapheme_width > width

          segment << grapheme
          segment_width += grapheme_width
          last_whitespace_index = index if grapheme.match?(/\s/)

          break if segment_width >= width
        end

        [segment, last_whitespace_index]
      end
    end
  end
end
