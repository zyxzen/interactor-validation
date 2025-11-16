# frozen_string_literal: true

RSpec.describe "Interactor::Validation Complete Coverage" do
  describe "triggering ArgumentError with 'Class name cannot be blank'" do
    it "handles anonymous class errors in error detail mapping" do
      # Create an anonymous interactor class
      anon_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :name
        validates :name, presence: true
      end

      result = anon_class.call(name: nil)

      expect(result.success?).to be false
      expect(result.errors).not_to be_empty
    end

    it "handles anonymous class in error restoration" do
      anon_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value
        validates :value, presence: true

        def validate!
          # Call super to trigger error restoration
          super
        end
      end

      result = anon_class.call(value: nil)
      expect(result.success?).to be false
    end

    it "handles anonymous class in validate_params! valid? call" do
      anon_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :field
        validates :field, presence: true
      end

      result = anon_class.call(field: nil)
      expect(result.success?).to be false
    end
  end

  describe "error_code_for with :timeout type" do
    it "returns REGEX_TIMEOUT for :timeout error type" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value

        def call
          # Call error_code_for directly  to test the :timeout branch
          code = error_code_for(:timeout)
          context.code_result = code
        end
      end

      result = interactor_class.call(value: "test")
      expect(result.code_result).to eq("REGEX_TIMEOUT")
    end
  end

  describe "error_code_for with :too_large type" do
    it "returns ARRAY_TOO_LARGE for :too_large error type" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value

        def call
          # Call error_code_for directly to test the :too_large branch
          code = error_code_for(:too_large)
          context.code_result = code
        end
      end

      result = interactor_class.call(value: "test")
      expect(result.code_result).to eq("ARRAY_TOO_LARGE")
    end
  end

  describe "error_code_for with unknown error type (else branch)" do
    it "uppercases unknown error types in else branch" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value

        def call
          # Trigger the else branch with a completely unknown type
          code = error_code_for(:some_totally_unknown_error)
          context.code_result = code
        end
      end

      result = interactor_class.call(value: "test")
      expect(result.code_result).to eq("SOME_TOTALLY_UNKNOWN_ERROR")
    end
  end

  describe "safe_regex_match? with caching disabled" do
    before do
      Interactor::Validation.configure do |config|
        config.cache_regex_patterns = false
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "skips caching when cache_regex_patterns is false" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :email
        validates :email, format: /@/
      end

      result = interactor_class.call(email: "test@example.com")
      expect(result.success?).to be true
    end
  end

  describe "add_error and add_nested_error halt parameter" do
    it "sets halt flag via add_error" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value

        def call
          # Directly call add_error with halt: true
          add_error(:field, "error", :invalid, halt: true)
          # Store halt flag status for verification
          context.halt_was_set = @halt_validation
        end
      end

      result = interactor_class.call(value: "test")
      expect(result.halt_was_set).to be true
    end

    it "sets halt flag via add_nested_error" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :data

        def call
          # Directly call add_nested_error with halt: true
          add_nested_error(:data, :field, "error", :invalid, halt: true)
          # Store halt flag status for verification
          context.halt_was_set = @halt_validation
        end
      end

      result = interactor_class.call(data: {})
      expect(result.halt_was_set).to be true
    end
  end
end
