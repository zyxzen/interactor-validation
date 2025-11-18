# frozen_string_literal: true

module Interactor
  module Validation
    module Validators
      module Length
        def validate_length(param, value, rule)
          # Use .length for collections (Array/Hash), .to_s.length for other types
          len = value.respond_to?(:length) && !value.is_a?(String) ? value.length : value.to_s.length
          unit = collection?(value) ? "items" : "characters"

          validate_minimum_length(param, len, rule[:minimum], unit, rule[:message]) if rule[:minimum]
          validate_maximum_length(param, len, rule[:maximum], unit, rule[:message]) if rule[:maximum]
          validate_exact_length(param, len, rule[:is], unit, rule[:message]) if rule[:is]
        end

        private

        def collection?(value)
          (value.is_a?(::Array) || value.is_a?(::Hash)) && !value.is_a?(String)
        end

        def validate_minimum_length(param, len, minimum, unit, custom_message)
          return unless len < minimum

          msg = custom_message || "is too short (minimum is #{minimum} #{unit})"
          errors.add(param, :too_short, message: msg, count: minimum)
        end

        def validate_maximum_length(param, len, maximum, unit, custom_message)
          return unless len > maximum

          msg = custom_message || "is too long (maximum is #{maximum} #{unit})"
          errors.add(param, :too_long, message: msg, count: maximum)
        end

        def validate_exact_length(param, len, exact, unit, custom_message)
          return unless len != exact

          msg = custom_message || "is the wrong length (should be #{exact} #{unit})"
          errors.add(param, :wrong_length, message: msg, count: exact)
        end
      end
    end
  end
end
