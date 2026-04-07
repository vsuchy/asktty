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

      def wrap(text, width)
        split_lines(text.to_s).flat_map { |line| wrap_line(line, width) }
      end

      def wrap_exact(text, width)
        split_lines(text.to_s).flat_map { |line| wrap_exact_line(line, width) }
      end

      def graphemes(text)
        text.scan(/\X/)
      end

      def split_lines(text)
        return [""] if text.empty?

        text.split("\n", -1)
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
