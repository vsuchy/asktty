# frozen_string_literal: true

module AskTTY
  module Internal
    module Validation
      module_function

      def message_for(value, validator, active:)
        return nil unless active && validator

        result = validator.call(value)
        return nil if result == true
        return result if result.is_a?(String)

        raise AskTTY::Error, "validator must return true or an error message"
      end
    end
  end
end
