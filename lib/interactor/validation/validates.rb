# frozen_string_literal: true

module Interactor
  module Validation
    module Validates
      extend ActiveSupport::Concern

      included do
        class_attribute :_param_validations, instance_writer: false, default: {}
      end

      def self.included(base)
        super
        # Include ActiveModel::Validations first, then prepend our override
        base.include ActiveModel::Validations unless base.included_modules.include?(ActiveModel::Validations)
        base.singleton_class.prepend(ClassMethodsOverride)
      end

      module ClassMethodsOverride
        # Override ActiveModel's validates to handle our simple validation rules
        # Falls back to ActiveModel's validates for complex cases
        def validates(param_name, **rules)
          # If no keyword arguments, delegate to ActiveModel's validates
          return super(param_name) if rules.empty?

          # Merge validation rules for the same param, ensuring we don't modify parent's hash
          current_validations = _param_validations.dup
          existing_rules = current_validations[param_name] || {}
          self._param_validations = current_validations.merge(param_name => existing_rules.merge(rules))
        end
      end

      private

      # Validates all declared parameters before execution
      def validate_params!
        # Trigger ActiveModel validations first (validate callbacks)
        # This runs any custom validations defined with validate :method_name
        # NOTE: valid? must be called BEFORE adding our custom errors
        # because it clears the errors object
        valid?

        # Run our custom param validations after ActiveModel validations
        self.class._param_validations.each do |param_name, rules|
          value = context.public_send(param_name)
          validate_param(param_name, value, rules)
        end

        return if errors.empty?

        context.fail!(errors: formatted_errors)
      end

      # Validates a single parameter with the given rules
      def validate_param(param_name, value, rules)
        validate_presence(param_name, value, rules)
        validate_format(param_name, value, rules)
        validate_length(param_name, value, rules)
        validate_inclusion(param_name, value, rules)
        validate_numericality(param_name, value, rules)
      end

      def validate_presence(param_name, value, rules)
        return unless rules[:presence]
        return if value.present?

        errors.add(param_name, 'IS_REQUIRED')
      end

      def validate_format(param_name, value, rules)
        return unless rules[:format] && value.present?

        format_options = rules[:format]
        pattern = format_options.is_a?(Hash) ? format_options[:with] : format_options
        return if value.to_s.match?(pattern)

        # Get custom message from format options or use default
        message = format_options.is_a?(Hash) ? format_options[:message] : nil
        errors.add(param_name, message || 'INVALID_FORMAT')
      end

      def validate_length(param_name, value, rules)
        return unless rules[:length] && value.present?

        length_rules = rules[:length]
        length = value.to_s.length

        if length_rules[:maximum] && length > length_rules[:maximum]
          errors.add(param_name, "EXCEEDS_MAX_LENGTH_#{length_rules[:maximum]}")
        end

        if length_rules[:minimum] && length < length_rules[:minimum]
          errors.add(param_name, "BELOW_MIN_LENGTH_#{length_rules[:minimum]}")
        end

        if length_rules[:is] && length != length_rules[:is]
          errors.add(param_name, "MUST_BE_LENGTH_#{length_rules[:is]}")
        end
      end

      def validate_inclusion(param_name, value, rules)
        return unless rules[:inclusion] && value.present?

        allowed_values = rules[:inclusion].is_a?(Hash) ? rules[:inclusion][:in] : rules[:inclusion]
        return if allowed_values.include?(value)

        errors.add(param_name, 'NOT_IN_ALLOWED_VALUES')
      end

      def validate_numericality(param_name, value, rules)
        return unless rules[:numericality] && value.present?

        numeric_rules = rules[:numericality].is_a?(Hash) ? rules[:numericality] : {}

        unless numeric?(value)
          errors.add(param_name, 'MUST_BE_A_NUMBER')
          return
        end

        numeric_value = coerce_to_numeric(value)
        validate_numeric_constraints(param_name, numeric_value, numeric_rules)
      end

      def numeric?(value)
        value.is_a?(Numeric) || value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
      end

      def coerce_to_numeric(value)
        value.is_a?(Numeric) ? value : value.to_s.to_f
      end

      def validate_numeric_constraints(param_name, value, rules)
        if rules[:greater_than] && value <= rules[:greater_than]
          errors.add(param_name, "MUST_BE_GREATER_THAN_#{rules[:greater_than]}")
        end

        if rules[:greater_than_or_equal_to] && value < rules[:greater_than_or_equal_to]
          errors.add(param_name, "MUST_BE_AT_LEAST_#{rules[:greater_than_or_equal_to]}")
        end

        if rules[:less_than] && value >= rules[:less_than]
          errors.add(param_name, "MUST_BE_LESS_THAN_#{rules[:less_than]}")
        end

        if rules[:less_than_or_equal_to] && value > rules[:less_than_or_equal_to]
          errors.add(param_name, "MUST_BE_AT_MOST_#{rules[:less_than_or_equal_to]}")
        end

        if rules[:equal_to] && value != rules[:equal_to]
          errors.add(param_name, "MUST_BE_EQUAL_TO_#{rules[:equal_to]}")
        end
      end

      # Formats errors into the expected structure
      def formatted_errors
        errors.map do |error|
          param_name = error.attribute.to_s.upcase
          message = error.message

          { code: "#{param_name}_#{message}" }
        end
      end
    end
  end
end
