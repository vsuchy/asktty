# frozen_string_literal: true

module AskTTY
  module Internal
    module Options
      Option = Struct.new(:label, :value)

      module_function

      def normalize(options)
        raise AskTTY::Error, "options must not be empty" if options.nil? || options.empty?

        options.map do |option|
          next option if option.is_a?(Option)

          raise AskTTY::Error, "options must be hashes with label and value" unless option.is_a?(Hash)

          label = option[:label] || option["label"]
          has_value = option.key?(:value) || option.key?("value")
          value = option[:value] if option.key?(:value)
          value = option["value"] if option.key?("value")

          raise AskTTY::Error, "options must include label and value" unless label && has_value

          Option.new(label.to_s, value)
        end
      end

      def values(options)
        options.map(&:value)
      end
    end
  end
end
