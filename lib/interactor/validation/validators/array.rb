# frozen_string_literal: true

module Interactor
  module Validation
    module Validators
      module Array
        def validate_array(param, value, nested_rules)
          return unless value.is_a?(::Array)

          value.each_with_index do |item, idx|
            validate_nested_item(param, item, nested_rules, idx)
          end
        end
      end
    end
  end
end
