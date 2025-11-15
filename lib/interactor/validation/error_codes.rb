# frozen_string_literal: true

module Interactor
  module Validation
    # Error code constants for structured error messages
    module ErrorCodes
      REQUIRED = "IS_REQUIRED"
      MUST_BE_BOOLEAN = "MUST_BE_BOOLEAN"
      INVALID_FORMAT = "INVALID_FORMAT"
      NOT_IN_ALLOWED_VALUES = "NOT_IN_ALLOWED_VALUES"
      MUST_BE_A_NUMBER = "MUST_BE_A_NUMBER"
      INVALID_TYPE = "INVALID_TYPE"
      REGEX_TIMEOUT = "REGEX_TIMEOUT"
      ARRAY_TOO_LARGE = "ARRAY_TOO_LARGE"

      # Generate length error codes
      def self.exceeds_max_length(count)
        "EXCEEDS_MAX_LENGTH_#{count}"
      end

      def self.below_min_length(count)
        "BELOW_MIN_LENGTH_#{count}"
      end

      def self.must_be_length(count)
        "MUST_BE_LENGTH_#{count}"
      end

      # Generate numeric comparison error codes
      def self.must_be_greater_than(count)
        "MUST_BE_GREATER_THAN_#{count}"
      end

      def self.must_be_at_least(count)
        "MUST_BE_AT_LEAST_#{count}"
      end

      def self.must_be_less_than(count)
        "MUST_BE_LESS_THAN_#{count}"
      end

      def self.must_be_at_most(count)
        "MUST_BE_AT_MOST_#{count}"
      end

      def self.must_be_equal_to(count)
        "MUST_BE_EQUAL_TO_#{count}"
      end
    end
  end
end
