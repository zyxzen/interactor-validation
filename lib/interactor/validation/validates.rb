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
          # Clear errors at the start
          errors.clear

          # Run parameter validations first
          if self.class._validations
            self.class._validations.each do |param, rules|
              value = context.respond_to?(param) ? context.public_send(param) : nil
              validate_param(param, value, rules)

              # Halt on first error if configured
              if Interactor::Validation.configuration.halt && errors.any?
                context.fail!(errors: format_errors)
                return
              end
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
          validate_numeric(param, value, rules[:numeric]) if rules[:numeric]
          validate_numeric(param, value, rules[:numericality]) if rules[:numericality]
        end

        def validate_nested(param, value, nested_rules)
          if value.is_a?(::Array)
            validate_array(param, value, nested_rules)
          elsif value.is_a?(::Hash)
            validate_hash(param, value, nested_rules)
          end
        end

        def format_errors
          case Interactor::Validation.configuration.mode
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
            .gsub(/\[(\d+)\]\./, '[\\1]_')    # items[0].name → items[0]_name (bracket before dot)
            .gsub(".", "_")                    # user.email → user_email
            .upcase                            # → ITEMS[0]_NAME

          # Convert type to uppercase: blank → BLANK, invalid → INVALID
          code_type = type.to_s.upcase

          # For blank errors, use more semantic "IS_REQUIRED"
          code_type = "IS_REQUIRED" if type == :blank

          "#{code_attribute}_#{code_type}"
        end
      end
    end
  end
end
