# frozen_string_literal: true

require "interactor"
require "active_support/concern"
require "active_model"

require_relative "validation/version"
require_relative "validation/configuration"
require_relative "validation/error_codes"
require_relative "validation/params"
require_relative "validation/validates"

module Interactor
  module Validation
    class Error < StandardError; end

    extend ActiveSupport::Concern

    included do
      include Params
      include Validates

      # Instance-level configuration (can override global config)
      class_attribute :validation_config, instance_writer: false, default: nil
    end

    class_methods do
      # Configure validation behavior for this interactor class
      # @example
      #   configure_validation do |config|
      #     config.error_mode = :code
      #   end
      def configure_validation
        self.validation_config ||= Configuration.new
        yield(validation_config)
      end
    end

    def self.included(base)
      super
      # Set up the validation hook after all modules are included
      # Use class_eval to ensure we're in the right context
      base.class_eval do
        before :validate_params! if respond_to?(:before)

        # Set up inherited hook to ensure child classes also get the before hook
        def self.inherited(subclass)
          super
          subclass.before :validate_params! if subclass.respond_to?(:before)
        end
      end
    end
  end
end
