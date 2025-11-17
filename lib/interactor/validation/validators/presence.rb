# frozen_string_literal: true

module Interactor
  module Validation
    module Validators
      module Presence
        def validate_presence(param, value, rule)
          return if value.present? || value == false

          msg = rule.is_a?(::Hash) ? rule[:message] : nil
          errors.add(param, :blank, message: msg || "can't be blank")
        end
      end
    end
  end
end
