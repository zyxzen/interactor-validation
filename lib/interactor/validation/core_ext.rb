# frozen_string_literal: true

module Interactor
  module Validation
    # Minimal core extensions - no external dependencies
    module CoreExt
      # Simple class attribute implementation with inheritance support
      def class_attribute(*names)
        names.each do |name|
          ivar_name = "@#{name}"

          # Class-level reader - checks own value, then parent
          define_singleton_method(name) do
            if instance_variable_defined?(ivar_name)
              instance_variable_get(ivar_name)
            elsif superclass.respond_to?(name)
              # When reading from parent, ensure we get our own copy first
              parent_value = superclass.public_send(name)
              # Deep copy parent value if it hasn't been set on this class yet
              if parent_value && !instance_variable_defined?(ivar_name)
                copied_value = deep_copy(parent_value)
                instance_variable_set(ivar_name, copied_value)
                copied_value
              else
                parent_value
              end
            end
          end

          # Class-level writer
          define_singleton_method("#{name}=") do |val|
            instance_variable_set(ivar_name, val)
          end

          # Instance-level reader delegates to class
          define_method(name) { self.class.public_send(name) }
        end
      end

      private

      def deep_copy(value)
        case value
        when Hash
          value.transform_values { |v| deep_copy(v) }
        when Array
          value.map { |v| deep_copy(v) }
        else
          # For immutable objects (Symbol, Integer, etc.) or simple objects, return as-is
          value.duplicable? ? value.dup : value
        end
      end

      # Simple delegation
      def delegate(*methods, to:)
        methods.each do |method|
          define_method(method) { |*args, &block| public_send(to).public_send(method, *args, &block) }
        end
      end
    end
  end
end

# Minimal Object extensions
class Object
  def present?
    !blank?
  end

  def blank?
    respond_to?(:empty?) ? empty? : false
  end
end

class NilClass
  def blank?
    true
  end
end

class FalseClass
  def blank?
    true
  end
end

class String
  def humanize
    tr("_.", " ").sub(/\A./, &:upcase)
  end
end

class Symbol
  def humanize
    to_s.humanize
  end

  def duplicable?
    false
  end
end

# Make immutable classes non-duplicable
[NilClass, FalseClass, TrueClass, Symbol, Numeric].each do |klass|
  klass.class_eval do
    def duplicable?
      false
    end
  end
end

class Object
  def duplicable?
    true
  end
end

class Module
  include Interactor::Validation::CoreExt
end
