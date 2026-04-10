# frozen_string_literal: true

module AskTTY
  module Internal
    class TextInputPrompt
      def initialize(title:, details: nil, placeholder: nil, value: nil, validator: nil, multiline: false)
        @title = title.to_s
        @details = details&.to_s
        @placeholder = placeholder&.to_s
        @value = value.to_s
        @validator = validator
        @multiline = multiline
      end

      def ask
        value = @value.dup
        validation_active = false

        Terminal.open do |session|
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
              next unless @multiline

              value << "\n"
              validation_active = true
            when :backspace
              updated_value = Rendering.chop_grapheme(value)
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
        Rendering.prompt_frame(
          title: @title, details: @details, help_items: help_items, error_message: error_message, width: width
        ) do |content_width|
          body_lines(value, content_width: content_width, show_cursor: show_cursor)
        end
      end

      def submitted_render(value, width:)
        Rendering.submitted_frame(@title, summary_value(value), width: width)
      end

      def body_lines(value, content_width:, show_cursor:)
        return placeholder_lines(content_width) if @placeholder && value.empty? && show_cursor

        render_segments(value_lines(value), content_width: content_width, show_cursor: show_cursor)
      end

      def placeholder_lines(content_width)
        render_segments(
          @placeholder.to_s.split("\n", -1),
          content_width: content_width,
          show_cursor: false,
          first_style: method(:placeholder_first_line),
          style: ANSIStyle.method(:muted)
        )
      end

      def value_lines(value)
        return [value] unless @multiline

        value.split("\n", -1)
      end

      def help_items
        return ["enter (submit)"] unless @multiline

        ["enter (submit)", "shift+enter/ctrl+j (new line)"]
      end

      def placeholder_first_line(text)
        Rendering.placeholder_with_cursor(text)
      end

      def printable?(character)
        character.length == 1 && character >= " "
      end

      def render_segments(
        segments, content_width:, show_cursor:, first_style: ANSIStyle.method(:text), style: first_style
      )
        segments = [""] if segments.empty?
        wrap_width = [content_width - 2, 1].max
        last_index = segments.length - 1

        segments.each_with_index.flat_map do |segment, segment_index|
          wrapped_segments = Rendering.wrap_exact(segment, wrap_width)
          wrapped_segments = [""] if wrapped_segments.empty?

          if show_cursor && segment_index == last_index && Rendering.display_width(wrapped_segments.last) >= wrap_width
            wrapped_segments << ""
          end

          wrapped_segments.each_with_index.map do |part, wrapped_index|
            prefix = segment_index.zero? && wrapped_index.zero? ? ANSIStyle.prompt("> ") : "  "
            current_style = segment_index.zero? && wrapped_index.zero? ? first_style : style
            line = prefix + current_style.call(part)

            if show_cursor && segment_index == last_index && wrapped_index == wrapped_segments.length - 1
              line << ANSIStyle.cursor
            end

            line
          end
        end
      end

      def summary_value(value)
        return value unless @multiline

        value.tr("\n", " ")
      end

      def validation_message(value, validation_active)
        Validation.message_for(value, @validator, active: validation_active)
      end
    end
  end
end
