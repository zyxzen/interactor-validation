# frozen_string_literal: true

RSpec.describe Interactor::Validation, "edge cases" do
  describe "missing context parameters" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :username

        validates :username, presence: true

        def call
          context.result = "Success"
        end
      end
    end

    context "when param is not provided in context" do
      it "treats missing param as nil and validates" do
        result = interactor_class.call({})
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USERNAME_IS_REQUIRED" })
      end
    end
  end

  describe "validates with block (ActiveModel style)" do
    it "delegates to ActiveModel::Validations when no keyword args" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        params :user

        # This should delegate to ActiveModel's validates
        validate :check_user

        def check_user
          errors.add(:user, "CUSTOM_ERROR") if user.nil?
        end
      end

      result = klass.call(user: nil)
      expect(result).to be_failure
    end
  end

  describe "format validation with custom message" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :code

        validates :code, format: { with: /\A[A-Z]{3}\z/, message: "INVALID_CODE_FORMAT" }
      end
    end

    it "uses custom error message" do
      result = interactor_class.call(code: "abc")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "CODE_INVALID_CODE_FORMAT" })
    end
  end

  describe "length validation with is option" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :pin

        validates :pin, length: { is: 4 }
      end
    end

    it "validates exact length" do
      expect(interactor_class.call(pin: "1234")).to be_success
      expect(interactor_class.call(pin: "123")).to be_failure
      expect(interactor_class.call(pin: "12345")).to be_failure
    end

    it "returns proper error message" do
      result = interactor_class.call(pin: "123")
      expect(result.errors).to include({ code: "PIN_MUST_BE_LENGTH_4" })
    end
  end

  describe "numericality validation with all constraint types" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :score

        validates :score, numericality: {
          greater_than_or_equal_to: 0,
          less_than_or_equal_to: 100,
          equal_to: 50
        }
      end
    end

    it "validates greater_than_or_equal_to" do
      result = interactor_class.call(score: -1)
      expect(result).to be_failure
      expect(result.errors).to include({ code: "SCORE_MUST_BE_AT_LEAST_0" })
    end

    it "validates less_than_or_equal_to" do
      result = interactor_class.call(score: 101)
      expect(result).to be_failure
      expect(result.errors).to include({ code: "SCORE_MUST_BE_AT_MOST_100" })
    end

    it "validates equal_to" do
      expect(interactor_class.call(score: 50)).to be_success

      result = interactor_class.call(score: 49)
      expect(result).to be_failure
      expect(result.errors).to include({ code: "SCORE_MUST_BE_EQUAL_TO_50" })
    end
  end

  describe "numericality with numeric strings" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :amount

        validates :amount, numericality: { greater_than: 0 }
      end
    end

    it "accepts integer strings" do
      expect(interactor_class.call(amount: "100")).to be_success
    end

    it "accepts float strings" do
      expect(interactor_class.call(amount: "99.99")).to be_success
    end

    it "accepts negative number strings" do
      result = interactor_class.call(amount: "-10")
      expect(result).to be_failure
    end

    it "validates numeric strings correctly" do
      result = interactor_class.call(amount: "0")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "AMOUNT_MUST_BE_GREATER_THAN_0" })
    end
  end

  describe "numericality with actual numbers" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :price

        validates :price, numericality: { greater_than: 0 }
      end
    end

    it "accepts integers" do
      expect(interactor_class.call(price: 100)).to be_success
    end

    it "accepts floats" do
      expect(interactor_class.call(price: 99.99)).to be_success
    end

    it "rejects zero" do
      result = interactor_class.call(price: 0)
      expect(result).to be_failure
    end

    it "rejects negative numbers" do
      result = interactor_class.call(price: -10.50)
      expect(result).to be_failure
    end
  end

  describe "inclusion validation with array" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :role

        validates :role, inclusion: %w[admin user guest]
      end
    end

    it "accepts values in array" do
      expect(interactor_class.call(role: "admin")).to be_success
    end

    it "rejects values not in array" do
      result = interactor_class.call(role: "superuser")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "ROLE_NOT_IN_ALLOWED_VALUES" })
    end
  end

  describe "validation skipping for blank values" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :optional_email

        validates :optional_email, format: { with: /@/ }
        validates :optional_email, length: { minimum: 5 }
      end
    end

    it "skips format validation when value is blank" do
      expect(interactor_class.call(optional_email: "")).to be_success
      expect(interactor_class.call(optional_email: nil)).to be_success
    end
  end

  describe "params without validates" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :name

        def call
          context.result = "Hello, #{name}!"
        end
      end
    end

    it "allows params without validation" do
      result = interactor_class.call(name: "World")
      expect(result).to be_success
      expect(result.result).to eq("Hello, World!")
    end
  end

  describe "validates without params" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        validates :email, presence: true

        def call
          context.result = "Done"
        end
      end
    end

    it "validates without declaring params" do
      result = interactor_class.call(email: "")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "EMAIL_IS_REQUIRED" })
    end

    it "succeeds when validation passes" do
      result = interactor_class.call(email: "test@example.com")
      expect(result).to be_success
    end
  end

  describe "error formatting edge cases" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :value

        validates :value, presence: true, length: { minimum: 5, maximum: 10 }
      end
    end

    it "reports multiple errors for same field" do
      result = interactor_class.call(value: "ab")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "VALUE_BELOW_MIN_LENGTH_5" })
      expect(result.errors.size).to eq(1) # Only length error since presence passes
    end
  end

  describe "class inheritance" do
    let(:base_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :username

        validates :username, presence: true
      end
    end

    let(:child_class) do
      Class.new(base_class) do
        params :password

        validates :password, presence: true
      end
    end

    it "inherits params from parent" do
      expect(child_class._declared_params).to include(:username, :password)
    end

    it "inherits validations from parent" do
      result = child_class.call(username: "", password: "secret")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "USERNAME_IS_REQUIRED" })
    end

    it "validates both parent and child params" do
      result = child_class.call(username: "john", password: "")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "PASSWORD_IS_REQUIRED" })
    end

    it "succeeds when all validations pass" do
      result = child_class.call(username: "john", password: "secret")
      expect(result).to be_success
    end
  end

  describe "format validation with regex only" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :hex_color

        validates :hex_color, format: /\A#[0-9A-Fa-f]{6}\z/
      end
    end

    it "accepts regex without hash" do
      expect(interactor_class.call(hex_color: "#FF5733")).to be_success
    end

    it "rejects invalid format" do
      result = interactor_class.call(hex_color: "FF5733")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "HEX_COLOR_INVALID_FORMAT" })
    end
  end

  describe "numericality as boolean" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :id

        validates :id, numericality: true
      end
    end

    it "validates as numeric when true" do
      expect(interactor_class.call(id: "123")).to be_success
      expect(interactor_class.call(id: 456)).to be_success
    end

    it "rejects non-numeric values" do
      result = interactor_class.call(id: "abc")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "ID_MUST_BE_A_NUMBER" })
    end
  end
end
