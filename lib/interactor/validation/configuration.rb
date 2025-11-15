# frozen_string_literal: true

module Interactor
  module Validation
    # Configuration class for interactor validation behavior
    class Configuration
      attr_accessor :halt_on_first_error, :regex_timeout, :max_array_size,
                    :enable_instrumentation, :cache_regex_patterns
      attr_reader :error_mode

      # Available error modes:
      # - :default - Uses ActiveModel-style human-readable messages [DEFAULT]
      # - :code - Returns structured error codes (e.g., USERNAME_IS_REQUIRED)
      def initialize
        @error_mode = :default
        @halt_on_first_error = false
        @regex_timeout = 0.1 # 100ms timeout for regex matching (ReDoS protection)
        @max_array_size = 1000 # Maximum array size for nested validation (memory protection)
        @enable_instrumentation = false # ActiveSupport::Notifications instrumentation
        @cache_regex_patterns = true # Cache compiled regex patterns for performance
      end

      def error_mode=(mode)
        raise ArgumentError, "Invalid error_mode: #{mode}. Must be :default or :code" unless %i[default code].include?(mode)

        @error_mode = mode
      end
    end

    class << self
      attr_writer :configuration

      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def reset_configuration!
        @configuration = Configuration.new
      end
    end
  end
end
