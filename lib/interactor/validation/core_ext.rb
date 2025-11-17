# frozen_string_literal: true

module Interactor
  module Validation
    # Minimal core extensions - no external dependencies
    module CoreExt
      # Simple class attribute implementation
      def class_attribute(*names)
        names.each do |name|
          # Class-level reader/writer
          define_singleton_method(name) { instance_variable_get("@#{name}") }
          define_singleton_method("#{name}=") { |val| instance_variable_set("@#{name}", val) }

          # Instance-level reader delegates to class
          define_method(name) { self.class.public_send(name) }
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
    respond_to?(:empty?) ? !!empty? : !self
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

class TrueClass
  def blank?
    false
  end
end

class Numeric
  def blank?
    false
  end
end

class String
  def humanize
    tr("_.", " ").sub(/\A./) { |char| char.upcase }
  end
end

class Symbol
  def humanize
    to_s.humanize
  end
end

class Module
  include Interactor::Validation::CoreExt
end
