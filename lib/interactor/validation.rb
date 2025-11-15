# frozen_string_literal: true

require "interactor"
require "active_support/concern"
require "active_model"

require_relative "validation/version"
require_relative "validation/params"
require_relative "validation/validates"

module Interactor
  module Validation
    class Error < StandardError; end

    extend ActiveSupport::Concern

    included do
      include Params
      include Validates
    end

    def self.included(base)
      super
      # Set up the validation hook after all modules are included
      # Use class_eval to ensure we're in the right context
      base.class_eval do
        if respond_to?(:before)
          before :validate_params!
        end

        # Set up inherited hook to ensure child classes also get the before hook
        def self.inherited(subclass)
          super
          subclass.before :validate_params! if subclass.respond_to?(:before)
        end
      end
    end
  end
end
