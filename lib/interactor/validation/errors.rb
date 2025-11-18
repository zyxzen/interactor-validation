# frozen_string_literal: true

module Interactor
  module Validation
    # Minimal error collection
    class Errors
      include Enumerable

      Error = Struct.new(:attribute, :type, :message, :options, keyword_init: true)

      def initialize(halt_checker: nil)
        @errors = []
        @halt_checker = halt_checker
      end

      def add(attribute, type = :invalid, message: nil, **options)
        @errors << Error.new(
          attribute: attribute,
          type: type,
          message: message || type.to_s,
          options: options
        )

        # Raise HaltValidation if halt is configured
        raise HaltValidation if @halt_checker&.call
      end

      def empty?
        @errors.empty?
      end

      def any?
        !empty?
      end

      def clear
        @errors.clear
      end

      def each(&)
        @errors.each(&)
      end

      def to_a
        @errors.dup
      end
    end
  end
end
