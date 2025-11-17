# frozen_string_literal: true

module Interactor
  module Validation
    module Validators
      module Length
        def validate_length(param, value, rule)
          len = value.to_s.length

          if rule[:minimum] && len < rule[:minimum]
            msg = rule[:message] || "is too short (minimum is #{rule[:minimum]} characters)"
            errors.add(param, :too_short, message: msg, count: rule[:minimum])
          end

          if rule[:maximum] && len > rule[:maximum]
            msg = rule[:message] || "is too long (maximum is #{rule[:maximum]} characters)"
            errors.add(param, :too_long, message: msg, count: rule[:maximum])
          end

          if rule[:is] && len != rule[:is]
            msg = rule[:message] || "is the wrong length (should be #{rule[:is]} characters)"
            errors.add(param, :wrong_length, message: msg, count: rule[:is])
          end
        end
      end
    end
  end
end
