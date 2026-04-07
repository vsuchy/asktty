# frozen_string_literal: true

require "io/console"

module AskTTY
  module Internal
    class Terminal
      attr_reader :width

      def self.open
        raise AskTTY::Error, "interactive prompts require a TTY input and output" unless $stdin.tty? && $stdout.tty?

        terminal = new(input: $stdin, output: $stdout)

        terminal.open do |live_terminal|
          yield live_terminal
        ensure
          live_terminal.finish
        end
      end

      def initialize(input:, output:)
        @input = input
        @output = output
        @line_count = 0
        @finished = false

        @width = output.winsize[1]
        @width = 80 if @width.nil? || @width <= 0
      rescue StandardError
        @width = 80
      end

      def open
        @output.print "\e[?25l"
        @output.flush

        @input.raw do
          yield self
        end
      ensure
        @output.print "\e[0m\e[?25h"
        @output.flush
      end

      def render(text)
        text = text.to_s

        if @line_count > 1
          @output.print "\e[#{@line_count - 1}F"
        else
          @output.print "\r"
        end

        @output.print "\e[J"
        @output.print normalize_output(text)
        @output.flush

        @line_count = [text.split("\n", -1).length, 1].max
      end

      def finish
        return if @finished

        @finished = true
        @line_count = 0

        @output.print "\e[0m\r\n"
        @output.flush
      end

      def read_key
        character = @input.getch

        case character
        when "\u0003"
          raise Interrupt
        when "\r"
          :enter
        when "\n"
          :ctrl_j
        when "\u007F", "\b"
          :backspace
        when "\e"
          decode_escape_sequence(read_escape_sequence)
        else
          character
        end
      end

      private

      def normalize_output(text)
        text.gsub("\n", "\r\n")
      end

      def read_escape_sequence
        sequence = +""

        while @input.wait_readable(0.01)
          chunk = @input.read_nonblock(1, exception: false)
          break if chunk == :wait_readable || chunk.nil?

          sequence << chunk
          break if chunk.match?(/[A-Za-z~]/)
        end

        sequence
      end

      def decode_escape_sequence(sequence)
        case sequence
        when "[A", "OA"
          :up
        when "[B", "OB"
          :down
        when "[D", "OD"
          :left
        when "[C", "OC"
          :right
        when "[13;2u", "[13;2~", "[27;2;13~"
          :shift_enter
        else
          :escape
        end
      end
    end
  end
end
