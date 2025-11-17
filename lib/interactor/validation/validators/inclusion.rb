# frozen_string_literal: true

module Interactor
  module Validation
    module Validators
      module Inclusion
        def validate_inclusion(param, value, rule)
          allowed = rule.is_a?(::Hash) ? rule[:in] : rule
          return if allowed.include?(value)

          msg = rule.is_a?(::Hash) ? rule[:message] : nil
          errors.add(param, :inclusion, message: msg || "is not included in the list")
        end
      end
    end
  end
end
