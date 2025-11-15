# frozen_string_literal: true

module Interactor
  module Validation
    # Configuration class for interactor validation behavior
    class Configuration
      attr_accessor :halt_on_first_error
      attr_reader :error_mode

      # Available error modes:
      # - :default - Uses ActiveModel-style human-readable messages
      # - :code - Returns structured error codes (e.g., USERNAME_IS_REQUIRED) [DEFAULT]
      def initialize
        @error_mode = :code
        @halt_on_first_error = false
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
