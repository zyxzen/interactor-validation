# frozen_string_literal: true

module Interactor
  module Validation
    module Validators
      module Numeric
        def validate_numeric(param, value, rule)
          unless numeric?(value)
            msg = rule.is_a?(::Hash) ? rule[:message] : nil
            errors.add(param, :not_a_number, message: msg || "is not a number")
            return
          end

          num = coerce_numeric(value)
          rule = {} unless rule.is_a?(::Hash)

          check_numeric_constraint(param, num, :greater_than, rule) { |n, v| n <= v }
          check_numeric_constraint(param, num, :greater_than_or_equal_to, rule) { |n, v| n < v }
          check_numeric_constraint(param, num, :less_than, rule) { |n, v| n >= v }
          check_numeric_constraint(param, num, :less_than_or_equal_to, rule) { |n, v| n > v }
          check_numeric_constraint(param, num, :equal_to, rule) { |n, v| n != v }
        end

        private

        def check_numeric_constraint(param, num, type, rule)
          return unless rule[type]
          return unless yield(num, rule[type])

          msg = rule[:message] || "must be #{type.to_s.tr("_", " ")} #{rule[type]}"
          errors.add(param, type, message: msg, count: rule[type])
        end

        def numeric?(value)
          value.is_a?(::Numeric) || value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
        end

        def coerce_numeric(value)
          return value if value.is_a?(::Numeric)

          value.to_s.include?(".") ? value.to_f : value.to_i
        end
      end
    end
  end
end
