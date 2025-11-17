# frozen_string_literal: true

RSpec.describe Interactor::Validation, "configuration" do
  after do
    # Reset configuration after each test
    Interactor::Validation.reset_configuration!
  end

  describe "global configuration" do
    it "has default configuration" do
      config = Interactor::Validation.configuration
      expect(config.error_mode).to eq(:default)
      expect(config.halt_on_first_error).to eq(false)
    end

    it "allows configuration via block" do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
        config.halt_on_first_error = true
      end

      config = Interactor::Validation.configuration
      expect(config.error_mode).to eq(:code)
      expect(config.halt_on_first_error).to eq(true)
    end

    it "resets configuration" do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
      end

      Interactor::Validation.reset_configuration!

      config = Interactor::Validation.configuration
      expect(config.error_mode).to eq(:default)
    end

    it "validates error_mode values" do
      expect do
        Interactor::Validation.configure do |config|
          config.error_mode = :invalid
        end
      end.to raise_error(ArgumentError, /Invalid error_mode/)
    end
  end

  describe "instance-level configuration" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :username
        validates :username, presence: true

        configure_validation do |config|
          config.error_mode = :default
        end
      end
    end

    it "allows per-interactor configuration" do
      expect(interactor_class.validation_config.error_mode).to eq(:default)
    end

    it "uses instance config over global config" do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
      end

      result = interactor_class.call(username: "")
      expect(result).to be_failure
      expect(result.errors.first).to have_key(:attribute)
      expect(result.errors.first).to have_key(:message)
      expect(result.errors.first).not_to have_key(:code)
    end
  end

  describe "error_mode: :code" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :username, :email, :age, :status, :pin

        validates :username, presence: true
        validates :email, format: { with: /@/ }
        validates :age, numericality: { greater_than: 0 }
        validates :status, inclusion: { in: %w[active inactive] }
        validates :pin, length: { is: 4 }

        configure_validation do |config|
          config.error_mode = :code
        end
      end
    end

    it "returns error codes for presence validation" do
      result = interactor_class.call(username: "")
      expect(result.errors).to include({ code: "USERNAME_IS_REQUIRED" })
    end

    it "returns error codes for format validation" do
      result = interactor_class.call(username: "john", email: "invalid")
      expect(result.errors).to include({ code: "EMAIL_INVALID_FORMAT" })
    end

    it "returns error codes for numericality validation" do
      result = interactor_class.call(username: "john", age: 0)
      expect(result.errors).to include({ code: "AGE_MUST_BE_GREATER_THAN_0" })
    end

    it "returns error codes for inclusion validation" do
      result = interactor_class.call(username: "john", status: "deleted")
      expect(result.errors).to include({ code: "STATUS_NOT_IN_ALLOWED_VALUES" })
    end

    it "returns error codes for length validation" do
      result = interactor_class.call(username: "john", pin: "123")
      expect(result.errors).to include({ code: "PIN_MUST_BE_LENGTH_4" })
    end

    it "returns error codes for non-numeric values" do
      result = interactor_class.call(username: "john", age: "abc")
      expect(result.errors).to include({ code: "AGE_MUST_BE_A_NUMBER" })
    end
  end

  describe "error_mode: :default" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :username, :email, :age, :status

        validates :username, presence: true
        validates :email, format: { with: /@/ }
        validates :age, numericality: { greater_than: 0 }
        validates :status, inclusion: { in: %w[active inactive] }

        configure_validation do |config|
          config.error_mode = :default
        end
      end
    end

    it "returns ActiveModel-style errors for presence validation" do
      result = interactor_class.call(username: "")
      expect(result.errors.first).to include(
        attribute: :username,
        type: :blank
      )
    end

    it "returns ActiveModel-style errors for format validation" do
      result = interactor_class.call(username: "john", email: "invalid")
      expect(result.errors.first).to include(
        attribute: :email,
        type: :invalid
      )
    end

    it "returns ActiveModel-style errors for numericality validation" do
      result = interactor_class.call(username: "john", age: 0)
      expect(result.errors.first).to include(
        attribute: :age,
        type: :greater_than
      )
    end

    it "returns ActiveModel-style errors for inclusion validation" do
      result = interactor_class.call(username: "john", status: "deleted")
      expect(result.errors.first).to include(
        attribute: :status,
        type: :inclusion
      )
    end

    it "includes message in error hash" do
      result = interactor_class.call(username: "")
      expect(result.errors.first).to have_key(:message)
      expect(result.errors.first[:message]).to be_a(String)
    end
  end

  describe "custom error messages" do
    context "with error_mode: :code" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :code, :status

          validates :code, format: { with: /\A[A-Z]+\z/, message: "CUSTOM_FORMAT_ERROR" }
          validates :status, presence: { message: "CUSTOM_REQUIRED_ERROR" }

          configure_validation do |config|
            config.error_mode = :code
          end
        end
      end

      it "uses custom message for format validation" do
        result = interactor_class.call(code: "abc")
        expect(result.errors).to include({ code: "CODE_CUSTOM_FORMAT_ERROR" })
      end

      it "uses custom message for presence validation" do
        result = interactor_class.call(status: "")
        expect(result.errors).to include({ code: "STATUS_CUSTOM_REQUIRED_ERROR" })
      end
    end

    context "with error_mode: :default" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :code

          validates :code, format: { with: /\A[A-Z]+\z/, message: "must be uppercase letters" }

          configure_validation do |config|
            config.error_mode = :default
          end
        end
      end

      it "uses custom message in default mode" do
        result = interactor_class.call(code: "abc")
        expect(result.errors.first[:message]).to eq("must be uppercase letters")
      end
    end
  end

  describe "halt_on_first_error option" do
    context "when false" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email, :age

          validates :username, presence: true
          validates :email, presence: true
          validates :age, presence: true

          configure_validation do |config|
            config.halt_on_first_error = false
          end
        end
      end

      it "collects all errors" do
        result = interactor_class.call(username: "", email: "", age: "")
        expect(result.errors.size).to eq(3)
      end
    end

    context "when true" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email, :age

          validates :username, presence: true
          validates :email, presence: true
          validates :age, presence: true

          configure_validation do |config|
            config.halt_on_first_error = true
          end
        end
      end

      it "stops at first error" do
        result = interactor_class.call(username: "", email: "", age: "")
        expect(result.errors.size).to eq(1)
      end
    end
  end

  describe "length validation error codes" do
    context "with maximum length" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :text
          validates :text, length: { maximum: 10 }
        end
      end

      it "returns proper error code" do
        result = interactor_class.call(text: "a" * 11)
        expect(result.errors).to include({ code: "TEXT_EXCEEDS_MAX_LENGTH_10" })
      end
    end

    context "with minimum length" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :text
          validates :text, length: { minimum: 5 }
        end
      end

      it "returns proper error code" do
        result = interactor_class.call(text: "abc")
        expect(result.errors).to include({ code: "TEXT_BELOW_MIN_LENGTH_5" })
      end
    end
  end

  describe "numericality validation error codes" do
    context "with less_than_or_equal_to" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :value
          validates :value, numericality: { less_than_or_equal_to: 100 }
        end
      end

      it "returns proper error code" do
        result = interactor_class.call(value: 101)
        expect(result.errors).to include({ code: "VALUE_MUST_BE_AT_MOST_100" })
      end
    end

    context "with greater_than_or_equal_to" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :value
          validates :value, numericality: { greater_than_or_equal_to: 10 }
        end
      end

      it "returns proper error code" do
        result = interactor_class.call(value: 9)
        expect(result.errors).to include({ code: "VALUE_MUST_BE_AT_LEAST_10" })
      end
    end

    context "with equal_to" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :value
          validates :value, numericality: { equal_to: 50 }
        end
      end

      it "returns proper error code" do
        result = interactor_class.call(value: 49)
        expect(result.errors).to include({ code: "VALUE_MUST_BE_EQUAL_TO_50" })
      end
    end

    context "with less_than" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :value
          validates :value, numericality: { less_than: 100 }
        end
      end

      it "returns proper error code" do
        result = interactor_class.call(value: 100)
        expect(result.errors).to include({ code: "VALUE_MUST_BE_LESS_THAN_100" })
      end
    end
  end

  describe "missing param handling" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        validates :missing_param, presence: true
      end
    end

    it "handles missing params gracefully" do
      result = interactor_class.call({})
      expect(result).to be_failure
      expect(result.errors).to include({ code: "MISSING_PARAM_IS_REQUIRED" })
    end
  end

  describe "skip_validate option" do
    it "has default value of true" do
      config = Interactor::Validation.configuration
      expect(config.skip_validate).to eq(true)
    end

    context "when true (default)" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email

          validates :username, presence: true
          validates :email, presence: true

          configure_validation do |config|
            config.error_mode = :code
            config.skip_validate = true
          end

          def validate!
            super
            # This should NOT be called if param validation fails
            errors.add(:base, "CUSTOM_VALIDATION_RAN")
          end
        end
      end

      it "skips custom validate! when param validation fails" do
        result = interactor_class.call(username: "", email: "")
        expect(result).to be_failure
        # Should only have param validation errors, not custom validation error
        expect(result.errors).to include({ code: "USERNAME_IS_REQUIRED" })
        expect(result.errors).not_to include({ code: "BASE_CUSTOM_VALIDATION_RAN" })
      end

      it "runs custom validate! when param validation passes" do
        result = interactor_class.call(username: "john", email: "john@example.com")
        expect(result).to be_failure
        # Should have custom validation error since params are valid
        expect(result.errors).to include({ code: "BASE_CUSTOM_VALIDATION_RAN" })
      end
    end

    context "when false" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email

          validates :username, presence: true
          validates :email, presence: true

          configure_validation do |config|
            config.error_mode = :code
            config.skip_validate = false
          end

          def validate!
            super
            # This SHOULD be called even if param validation fails
            errors.add(:base, "CUSTOM_VALIDATION_RAN")
          end
        end
      end

      it "runs custom validate! even when param validation fails" do
        result = interactor_class.call(username: "", email: "")
        expect(result).to be_failure
        # Should have both param validation errors AND custom validation error
        expect(result.errors).to include({ code: "USERNAME_IS_REQUIRED" })
        expect(result.errors).to include({ code: "BASE_CUSTOM_VALIDATION_RAN" })
      end

      it "runs custom validate! when param validation passes" do
        result = interactor_class.call(username: "john", email: "john@example.com")
        expect(result).to be_failure
        # Should have custom validation error
        expect(result.errors).to include({ code: "BASE_CUSTOM_VALIDATION_RAN" })
      end
    end
  end
end
