# frozen_string_literal: true

module Interactor
  module Validation
    module Params
      def self.included(base)
        base.extend(ClassMethods)
        base.class_attribute :_declared_params
        base._declared_params = []
      end

      module ClassMethods
        def params(*param_names)
          param_names.each do |param_name|
            _declared_params << param_name unless _declared_params.include?(param_name)
            delegate param_name, to: :context
          end
        end
      end
    end
  end
end
