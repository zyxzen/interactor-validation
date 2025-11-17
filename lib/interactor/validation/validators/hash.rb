# frozen_string_literal: true

module Interactor
  module Validation
    module Validators
      module Hash
        def validate_hash(param, value, nested_rules)
          return unless value.is_a?(::Hash)

          validate_nested_item(param, value, nested_rules)
        end

        private

        def validate_nested_item(param, item, nested_rules, index = nil)
          return unless item.is_a?(::Hash)

          nested_rules.each do |attr, attr_rules|
            attr_path = index.nil? ? "#{param}.#{attr}" : "#{param}[#{index}].#{attr}"
            attr_value = item[attr] || item[attr.to_s]
            validate_nested_attribute(attr_path.to_sym, attr_value, attr_rules)
          end
        end

        def validate_nested_attribute(attr_path, value, rules)
          if rules[:presence] && !value.present? && value != false
            msg = rules[:presence].is_a?(::Hash) ? rules[:presence][:message] : nil
            errors.add(attr_path, :blank, message: msg || "can't be blank")
          end

          return unless value.present? || value == false

          validate_format(attr_path, value, rules[:format]) if rules[:format]
          validate_length(attr_path, value, rules[:length]) if rules[:length]
          validate_inclusion(attr_path, value, rules[:inclusion]) if rules[:inclusion]
          validate_numeric(attr_path, value, rules[:numeric]) if rules[:numeric]
        end
      end
    end
  end
end
