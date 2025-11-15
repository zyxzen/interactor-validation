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
          # Safe param access - returns nil if not present in context
          value = context.respond_to?(param_name) ? context.public_send(param_name) : nil
          validate_param(param_name, value, rules)

          # Halt on first error if configured
          break if current_config.halt_on_first_error && errors.any?
        end

        return if errors.empty?

        context.fail!(errors: formatted_errors)
      end

      # Get the current configuration (instance config overrides global config)
      def current_config
        self.class.validation_config || Interactor::Validation.configuration
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

        message = extract_message(rules[:presence], :blank)
        add_error(param_name, message, :blank)
      end

      def validate_format(param_name, value, rules)
        return unless rules[:format] && value.present?

        format_options = rules[:format]
        pattern = format_options.is_a?(Hash) ? format_options[:with] : format_options
        return if value.to_s.match?(pattern)

        message = extract_message(format_options, :invalid)
        add_error(param_name, message, :invalid)
      end

      def validate_length(param_name, value, rules)
        return unless rules[:length] && value.present?

        length_rules = rules[:length]
        length = value.to_s.length

        if length_rules[:maximum] && length > length_rules[:maximum]
          message = extract_message(length_rules, :too_long, count: length_rules[:maximum])
          add_error(param_name, message, :too_long, count: length_rules[:maximum])
        end

        if length_rules[:minimum] && length < length_rules[:minimum]
          message = extract_message(length_rules, :too_short, count: length_rules[:minimum])
          add_error(param_name, message, :too_short, count: length_rules[:minimum])
        end

        return unless length_rules[:is] && length != length_rules[:is]

        message = extract_message(length_rules, :wrong_length, count: length_rules[:is])
        add_error(param_name, message, :wrong_length, count: length_rules[:is])
      end

      def validate_inclusion(param_name, value, rules)
        return unless rules[:inclusion] && value.present?

        inclusion_options = rules[:inclusion]
        allowed_values = inclusion_options.is_a?(Hash) ? inclusion_options[:in] : inclusion_options
        return if allowed_values.include?(value)

        message = extract_message(inclusion_options, :inclusion)
        add_error(param_name, message, :inclusion)
      end

      def validate_numericality(param_name, value, rules)
        return unless rules[:numericality] && value.present?

        numeric_rules = rules[:numericality].is_a?(Hash) ? rules[:numericality] : {}

        unless numeric?(value)
          message = extract_message(numeric_rules, :not_a_number)
          add_error(param_name, message, :not_a_number)
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
          message = extract_message(rules, :greater_than, count: rules[:greater_than])
          add_error(param_name, message, :greater_than, count: rules[:greater_than])
        end

        if rules[:greater_than_or_equal_to] && value < rules[:greater_than_or_equal_to]
          message = extract_message(rules, :greater_than_or_equal_to, count: rules[:greater_than_or_equal_to])
          add_error(param_name, message, :greater_than_or_equal_to, count: rules[:greater_than_or_equal_to])
        end

        if rules[:less_than] && value >= rules[:less_than]
          message = extract_message(rules, :less_than, count: rules[:less_than])
          add_error(param_name, message, :less_than, count: rules[:less_than])
        end

        if rules[:less_than_or_equal_to] && value > rules[:less_than_or_equal_to]
          message = extract_message(rules, :less_than_or_equal_to, count: rules[:less_than_or_equal_to])
          add_error(param_name, message, :less_than_or_equal_to, count: rules[:less_than_or_equal_to])
        end

        return unless rules[:equal_to] && value != rules[:equal_to]

        message = extract_message(rules, :equal_to, count: rules[:equal_to])
        add_error(param_name, message, :equal_to, count: rules[:equal_to])
      end

      # Extract custom message from validation options
      # @param options [Hash, Boolean] validation options
      # @param error_type [Symbol] the type of error
      # @param interpolations [Hash] values to interpolate into message
      # @return [String, nil] custom message if provided
      def extract_message(options, _error_type, **_interpolations)
        return nil unless options.is_a?(Hash)

        options[:message]
      end

      # Add an error with proper formatting based on error mode
      # @param param_name [Symbol] the parameter name
      # @param custom_message [String, nil] custom error message if provided
      # @param error_type [Symbol] the type of validation error
      # @param interpolations [Hash] values to interpolate into the message
      def add_error(param_name, custom_message, error_type, **interpolations)
        if current_config.error_mode == :code
          # Code mode: use custom message or generate code
          code_message = custom_message || error_code_for(error_type, **interpolations)
          errors.add(param_name, code_message)
        elsif custom_message
          # Default mode: use ActiveModel's error messages
          errors.add(param_name, custom_message)
        else
          errors.add(param_name, error_type, **interpolations)
        end
      end

      # Generate error code for :code mode
      # @param error_type [Symbol] the type of validation error
      # @param interpolations [Hash] values to interpolate into the code
      # @return [String] the error code
      def error_code_for(error_type, **interpolations)
        case error_type
        when :blank
          "IS_REQUIRED"
        when :invalid
          "INVALID_FORMAT"
        when :too_long
          "EXCEEDS_MAX_LENGTH_#{interpolations[:count]}"
        when :too_short
          "BELOW_MIN_LENGTH_#{interpolations[:count]}"
        when :wrong_length
          "MUST_BE_LENGTH_#{interpolations[:count]}"
        when :inclusion
          "NOT_IN_ALLOWED_VALUES"
        when :not_a_number
          "MUST_BE_A_NUMBER"
        when :greater_than
          "MUST_BE_GREATER_THAN_#{interpolations[:count]}"
        when :greater_than_or_equal_to
          "MUST_BE_AT_LEAST_#{interpolations[:count]}"
        when :less_than
          "MUST_BE_LESS_THAN_#{interpolations[:count]}"
        when :less_than_or_equal_to
          "MUST_BE_AT_MOST_#{interpolations[:count]}"
        when :equal_to
          "MUST_BE_EQUAL_TO_#{interpolations[:count]}"
        else
          error_type.to_s.upcase
        end
      end

      # Formats errors into the expected structure
      def formatted_errors
        if current_config.error_mode == :code
          # Code mode: return structured error codes
          errors.map do |error|
            param_name = error.attribute.to_s.upcase
            message = error.message

            { code: "#{param_name}_#{message}" }
          end
        else
          # Default mode: return ActiveModel-style errors
          errors.map do |error|
            # Build a human-readable message manually to avoid anonymous class issues
            message = build_error_message(error)
            {
              attribute: error.attribute,
              type: error.type,
              message: message
            }
          end
        end
      end

      # Build a human-readable error message
      # @param error [ActiveModel::Error] the error object
      # @return [String] the formatted message
      def build_error_message(error)
        # Try to use ActiveModel's message first
        error.message if error.respond_to?(:message)
      rescue ArgumentError
        # Fallback for anonymous classes or other issues
        attribute_name = error.attribute.to_s.humanize
        error_message = error.options[:message] || default_message_for_type(error.type, error.options)
        "#{attribute_name} #{error_message}"
      end

      # Get default message for error type
      # @param type [Symbol] the error type
      # @param options [Hash] error options with interpolations
      # @return [String] the default message
      def default_message_for_type(type, options = {})
        case type
        when :blank
          "can't be blank"
        when :invalid
          "is invalid"
        when :too_long
          "is too long (maximum is #{options[:count]} characters)"
        when :too_short
          "is too short (minimum is #{options[:count]} characters)"
        when :wrong_length
          "is the wrong length (should be #{options[:count]} characters)"
        when :inclusion
          "is not included in the list"
        when :not_a_number
          "is not a number"
        when :greater_than
          "must be greater than #{options[:count]}"
        when :greater_than_or_equal_to
          "must be greater than or equal to #{options[:count]}"
        when :less_than
          "must be less than #{options[:count]}"
        when :less_than_or_equal_to
          "must be less than or equal to #{options[:count]}"
        when :equal_to
          "must be equal to #{options[:count]}"
        else
          "is invalid"
        end
      end
    end
  end
end
