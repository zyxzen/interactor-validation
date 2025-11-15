# frozen_string_literal: true

module Interactor
  module Validation
    module Params
      extend ActiveSupport::Concern

      included do
        class_attribute :_declared_params, instance_writer: false, default: []
      end

      class_methods do
        # Declares parameters that will be delegated from context
        # and registered for validation
        #
        # @param param_names [Array<Symbol>] the parameter names to declare
        # @example
        #   params :username, :password
        def params(*param_names)
          param_names.each do |param_name|
            # Ensure we're working with a copy to avoid modifying parent's array
            current_params = _declared_params.dup
            self._declared_params = current_params + [param_name] unless current_params.include?(param_name)

            # Delegate to context for easy access
            delegate param_name, to: :context
          end
        end
      end
    end
  end
end
