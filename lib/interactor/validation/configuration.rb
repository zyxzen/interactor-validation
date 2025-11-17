# frozen_string_literal: true

module Interactor
  module Validation
    # Configuration class for interactor validation behavior
    class Configuration
      attr_accessor :skip_validate, :mode

      def initialize
        @skip_validate = true # Skip validate! hook if validate_params! has errors
        @mode = :default # Error message format mode (:default or :code)
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
    end
  end
end
