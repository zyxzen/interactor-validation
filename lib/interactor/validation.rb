# frozen_string_literal: true

require "interactor"
require_relative "validation/core_ext"
require_relative "validation/errors"
require_relative "validation/params"
require_relative "validation/validates"
require_relative "validation/version"

module Interactor
  module Validation
    def self.included(base)
      base.include Params
      base.include Validates
      base.before :validate! if base.respond_to?(:before)
    end
  end
end
