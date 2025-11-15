# frozen_string_literal: true

module Interactor
  module Validation
    # rubocop:disable Metrics/ModuleLength
    module Validates
      extend ActiveSupport::Concern

      included do
        class_attribute :_param_validations, instance_writer: false, default: {}
        # Regex pattern cache for performance
        class_attribute :_regex_cache, instance_writer: false, default: {}
      end

      # Class-level mutex for thread-safe validation updates
      @validations_mutex = Mutex.new

      def self.validations_mutex
        @validations_mutex ||= Mutex.new
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
        # @param param_name [Symbol] the parameter name to validate
        # @param rules [Hash] validation rules (presence, format, length, etc.)
        # @yield [NestedValidationBuilder] optional block for nested validation DSL
        # @return [void]
        def validates(param_name, **rules, &)
          # Thread-safe validation rule updates
          Validates.validations_mutex.synchronize do
            # If block is provided, this is nested validation
            if block_given?
              nested_rules = build_nested_rules(&)
              current_validations = _param_validations.dup
              existing_rules = current_validations[param_name] || {}
              self._param_validations = current_validations.merge(
                param_name => existing_rules.merge(_nested: nested_rules)
              )
              return
            end

            # If no keyword arguments and no block, mark as skip validation
            if rules.empty?
              current_validations = _param_validations.dup
              existing_rules = current_validations[param_name] || {}
              self._param_validations = current_validations.merge(
                param_name => existing_rules.merge(_skip: true)
              )
              return
            end

            # Merge validation rules for the same param, ensuring we don't modify parent's hash
            current_validations = _param_validations.dup
            existing_rules = current_validations[param_name] || {}
            self._param_validations = current_validations.merge(param_name => existing_rules.merge(rules))
          end
        end

        private

        # Build nested validation rules from a block
        def build_nested_rules(&)
          builder = NestedValidationBuilder.new
          builder.instance_eval(&)
          builder.rules
        end
      end

      # Builder class for nested validation DSL
      class NestedValidationBuilder
        attr_reader :rules

        def initialize
          @rules = {}
        end

        # Define validation for a nested attribute
        def attribute(attr_name, **validations)
          @rules[attr_name] = validations
        end
      end

      private

      # Validates all declared parameters before execution
      # @return [void]
      # @raise [Interactor::Failure] if validation fails
      def validate_params!
        # Memoize config for performance
        @current_config = current_config

        # Instrument validation if enabled
        instrument("validate_params.interactor_validation") do
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
            break if @current_config.halt_on_first_error && errors.any?
          end

          return if errors.empty?

          context.fail!(errors: formatted_errors)
        end
      ensure
        @current_config = nil # Clear memoization
      end

      # Get the current configuration (instance config overrides global config)
      # @return [Configuration] the active configuration
      def current_config
        @current_config || self.class.validation_config || Interactor::Validation.configuration
      end

      # Instrument a block of code if instrumentation is enabled
      # @param event_name [String] the event name for ActiveSupport::Notifications
      # @yield the block to instrument
      # @return [Object] the return value of the block
      def instrument(event_name, &)
        if current_config.enable_instrumentation
          ActiveSupport::Notifications.instrument(event_name, interactor: self.class.name, &)
        else
          yield
        end
      end

      # Validates a single parameter with the given rules
      def validate_param(param_name, value, rules)
        # Skip validation if explicitly marked
        return if rules[:_skip]

        # Handle nested validation (hash or array)
        if rules[:_nested]
          validate_nested(param_name, value, rules[:_nested])
          return
        end

        # Standard validations
        validate_presence(param_name, value, rules)
        validate_boolean(param_name, value, rules)
        validate_format(param_name, value, rules)
        validate_length(param_name, value, rules)
        validate_inclusion(param_name, value, rules)
        validate_numericality(param_name, value, rules)
      end

      # Validates nested attributes in a hash or array
      def validate_nested(param_name, value, nested_rules)
        if value.is_a?(Array)
          validate_array_of_hashes(param_name, value, nested_rules)
        elsif value.is_a?(Hash)
          validate_hash_attributes(param_name, value, nested_rules)
        else
          # If value is not hash or array, add type error
          add_nested_error(param_name, nil, nil, :invalid_type)
        end
      end

      # Validates each hash in an array
      # @param param_name [Symbol] the parameter name
      # @param array [Array] the array of hashes to validate
      # @param nested_rules [Hash] validation rules for nested attributes
      # @return [void]
      def validate_array_of_hashes(param_name, array, nested_rules)
        # Memory protection: limit array size
        if array.size > current_config.max_array_size
          add_error(param_name, ErrorCodes::ARRAY_TOO_LARGE, :too_large,
                    count: current_config.max_array_size)
          return
        end

        array.each_with_index do |item, index|
          if item.is_a?(Hash)
            validate_hash_attributes(param_name, item, nested_rules, index: index)
          else
            add_nested_error(param_name, nil, nil, :invalid_type, index: index)
          end
        end
      end

      # Validates attributes within a hash
      # @param param_name [Symbol] the parameter name
      # @param hash [Hash] the hash containing attributes to validate
      # @param nested_rules [Hash] validation rules for each attribute
      # @param index [Integer, nil] optional array index for error messages
      # @return [void]
      def validate_hash_attributes(param_name, hash, nested_rules, index: nil)
        nested_rules.each do |attr_name, attr_rules|
          # Check both symbol and string keys, handling nil/false values and missing keys properly
          attr_value = get_nested_value(hash, attr_name)
          validate_nested_attribute(param_name, attr_name, attr_value, attr_rules, index: index)
        end
      end

      # Get nested value from hash, distinguishing between nil and missing keys
      # @param hash [Hash] the hash to search
      # @param attr_name [Symbol] the attribute name
      # @return [Object, Symbol] the value or :__missing__ sentinel
      def get_nested_value(hash, attr_name)
        if hash.key?(attr_name)
          hash[attr_name]
        elsif hash.key?(attr_name.to_s)
          hash[attr_name.to_s]
        else
          :__missing__ # Sentinel value to distinguish from nil
        end
      end

      # Validates a single nested attribute
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def validate_nested_attribute(param_name, attr_name, value, rules, index: nil)
        # Handle missing key sentinel
        is_missing = value == :__missing__
        value = nil if is_missing

        # Validate presence (false is a valid present value for booleans)
        if rules[:presence] && !value.present? && value != false
          message = extract_message(rules[:presence], :blank)
          add_nested_error(param_name, attr_name, message, :blank, index: index)
        end

        # Validate boolean (works on all values, not just present ones)
        # Don't validate boolean for missing keys (sentinel value)
        if rules[:boolean] && !is_missing && !boolean?(value)
          message = extract_message(rules[:boolean], :not_boolean)
          add_nested_error(param_name, attr_name, message, :not_boolean, index: index)
        end

        # Only run other validations if value is present (false is considered present for booleans)
        return unless value.present? || value == false

        # Validate format (with ReDoS protection)
        if rules[:format]
          format_options = rules[:format]
          pattern = format_options.is_a?(Hash) ? format_options[:with] : format_options

          # Safe regex matching with timeout protection
          unless safe_regex_match?(value.to_s, pattern)
            message = extract_message(format_options, :invalid)
            add_nested_error(param_name, attr_name, message, :invalid, index: index)
          end
        end

        # Validate length
        validate_nested_length(param_name, attr_name, value, rules[:length], index: index) if rules[:length]

        # Validate inclusion
        if rules[:inclusion]
          inclusion_options = rules[:inclusion]
          allowed_values = inclusion_options.is_a?(Hash) ? inclusion_options[:in] : inclusion_options
          unless allowed_values.include?(value)
            message = extract_message(inclusion_options, :inclusion)
            add_nested_error(param_name, attr_name, message, :inclusion, index: index)
          end
        end

        # Validate numericality
        return unless rules[:numericality]

        validate_nested_numericality(param_name, attr_name, value, rules[:numericality], index: index)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      # Validates length for nested attributes
      def validate_nested_length(param_name, attr_name, value, length_rules, index: nil)
        length = value.to_s.length

        if length_rules[:maximum] && length > length_rules[:maximum]
          message = extract_message(length_rules, :too_long, count: length_rules[:maximum])
          add_nested_error(param_name, attr_name, message, :too_long,
                           count: length_rules[:maximum], index: index)
        end

        if length_rules[:minimum] && length < length_rules[:minimum]
          message = extract_message(length_rules, :too_short, count: length_rules[:minimum])
          add_nested_error(param_name, attr_name, message, :too_short,
                           count: length_rules[:minimum], index: index)
        end

        return unless length_rules[:is] && length != length_rules[:is]

        message = extract_message(length_rules, :wrong_length, count: length_rules[:is])
        add_nested_error(param_name, attr_name, message, :wrong_length,
                         count: length_rules[:is], index: index)
      end

      # Validates numericality for nested attributes
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      def validate_nested_numericality(param_name, attr_name, value, numeric_rules, index: nil)
        numeric_rules = {} unless numeric_rules.is_a?(Hash)

        unless numeric?(value)
          message = extract_message(numeric_rules, :not_a_number)
          add_nested_error(param_name, attr_name, message, :not_a_number, index: index)
          return
        end

        numeric_value = coerce_to_numeric(value)

        if numeric_rules[:greater_than] && numeric_value <= numeric_rules[:greater_than]
          message = extract_message(numeric_rules, :greater_than, count: numeric_rules[:greater_than])
          add_nested_error(param_name, attr_name, message, :greater_than,
                           count: numeric_rules[:greater_than], index: index)
        end

        if numeric_rules[:greater_than_or_equal_to] && numeric_value < numeric_rules[:greater_than_or_equal_to]
          message = extract_message(numeric_rules, :greater_than_or_equal_to,
                                    count: numeric_rules[:greater_than_or_equal_to])
          add_nested_error(param_name, attr_name, message, :greater_than_or_equal_to,
                           count: numeric_rules[:greater_than_or_equal_to], index: index)
        end

        if numeric_rules[:less_than] && numeric_value >= numeric_rules[:less_than]
          message = extract_message(numeric_rules, :less_than, count: numeric_rules[:less_than])
          add_nested_error(param_name, attr_name, message, :less_than,
                           count: numeric_rules[:less_than], index: index)
        end

        if numeric_rules[:less_than_or_equal_to] && numeric_value > numeric_rules[:less_than_or_equal_to]
          message = extract_message(numeric_rules, :less_than_or_equal_to,
                                    count: numeric_rules[:less_than_or_equal_to])
          add_nested_error(param_name, attr_name, message, :less_than_or_equal_to,
                           count: numeric_rules[:less_than_or_equal_to], index: index)
        end

        return unless numeric_rules[:equal_to] && numeric_value != numeric_rules[:equal_to]

        message = extract_message(numeric_rules, :equal_to, count: numeric_rules[:equal_to])
        add_nested_error(param_name, attr_name, message, :equal_to,
                         count: numeric_rules[:equal_to], index: index)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

      # Add error for nested validation
      # rubocop:disable Metrics/ParameterLists
      def add_nested_error(param_name, attr_name, custom_message, error_type, index: nil, **interpolations)
        # Build the attribute path for the error
        attribute_path = if index.nil?
                           # Hash validation: param_name.attr_name
                           attr_name ? :"#{param_name}.#{attr_name}" : param_name
                         else
                           # Array validation: param_name[index].attr_name
                           attr_name ? :"#{param_name}[#{index}].#{attr_name}" : :"#{param_name}[#{index}]"
                         end

        if current_config.error_mode == :code
          # Code mode: use custom message or generate code
          code_message = custom_message || error_code_for(error_type, **interpolations)
          errors.add(attribute_path, code_message)
        elsif custom_message
          # Default mode: use ActiveModel's error messages with custom message
          errors.add(attribute_path, custom_message)
        else
          errors.add(attribute_path, error_type, **interpolations)
        end
      end
      # rubocop:enable Metrics/ParameterLists

      def validate_presence(param_name, value, rules)
        return unless rules[:presence]
        # For booleans, false is a valid present value
        return if value.present? || value == false

        message = extract_message(rules[:presence], :blank)
        add_error(param_name, message, :blank)
      end

      def validate_boolean(param_name, value, rules)
        return unless rules[:boolean]
        return if boolean?(value)

        message = extract_message(rules[:boolean], :not_boolean)
        add_error(param_name, message, :not_boolean)
      end

      def boolean?(value)
        [true, false].include?(value)
      end

      # Validates format using regex patterns with ReDoS protection
      # @param param_name [Symbol] the parameter name
      # @param value [Object] the value to validate
      # @param rules [Hash] validation rules containing :format
      # @return [void]
      def validate_format(param_name, value, rules)
        return unless rules[:format] && value.present?

        format_options = rules[:format]
        pattern = format_options.is_a?(Hash) ? format_options[:with] : format_options

        # Safe regex matching with timeout and caching
        return if safe_regex_match?(value.to_s, pattern)

        message = extract_message(format_options, :invalid)
        add_error(param_name, message, :invalid)
      end

      # Safely match a value against a regex pattern with timeout protection
      # @param value [String] the string to match
      # @param pattern [Regexp] the regex pattern
      # @return [Boolean] true if matches, false if no match or timeout
      def safe_regex_match?(value, pattern)
        # Get cached pattern if caching is enabled
        cached_pattern = current_config.cache_regex_patterns ? get_cached_regex(pattern) : pattern

        # Use Regexp.timeout if available (Ruby 3.2+)
        if Regexp.respond_to?(:timeout)
          begin
            Regexp.timeout = current_config.regex_timeout
            value.match?(cached_pattern)
          rescue Regexp::TimeoutError
            # Log timeout and treat as validation failure
            add_error(:regex, ErrorCodes::REGEX_TIMEOUT, :timeout) if errors.respond_to?(:add)
            false
          ensure
            Regexp.timeout = nil
          end
        else
          # Fallback for older Ruby versions - use Timeout module
          require "timeout"
          begin
            Timeout.timeout(current_config.regex_timeout) do
              value.match?(cached_pattern)
            end
          rescue Timeout::Error
            add_error(:regex, ErrorCodes::REGEX_TIMEOUT, :timeout) if errors.respond_to?(:add)
            false
          end
        end
      end

      # Get or cache a compiled regex pattern
      # @param pattern [Regexp] the pattern to cache
      # @return [Regexp] the cached pattern
      def get_cached_regex(pattern)
        cache_key = pattern.source
        self.class._regex_cache[cache_key] ||= pattern
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

      # Check if a value is numeric or can be coerced to numeric
      # @param value [Object] the value to check
      # @return [Boolean] true if numeric or numeric string
      def numeric?(value)
        value.is_a?(Numeric) || value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
      end

      # Coerce a value to numeric, preserving integer precision
      # @param value [Object] the value to coerce
      # @return [Numeric] integer or float depending on input
      def coerce_to_numeric(value)
        return value if value.is_a?(Numeric)

        str = value.to_s
        # Use to_i for integers to preserve precision, to_f for floats
        str.include?(".") ? str.to_f : str.to_i
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

      # Generate error code for :code mode using constants
      # @param error_type [Symbol] the type of validation error
      # @param interpolations [Hash] values to interpolate into the code
      # @return [String] the error code
      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
      def error_code_for(error_type, **interpolations)
        case error_type
        when :blank
          ErrorCodes::REQUIRED
        when :not_boolean
          ErrorCodes::MUST_BE_BOOLEAN
        when :invalid
          ErrorCodes::INVALID_FORMAT
        when :too_long
          ErrorCodes.exceeds_max_length(interpolations[:count])
        when :too_short
          ErrorCodes.below_min_length(interpolations[:count])
        when :wrong_length
          ErrorCodes.must_be_length(interpolations[:count])
        when :inclusion
          ErrorCodes::NOT_IN_ALLOWED_VALUES
        when :not_a_number
          ErrorCodes::MUST_BE_A_NUMBER
        when :greater_than
          ErrorCodes.must_be_greater_than(interpolations[:count])
        when :greater_than_or_equal_to
          ErrorCodes.must_be_at_least(interpolations[:count])
        when :less_than
          ErrorCodes.must_be_less_than(interpolations[:count])
        when :less_than_or_equal_to
          ErrorCodes.must_be_at_most(interpolations[:count])
        when :equal_to
          ErrorCodes.must_be_equal_to(interpolations[:count])
        when :invalid_type
          ErrorCodes::INVALID_TYPE
        when :too_large
          ErrorCodes::ARRAY_TOO_LARGE
        when :timeout
          ErrorCodes::REGEX_TIMEOUT
        else
          error_type.to_s.upcase
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

      # Formats errors into the expected structure
      def formatted_errors
        if current_config.error_mode == :code
          # Code mode: return structured error codes
          errors.map do |error|
            # Convert attribute path to uppercase, handling nested paths
            # Example: "attributes.username" -> "ATTRIBUTES.USERNAME"
            # Example: "attributes[0].username" -> "ATTRIBUTES[0].USERNAME"
            param_name = format_attribute_for_code(error.attribute)
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

      # Format attribute path for error code
      # @param attribute [Symbol] the attribute path (e.g., :"attributes.username" or :"attributes[0].username")
      # @return [String] formatted attribute path (e.g., "ATTRIBUTES_USERNAME" or "ATTRIBUTES[0]_USERNAME")
      def format_attribute_for_code(attribute)
        # Convert to string and uppercase
        attr_str = attribute.to_s.upcase
        # Replace dots with underscores, but preserve array indices
        # Example: "attributes[0].username" -> "ATTRIBUTES[0]_USERNAME"
        attr_str.gsub(/\.(?![^\[]*\])/, "_")
      end

      # Build a human-readable error message
      # @param error [ActiveModel::Error] the error object
      # @return [String] the formatted message
      def build_error_message(error)
        # For nested attributes (with dots or brackets), we can't use ActiveModel's message method
        # because it tries to call a method on the class which doesn't exist
        if error.attribute.to_s.include?(".") || error.attribute.to_s.include?("[")
          # Manually build message for nested attributes
          attribute_name = error.attribute.to_s.humanize
          error_message = error.options[:message] || default_message_for_type(error.type, error.options)
          "#{attribute_name} #{error_message}"
        elsif error.respond_to?(:message)
          # Try to use ActiveModel's message for simple attributes
          error.message
        end
      rescue ArgumentError, NoMethodError
        # Fallback for anonymous classes or other issues
        attribute_name = error.attribute.to_s.humanize
        error_message = error.options[:message] || default_message_for_type(error.type, error.options)
        "#{attribute_name} #{error_message}"
      end

      # Get default message for error type
      # @param type [Symbol] the error type
      # @param options [Hash] error options with interpolations
      # @return [String] the default message
      # rubocop:disable Metrics/MethodLength
      def default_message_for_type(type, options = {})
        case type
        when :blank
          "can't be blank"
        when :not_boolean
          "must be a boolean value"
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
        when :invalid_type
          "must be a Hash or Array"
        else
          "is invalid"
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
