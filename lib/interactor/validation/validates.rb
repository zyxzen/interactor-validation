# frozen_string_literal: true

require_relative "validators/presence"
require_relative "validators/numeric"
require_relative "validators/boolean"
require_relative "validators/format"
require_relative "validators/length"
require_relative "validators/inclusion"
require_relative "validators/hash"
require_relative "validators/array"

module Interactor
  module Validation
    module Validates
      def self.included(base)
        base.extend(ClassMethods)
        base.class_attribute :_validations
        base._validations = {}
        base.class_attribute :_validation_config
        base._validation_config = {}
        base.prepend(InstanceMethods)
      end

      class ConfigurationProxy
        def initialize(config_hash)
          @config = config_hash
        end

        def mode=(value)
          @config[:mode] = value
        end

        def halt=(value)
          @config[:halt] = value
        end

        def skip_validate=(value)
          @config[:skip_validate] = value
        end
      end

      module ClassMethods
        def inherited(subclass)
          super
          # Ensure child class gets its own copy of config, merging with parent's config
          subclass._validation_config = _validation_config.dup
          # Ensure child class gets its own copy of validations
          subclass._validations = _validations.dup
        end

        def validates(param_name, **rules, &)
          # Ensure we have our own copy of validations when first modifying
          self._validations = _validations.dup if _validations.equal?(superclass._validations) rescue false
          _validations[param_name] ||= {}
          _validations[param_name].merge!(rules)
          _validations[param_name][:_nested] = build_nested_rules(&) if block_given?
        end

        def configure
          # Ensure we have our own copy of config before modifying
          self._validation_config = _validation_config.dup if _validation_config.equal?(superclass._validation_config) rescue false
          config = ConfigurationProxy.new(_validation_config)
          yield(config)
        end

        def validation_halt(value)
          # Ensure we have our own copy of config before modifying
          self._validation_config = _validation_config.dup if _validation_config.equal?(superclass._validation_config) rescue false
          _validation_config[:halt] = value
        end

        def validation_mode(value)
          # Ensure we have our own copy of config before modifying
          self._validation_config = _validation_config.dup if _validation_config.equal?(superclass._validation_config) rescue false
          _validation_config[:mode] = value
        end

        private

        def build_nested_rules(&)
          builder = NestedBuilder.new
          builder.instance_eval(&)
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

          # Include all validator modules
          base.include(Validators::Presence)
          base.include(Validators::Numeric)
          base.include(Validators::Boolean)
          base.include(Validators::Format)
          base.include(Validators::Length)
          base.include(Validators::Inclusion)
          base.include(Validators::Hash)
          base.include(Validators::Array)
        end

        def errors
          @errors ||= Errors.new
        end

        def validate!
          errors.clear
          param_errors = false

          # Run parameter validations
          if self.class._validations
            self.class._validations.each do |param, rules|
              value = context.respond_to?(param) ? context.public_send(param) : nil
              validate_param(param, value, rules)

              # Halt on first error if configured
              if validation_config(:halt) && errors.any?
                context.fail!(errors: format_errors)
                return
              end
            end
            param_errors = errors.any?
          end

          # Call super to allow user-defined validate! to run
          # Skip if param validations failed and skip_validate is true
          super unless param_errors && validation_config(:skip_validate)

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
          validate_numeric(param, value, rules[:numeric] || rules[:numericality]) if rules[:numeric] || rules[:numericality]
        end

        def validate_nested(param, value, nested_rules)
          if value.is_a?(::Array)
            validate_array(param, value, nested_rules)
          elsif value.is_a?(::Hash)
            validate_hash(param, value, nested_rules)
          end
        end

        def validation_config(key)
          # Check per-interactor config first, then fall back to global config
          self.class._validation_config.key?(key) ? self.class._validation_config[key] : Interactor::Validation.configuration.public_send(key)
        end

        def format_errors
          case validation_config(:mode)
          when :code
            format_errors_as_code
          else
            format_errors_as_default
          end
        end

        def format_errors_as_default
          errors.map do |err|
            {
              attribute: err.attribute,
              type: err.type,
              message: "#{err.attribute.to_s.humanize} #{err.message}"
            }
          end
        end

        def format_errors_as_code
          errors.map do |err|
            { code: generate_error_code(err.attribute, err.type) }
          end
        end

        def generate_error_code(attribute, type)
          # Convert attribute to uppercase with underscores
          # Handle nested attributes: user.email → USER_EMAIL, items[0].name → ITEMS[0]_NAME
          code_attribute = attribute.to_s
                                    .gsub(/\[(\d+)\]\./, '[\\1]_')
                                    .gsub(".", "_")
                                    .upcase

          # Use "IS_REQUIRED" for blank errors, otherwise use type name
          code_type = type == :blank ? "IS_REQUIRED" : type.to_s.upcase

          "#{code_attribute}_#{code_type}"
        end
      end
    end
  end
end
