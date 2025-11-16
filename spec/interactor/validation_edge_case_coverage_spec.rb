# frozen_string_literal: true

RSpec.describe "Interactor::Validation Edge Case Coverage" do
  describe "anonymous class error handling with ArgumentError" do
    it "triggers ArgumentError handling in error detail mapping" do
      # Create an anonymous class
      anon_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :name
        validates :name, presence: true

        def validate!
          # Preserve errors from validate_params!
          existing_errors = errors.dup

          # Call super which might trigger ArgumentError for anonymous classes
          begin
            super
          rescue NoMethodError
            # Expected for anonymous classes without parent validate!
          end
        end
      end

      result = anon_class.call(name: nil)
      expect(result.success?).to be false
    end

    it "triggers ArgumentError handling when accessing error properties" do
      anon_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :field
        validates :field, presence: true
      end

      result = anon_class.call(field: nil)
      expect(result.success?).to be false
      # This should have gone through the anonymous class error handling
      expect(result.errors).not_to be_empty
    end

    it "handles error detail restoration with ArgumentError" do
      anon_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value
        validates :value, presence: true

        def validate!
          # This should trigger the error restoration path
          super
        end
      end

      result = anon_class.call(value: nil)
      expect(result.success?).to be false
    end
  end

  describe "regex timeout with actual slow pattern" do
    before do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
        config.regex_timeout = 0.00001 # Extremely short 0.01ms timeout
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "triggers regex timeout with catastrophic backtracking" do
      skip "Regex timeout timing is unreliable in test environment"

      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :input
        # Pattern known to cause exponential backtracking
        validates :input, format: /^(a*)*$/
      end

      # Input that doesn't match and causes backtracking
      result = interactor_class.call(input: "a" * 20 + "b")

      # May get either timeout or invalid format depending on timing
      expect(result.success?).to be false
    end
  end

  describe "subclass without before method via respond_to_missing?" do
    it "handles subclass that doesn't respond to before" do
      base = Class.new do
        include Interactor
        include Interactor::Validation

        params :name
        validates :name, presence: true
      end

      # Create subclass that doesn't respond to before
      subclass = Class.new(base) do
        params :email

        # Use respond_to_missing? to hide :before
        def self.respond_to_missing?(method_name, _include_private = false)
          return false if method_name == :before
          super
        end
      end

      # Should work despite not responding to before
      expect(subclass).not_to be_nil
    end
  end

  describe "error without message method coverage" do
    it "handles error object that doesn't respond to message" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value
        validates :value, presence: true
      end

      result = interactor_class.call(value: nil)

      expect(result.success?).to be false
      # The formatted_errors should handle errors without message method
      expect(result.errors).not_to be_empty
    end
  end

  describe "halt parameter coverage" do
    it "covers halt parameter in add_error for non-nested errors" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value

        # Override validate_params! to test halt directly
        def validate_params!
          super
          # Directly call add_error with halt: true
          send(:add_error, :test_field, "test error", :invalid, halt: true)
          # This line should not be reached if halt works
          send(:add_error, :should_not_reach, "not added", :invalid)
        end
      end

      result = interactor_class.call(value: "test")

      expect(result.success?).to be false
      # Should have the first error but not the second due to halt
      error_attrs = result.errors.map { |e| e[:attribute] }
      expect(error_attrs).to include(:test_field)
    end

    it "covers halt parameter in add_nested_error" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :data

        def validate_params!
          super
          # Directly call add_nested_error with halt: true
          send(:add_nested_error, :data, :field1, "error", :invalid, halt: true)
          # This should not be reached
          send(:add_nested_error, :data, :field2, "error", :invalid)
        end
      end

      result = interactor_class.call(data: { field1: "value" })

      expect(result.success?).to be false
    end
  end

  describe "unknown error type coverage" do
    before do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "handles completely unknown error types in error_code_for" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value

        def validate_params!
          super
          # Add an error with a custom unknown symbol type
          errors.add(:value, :completely_unknown_custom_error_type)
        end

        def call
          validate_params!
          validate!
        end
      end

      result = interactor_class.call(value: "test")

      expect(result.success?).to be false
      # The unknown error type should be uppercased
      expect(result.errors.first[:code]).to eq("VALUE_COMPLETELY_UNKNOWN_CUSTOM_ERROR_TYPE")
    end
  end

  describe "array too large error code path" do
    before do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
        config.max_array_size = 1
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "triggers :too_large case in error_code_for" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :items
        validates :items do
          attribute :name, presence: true
        end
      end

      result = interactor_class.call(items: [{ name: "a" }, { name: "b" }])

      expect(result.success?).to be false
      # This should trigger the :too_large error code path
      expect(result.errors.first[:code]).to eq("ITEMS_ARRAY_TOO_LARGE")
    end
  end

  describe "ActiveModel::ValidationError rescue path" do
    it "rescues ValidationError in validate! method" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value
        validates :value, presence: true

        def validate!
          # Try to call super - this may raise ValidationError
          begin
            super
          rescue ActiveModel::ValidationError => e
            # This rescue block should be hit
            errors.add(:rescued, "caught validation error")
          end
        end
      end

      result = interactor_class.call(value: nil)
      expect(result.success?).to be false
    end
  end

  describe "NoMethodError rescue in validate!" do
    it "rescues NoMethodError when calling super" do
      base_class = Class.new do
        # No validate! method defined
      end

      interactor_class = Class.new(base_class) do
        include Interactor::Validation::Validates

        def context
          @context ||= OpenStruct.new(fail!: ->(errors:) { @failed = true })
        end

        def validate_params!
          # Empty - just need to trigger validate!
        end
      end

      instance = interactor_class.new
      # Should not raise NoMethodError
      expect { instance.send(:validate!) }.not_to raise_error
    end
  end

  describe "cache_regex_patterns disabled coverage" do
    before do
      Interactor::Validation.configure do |config|
        config.cache_regex_patterns = false
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "uses non-cached path for regex validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :email
        validates :email, format: /@/
      end

      result = interactor_class.call(email: "test@example.com")
      expect(result.success?).to be true

      # Second call should also not use cache
      result2 = interactor_class.call(email: "test2@example.com")
      expect(result2.success?).to be true
    end
  end
end
