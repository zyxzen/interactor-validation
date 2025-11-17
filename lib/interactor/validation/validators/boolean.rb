# frozen_string_literal: true

module Interactor
  module Validation
    module Validators
      module Boolean
        def validate_boolean(param, value)
          return if [true, false].include?(value)

          errors.add(param, :invalid, message: "must be true or false")
        end
      end
    end
  end
end
