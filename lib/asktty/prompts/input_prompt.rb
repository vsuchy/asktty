# frozen_string_literal: true

module AskTTY
  class InputPrompt
    def self.ask(title:, details: nil, placeholder: nil, value: nil, &validator)
      new(title: title, details: details, placeholder: placeholder, value: value, validator: validator).ask
    end

    def initialize(title:, details: nil, placeholder: nil, value: nil, validator: nil)
      @prompt = Internal::TextInputPrompt.new(
        title: title, details: details, placeholder: placeholder, value: value, validator: validator, multiline: false
      )
    end

    def ask
      @prompt.ask
    end
  end
end
