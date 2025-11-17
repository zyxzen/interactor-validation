# frozen_string_literal: true

module Interactor
  module Validation
    module Validators
      module Format
        def validate_format(param, value, rule)
          pattern = rule.is_a?(::Hash) ? rule[:with] : rule
          return if value.to_s.match?(pattern)

          msg = rule.is_a?(::Hash) ? rule[:message] : nil
          errors.add(param, :invalid, message: msg || "is invalid")
        end
      end
    end
  end
end
