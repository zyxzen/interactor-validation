# frozen_string_literal: true

module Interactor
  module Validation
    # Minimal error collection
    class Errors
      include Enumerable

      Error = Struct.new(:attribute, :type, :message, :options, keyword_init: true)

      def initialize
        @errors = []
      end

      def add(attribute, type = :invalid, message: nil, **options)
        @errors << Error.new(
          attribute: attribute,
          type: type,
          message: message || type.to_s,
          options: options
        )
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

      def each(&block)
        @errors.each(&block)
      end

      def to_a
        @errors.dup
      end
    end
  end
end
