# frozen_string_literal: true

module Interactor
  module Validation
    module Validates
      def self.included(base)
        base.extend(ClassMethods)
        base.class_attribute :_validations
        base._validations = {}
        base.prepend(InstanceMethods)
      end

      module ClassMethods
        def validates(param_name, **rules, &block)
          self._validations ||= {}
          _validations[param_name] ||= {}
          _validations[param_name].merge!(rules)
          _validations[param_name][:_nested] = build_nested_rules(&block) if block_given?
        end

        private

        def build_nested_rules(&block)
          builder = NestedBuilder.new
          builder.instance_eval(&block)
          builder.rules
        end
      end

      class NestedBuilder
        attr_reader :rules

        def initialize
          @rules = {}
        end

        def attribute(name, **validations)
          @rules[name] = validations
        end
      end

      # Base module with default validate! that does nothing
      module BaseValidation
        def validate!
          # Default implementation - does nothing
          # Subclasses can override and call super
        end
      end

      module InstanceMethods
        def self.prepended(base)
          # Include BaseValidation so super works in user's validate!
          base.include(BaseValidation) unless base.ancestors.include?(BaseValidation)
        end

        def errors
          @errors ||= Errors.new
        end

        def validate!
          # Clear errors at the start
          errors.clear

          # Run parameter validations first
          if self.class._validations
            self.class._validations.each do |param, rules|
              value = context.respond_to?(param) ? context.public_send(param) : nil
              validate_param(param, value, rules)
            end
          end

          # Call super to allow user-defined validate! to run
          super

          # Fail context if any errors exist
          context.fail!(errors: format_errors) if errors.any?
        end

        private

        def validate_param(param, value, rules)
          # Handle nested validation
          if rules[:_nested]
            validate_presence(param, value, rules[:presence]) if rules[:presence]
            validate_nested(param, value, rules[:_nested]) if value.present?
            return
          end

          # Standard validations
          validate_presence(param, value, rules[:presence]) if rules[:presence]
          return unless value.present?

          validate_boolean(param, value) if rules[:boolean]
          validate_format(param, value, rules[:format]) if rules[:format]
          validate_length(param, value, rules[:length]) if rules[:length]
          validate_inclusion(param, value, rules[:inclusion]) if rules[:inclusion]
          validate_numericality(param, value, rules[:numericality]) if rules[:numericality]
        end

        def validate_presence(param, value, rule)
          return if value.present? || value == false

          msg = rule.is_a?(Hash) ? rule[:message] : nil
          errors.add(param, :blank, message: msg || "can't be blank")
        end

        def validate_boolean(param, value)
          return if [true, false].include?(value)

          errors.add(param, :invalid, message: "must be true or false")
        end

        def validate_format(param, value, rule)
          pattern = rule.is_a?(Hash) ? rule[:with] : rule
          return if value.to_s.match?(pattern)

          msg = rule.is_a?(Hash) ? rule[:message] : nil
          errors.add(param, :invalid, message: msg || "is invalid")
        end

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

        def validate_inclusion(param, value, rule)
          allowed = rule.is_a?(Hash) ? rule[:in] : rule
          return if allowed.include?(value)

          msg = rule.is_a?(Hash) ? rule[:message] : nil
          errors.add(param, :inclusion, message: msg || "is not included in the list")
        end

        def validate_numericality(param, value, rule)
          unless numeric?(value)
            msg = rule.is_a?(Hash) ? rule[:message] : nil
            errors.add(param, :not_a_number, message: msg || "is not a number")
            return
          end

          num = coerce_numeric(value)
          rule = {} unless rule.is_a?(Hash)

          check_numeric_constraint(param, num, :greater_than, rule) { |n, v| n <= v }
          check_numeric_constraint(param, num, :greater_than_or_equal_to, rule) { |n, v| n < v }
          check_numeric_constraint(param, num, :less_than, rule) { |n, v| n >= v }
          check_numeric_constraint(param, num, :less_than_or_equal_to, rule) { |n, v| n > v }
          check_numeric_constraint(param, num, :equal_to, rule) { |n, v| n != v }
        end

        def check_numeric_constraint(param, num, type, rule)
          return unless rule[type]
          return unless yield(num, rule[type])

          msg = rule[:message] || "must be #{type.to_s.tr("_", " ")} #{rule[type]}"
          errors.add(param, type, message: msg, count: rule[type])
        end

        def numeric?(value)
          value.is_a?(Numeric) || value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
        end

        def coerce_numeric(value)
          return value if value.is_a?(Numeric)

          value.to_s.include?(".") ? value.to_f : value.to_i
        end

        def validate_nested(param, value, nested_rules)
          if value.is_a?(Array)
            value.each_with_index do |item, idx|
              validate_nested_item(param, item, nested_rules, idx)
            end
          elsif value.is_a?(Hash)
            validate_nested_item(param, value, nested_rules)
          end
        end

        def validate_nested_item(param, item, nested_rules, index = nil)
          return unless item.is_a?(Hash)

          nested_rules.each do |attr, attr_rules|
            attr_path = index.nil? ? "#{param}.#{attr}" : "#{param}[#{index}].#{attr}"
            attr_value = item[attr] || item[attr.to_s]
            validate_nested_attribute(attr_path.to_sym, attr_value, attr_rules)
          end
        end

        def validate_nested_attribute(attr_path, value, rules)
          if rules[:presence] && !value.present? && value != false
            msg = rules[:presence].is_a?(Hash) ? rules[:presence][:message] : nil
            errors.add(attr_path, :blank, message: msg || "can't be blank")
          end

          return unless value.present? || value == false

          validate_format(attr_path, value, rules[:format]) if rules[:format]
          validate_length(attr_path, value, rules[:length]) if rules[:length]
          validate_inclusion(attr_path, value, rules[:inclusion]) if rules[:inclusion]
          validate_numericality(attr_path, value, rules[:numericality]) if rules[:numericality]
        end

        def format_errors
          errors.map do |err|
            {
              attribute: err.attribute,
              type: err.type,
              message: "#{err.attribute.to_s.humanize} #{err.message}"
            }
          end
        end
      end
    end
  end
end
