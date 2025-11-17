# frozen_string_literal: true

RSpec.describe Interactor::Validation do
  after(:each) do
    # Reset global configuration after each test
    Interactor::Validation.configure do |config|
      config.halt = false
      config.mode = :default
      config.skip_validate = true
    end
  end

  # ============================================================================
  # BASIC VALIDATORS
  # ============================================================================

  describe "presence validator" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :name, :email
        validates :name, presence: true
        validates :email, presence: { message: "Email is required" }
      end
    end

    it "fails when value is nil" do
      result = interactor_class.call(name: nil, email: "test@example.com")
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:name)
      expect(result.errors.first[:type]).to eq(:blank)
    end

    it "fails when value is empty string" do
      result = interactor_class.call(name: "", email: "test@example.com")
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:name)
    end

    it "succeeds when value is present" do
      result = interactor_class.call(name: "John", email: "john@example.com")
      expect(result).to be_success
      expect(result.errors).to be_nil
    end

    it "uses custom error message" do
      result = interactor_class.call(name: "John", email: "")
      expect(result).to be_failure
      expect(result.errors.first[:message]).to eq("Email Email is required")
    end
  end

  describe "format validator" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :email, :username
        validates :email, format: { with: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i }
        validates :username, format: { with: /\A[a-z0-9_]+\z/, message: "Invalid username format" }
      end
    end

    it "fails when value doesn't match pattern" do
      result = interactor_class.call(email: "invalid-email", username: "valid_user")
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:email)
      expect(result.errors.first[:type]).to eq(:invalid)
    end

    it "succeeds when value matches pattern" do
      result = interactor_class.call(email: "test@example.com", username: "valid_user")
      expect(result).to be_success
    end

    it "uses custom error message" do
      result = interactor_class.call(email: "test@example.com", username: "Invalid-User!")
      expect(result).to be_failure
      expect(result.errors.first[:message]).to eq("Username Invalid username format")
    end

    context "with non-string types" do
      let(:type_interactor) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :code, :id, :label
          validates :code, format: { with: /^\d{4}$/ }
          validates :id, format: { with: /^\d+$/ }
          validates :label, format: { with: /^[a-z_]+$/ }
        end
      end

      it "accepts numeric values by converting to string" do
        result = type_interactor.call(code: 1234, id: 5678, label: :test_label)
        expect(result).to be_success
      end

      it "accepts symbol values by converting to string" do
        result = type_interactor.call(code: "9999", id: "1111", label: :valid_symbol)
        expect(result).to be_success
      end

      it "validates arbitrary objects using their to_s representation" do
        # NOTE: Format validator intentionally uses .to_s on any object
        # This means objects with predictable string representations will match/fail based on the pattern
        custom_object = Class.new do
          def to_s
            "Invalid-Label!" # Contains uppercase and special chars, won't match /^[a-z_]+$/
          end
        end.new

        result = type_interactor.call(code: "1234", id: "5678", label: custom_object)
        expect(result).to be_failure # "Invalid-Label!" doesn't match /^[a-z_]+$/
        expect(result.errors.first[:attribute]).to eq(:label)
        expect(result.errors.first[:type]).to eq(:invalid)
      end
    end
  end

  describe "length validator" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :password, :code, :bio
        validates :password, length: { minimum: 8, maximum: 128 }
        validates :code, length: { is: 6 }
        validates :bio, length: { maximum: 500 }
      end
    end

    it "fails when value is too short" do
      result = interactor_class.call(password: "short", code: "123456", bio: "Test")
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:password)
      expect(result.errors.first[:type]).to eq(:too_short)
    end

    it "fails when value is too long" do
      result = interactor_class.call(password: "a" * 129, code: "123456", bio: "Test")
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:password)
      expect(result.errors.first[:type]).to eq(:too_long)
    end

    it "fails when value is not exact length" do
      result = interactor_class.call(password: "validpassword", code: "12345", bio: "Test")
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:code)
      expect(result.errors.first[:type]).to eq(:wrong_length)
    end

    it "succeeds when all lengths are valid" do
      result = interactor_class.call(password: "validpassword", code: "123456", bio: "Test bio")
      expect(result).to be_success
    end

    context "with array values" do
      let(:array_interactor) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :tags, :categories
          validates :tags, length: { minimum: 2, maximum: 5 }
          validates :categories, length: { is: 3 }
        end
      end

      it "validates array length correctly" do
        result = array_interactor.call(tags: %w[ruby rails], categories: %w[tech web dev])
        expect(result).to be_success
      end

      it "fails when array is too short" do
        result = array_interactor.call(tags: ["ruby"], categories: %w[tech web dev])
        expect(result).to be_failure
        expect(result.errors.first[:attribute]).to eq(:tags)
        expect(result.errors.first[:type]).to eq(:too_short)
        expect(result.errors.first[:message]).to include("items")
      end

      it "fails when array is too long" do
        result = array_interactor.call(tags: %w[a b c d e f], categories: %w[tech web dev])
        expect(result).to be_failure
        expect(result.errors.first[:attribute]).to eq(:tags)
        expect(result.errors.first[:type]).to eq(:too_long)
        expect(result.errors.first[:message]).to include("items")
      end

      it "fails when array length is not exact" do
        result = array_interactor.call(tags: %w[ruby rails], categories: %w[tech web])
        expect(result).to be_failure
        expect(result.errors.first[:attribute]).to eq(:categories)
        expect(result.errors.first[:type]).to eq(:wrong_length)
        expect(result.errors.first[:message]).to include("items")
      end
    end

    context "with hash values" do
      let(:hash_interactor) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :config
          validates :config, length: { minimum: 2, maximum: 5 }
        end
      end

      it "validates hash length correctly" do
        result = hash_interactor.call(config: { key1: "value1", key2: "value2" })
        expect(result).to be_success
      end

      it "fails when hash has too few items" do
        result = hash_interactor.call(config: { key1: "value1" })
        expect(result).to be_failure
        expect(result.errors.first[:attribute]).to eq(:config)
        expect(result.errors.first[:type]).to eq(:too_short)
        expect(result.errors.first[:message]).to include("items")
      end

      it "fails when hash has too many items" do
        result = hash_interactor.call(config: { k1: "v1", k2: "v2", k3: "v3", k4: "v4", k5: "v5", k6: "v6" })
        expect(result).to be_failure
        expect(result.errors.first[:attribute]).to eq(:config)
        expect(result.errors.first[:type]).to eq(:too_long)
        expect(result.errors.first[:message]).to include("items")
      end
    end
  end

  describe "inclusion validator" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :status, :role
        validates :status, inclusion: { in: %w[active pending inactive] }
        validates :role, inclusion: { in: %w[admin user guest], message: "Invalid role" }
      end
    end

    it "fails when value is not in allowed set" do
      result = interactor_class.call(status: "deleted", role: "admin")
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:status)
      expect(result.errors.first[:type]).to eq(:inclusion)
    end

    it "succeeds when value is in allowed set" do
      result = interactor_class.call(status: "active", role: "admin")
      expect(result).to be_success
    end

    it "uses custom error message" do
      result = interactor_class.call(status: "active", role: "superadmin")
      expect(result).to be_failure
      expect(result.errors.first[:message]).to eq("Role Invalid role")
    end
  end

  describe "numericality validator" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :age, :price, :quantity, :rating, :count
        validates :age, numericality: { greater_than: 0 }
        validates :price, numericality: { greater_than_or_equal_to: 0 }
        validates :quantity, numericality: { less_than: 100 }
        validates :rating, numericality: { equal_to: 5 }
        validates :count, numericality: true
      end
    end

    it "fails when value is not greater than threshold" do
      result = interactor_class.call(age: 0, price: 0, quantity: 50, rating: 5, count: 10)
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:age)
      expect(result.errors.first[:type]).to eq(:greater_than)
    end

    it "fails when value is not equal to threshold" do
      result = interactor_class.call(age: 18, price: 0, quantity: 50, rating: 4, count: 10)
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:rating)
      expect(result.errors.first[:type]).to eq(:equal_to)
    end

    it "fails when value is not numeric" do
      result = interactor_class.call(age: 18, price: 0, quantity: 50, rating: 5, count: "not-a-number")
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:count)
      expect(result.errors.first[:type]).to eq(:not_a_number)
    end

    it "succeeds when all numeric validations pass" do
      result = interactor_class.call(age: 18, price: 10.5, quantity: 50, rating: 5, count: 100)
      expect(result).to be_success
    end

    context "with numeric alias" do
      let(:alias_interactor) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :age
          validates :age, numeric: { greater_than: 0 }
        end
      end

      it "works with numeric alias" do
        result = alias_interactor.call(age: -5)
        expect(result).to be_failure
        expect(result.errors.first[:type]).to eq(:greater_than)
      end
    end

    context "with less_than_or_equal_to constraint" do
      let(:max_interactor) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :score, :percentage
          validates :score, numericality: { less_than_or_equal_to: 100 }
          validates :percentage, numericality: { less_than_or_equal_to: 100, message: "cannot exceed 100" }
        end
      end

      it "fails when value exceeds maximum" do
        result = max_interactor.call(score: 101, percentage: 50)
        expect(result).to be_failure
        expect(result.errors.first[:attribute]).to eq(:score)
        expect(result.errors.first[:type]).to eq(:less_than_or_equal_to)
      end

      it "succeeds when value equals maximum" do
        result = max_interactor.call(score: 100, percentage: 100)
        expect(result).to be_success
      end

      it "uses custom error message" do
        result = max_interactor.call(score: 100, percentage: 101)
        expect(result).to be_failure
        expect(result.errors.first[:message]).to include("cannot exceed 100")
      end
    end

    context "with string numeric values" do
      let(:string_numeric_interactor) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :quantity, :price
          validates :quantity, numericality: { greater_than: 0 }
          validates :price, numericality: { greater_than_or_equal_to: 0.01 }
        end
      end

      it "coerces string integers" do
        result = string_numeric_interactor.call(quantity: "10", price: "5.99")
        expect(result).to be_success
      end

      it "validates coerced strings correctly" do
        result = string_numeric_interactor.call(quantity: "0", price: "0.01")
        expect(result).to be_failure # quantity must be > 0
        expect(result.errors.first[:attribute]).to eq(:quantity)
      end

      it "rejects non-numeric strings" do
        result = string_numeric_interactor.call(quantity: "abc", price: "5.99")
        expect(result).to be_failure
        expect(result.errors.first[:type]).to eq(:not_a_number)
      end
    end
  end

  describe "boolean validator" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :is_active, :terms_accepted
        validates :is_active, boolean: true
        validates :terms_accepted, boolean: true
      end
    end

    it "fails when value is not true or false" do
      result = interactor_class.call(is_active: "yes", terms_accepted: true)
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:is_active)
      expect(result.errors.first[:type]).to eq(:invalid)
      expect(result.errors.first[:message]).to eq("Is active must be true or false")
    end

    it "succeeds when value is true" do
      result = interactor_class.call(is_active: true, terms_accepted: true)
      expect(result).to be_success
    end

    it "succeeds when value is false" do
      result = interactor_class.call(is_active: false, terms_accepted: false)
      expect(result).to be_success
    end

    it "allows nil values (skipped when not present)" do
      result = interactor_class.call(is_active: nil, terms_accepted: true)
      expect(result).to be_success
    end

    it "rejects integer 0 and 1" do
      result = interactor_class.call(is_active: 0, terms_accepted: 1)
      expect(result).to be_failure
      expect(result.errors.size).to eq(2)
    end

    it "rejects string values" do
      result = interactor_class.call(is_active: "true", terms_accepted: "false")
      expect(result).to be_failure
      expect(result.errors.size).to eq(2)
    end
  end

  # ============================================================================
  # NESTED VALIDATION
  # ============================================================================

  describe "nested hash validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :user
        validates :user, presence: true do
          attribute :name, presence: true
          attribute :email, format: { with: /@/ }
          attribute :age, numericality: { greater_than: 0 }
        end
      end
    end

    it "validates nested hash attributes" do
      result = interactor_class.call(user: { name: "", email: "invalid", age: -5 })
      expect(result).to be_failure
      expect(result.errors.size).to eq(3)
      expect(result.errors.map { |e| e[:attribute] }).to contain_exactly(
        :"user.name", :"user.email", :"user.age"
      )
    end

    it "succeeds when all nested attributes are valid" do
      result = interactor_class.call(user: { name: "John", email: "john@example.com", age: 25 })
      expect(result).to be_success
    end

    it "fails when parent is nil" do
      result = interactor_class.call(user: nil)
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:user)
      expect(result.errors.first[:type]).to eq(:blank)
    end
  end

  describe "nested array validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :items
        validates :items do
          attribute :name, presence: true
          attribute :price, numericality: { greater_than: 0 }
        end
      end
    end

    it "validates each array element" do
      items = [
        { name: "Item 1", price: 10 },
        { name: "", price: -5 },
        { name: "Item 3", price: 0 }
      ]
      result = interactor_class.call(items: items)
      expect(result).to be_failure
      expect(result.errors.size).to eq(3)
      expect(result.errors.map { |e| e[:attribute] }).to contain_exactly(
        :"items[1].name", :"items[1].price", :"items[2].price"
      )
    end

    it "succeeds when all array elements are valid" do
      items = [
        { name: "Item 1", price: 10 },
        { name: "Item 2", price: 20 }
      ]
      result = interactor_class.call(items: items)
      expect(result).to be_success
    end
  end

  describe "nested hash with false values" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :settings
        validates :settings do
          attribute :enabled, presence: true
          attribute :auto_save, presence: true
        end
      end
    end

    it "correctly handles false as a valid value" do
      result = interactor_class.call(settings: { enabled: false, auto_save: false })
      expect(result).to be_success
    end

    it "correctly handles true as a valid value" do
      result = interactor_class.call(settings: { enabled: true, auto_save: true })
      expect(result).to be_success
    end

    it "fails when value is nil" do
      result = interactor_class.call(settings: { enabled: nil, auto_save: false })
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:"settings.enabled")
    end

    it "works with string keys in hash" do
      result = interactor_class.call(settings: { "enabled" => false, "auto_save" => true })
      expect(result).to be_success
    end

    context "with custom error messages" do
      let(:custom_message_interactor) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :config
          validates :config do
            attribute :enabled, presence: { message: "must be provided" }
            attribute :timeout, numericality: { greater_than: 0, message: "must be positive" }
          end
        end
      end

      it "uses custom messages in nested validations" do
        result = custom_message_interactor.call(config: { enabled: nil, timeout: -5 })
        expect(result).to be_failure
        expect(result.errors.size).to eq(2)
        expect(result.errors.first[:message]).to include("must be provided")
        expect(result.errors.last[:message]).to include("must be positive")
      end
    end
  end

  describe "nested validation with mixed types" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :data
        validates :data do
          attribute :count, numericality: true
          attribute :active, presence: true
          attribute :label, format: { with: /^[a-z]+$/ }
          attribute :category, inclusion: { in: %w[a b c] }
          attribute :description, length: { minimum: 5 }
        end
      end
    end

    it "validates multiple different validator types in nested hash" do
      result = interactor_class.call(data: {
                                       count: "not_a_number",
                                       active: nil,
                                       label: "Invalid123",
                                       category: "z",
                                       description: "sh"
                                     })
      expect(result).to be_failure
      expect(result.errors.size).to eq(5)
    end

    it "succeeds when all nested validators pass" do
      result = interactor_class.call(data: {
                                       count: 42,
                                       active: true,
                                       label: "valid",
                                       category: "a",
                                       description: "long enough"
                                     })
      expect(result).to be_success
    end
  end

  describe "nested array with halt configuration" do
    let(:halt_interactor) do
      Class.new do
        include Interactor
        include Interactor::Validation

        validation_halt true

        params :items
        validates :items do
          attribute :name, presence: true
          attribute :price, numericality: { greater_than: 0 }
        end
      end
    end

    it "halts on first item with errors" do
      items = [
        { name: "Valid", price: 10 },
        { name: "", price: -5 },
        { name: "", price: -10 }
      ]
      result = halt_interactor.call(items: items)
      expect(result).to be_failure
      # Should stop after first error in second item
      expect(result.errors.size).to be <= 2
    end
  end

  # ============================================================================
  # CUSTOM VALIDATION
  # ============================================================================

  describe "custom validate! method" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :product_id, :quantity

        validates :product_id, presence: true
        validates :quantity, numericality: { greater_than: 0 }

        def validate!
          errors.add(:product_id, :not_found, message: "Product not found") if product_id == 999
          errors.add(:quantity, :insufficient, message: "Insufficient stock") if quantity > 100
        end
      end
    end

    it "runs custom validations after parameter validations" do
      result = interactor_class.call(product_id: 999, quantity: 50)
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:product_id)
      expect(result.errors.first[:type]).to eq(:not_found)
    end

    it "collects both parameter and custom validation errors" do
      result = interactor_class.call(product_id: 1, quantity: 150)
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:quantity)
      expect(result.errors.first[:type]).to eq(:insufficient)
    end
  end

  # ============================================================================
  # CONFIGURATION
  # ============================================================================

  describe "skip_validate configuration" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :email
        validates :email, presence: true

        def validate!
          errors.add(:custom, :custom_error, message: "Custom validation failed")
        end
      end
    end

    context "when skip_validate is true (default)" do
      it "skips custom validate! when parameter validations fail" do
        result = interactor_class.call(email: "")
        expect(result).to be_failure
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:email)
      end
    end

    context "when skip_validate is false" do
      before do
        Interactor::Validation.configure { |config| config.skip_validate = false }
      end

      it "runs custom validate! even when parameter validations fail" do
        result = interactor_class.call(email: "")
        expect(result).to be_failure
        expect(result.errors.size).to eq(2)
        expect(result.errors.map { |e| e[:attribute] }).to contain_exactly(:email, :custom)
      end
    end
  end

  describe "halt configuration" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :email, :username, :age
        validates :email, presence: true
        validates :username, presence: true
        validates :age, numericality: { greater_than: 0 }
      end
    end

    context "when halt is false (default)" do
      it "collects all validation errors" do
        result = interactor_class.call(email: "", username: "", age: -5)
        expect(result).to be_failure
        expect(result.errors.size).to eq(3)
      end
    end

    context "when halt is true" do
      before do
        Interactor::Validation.configure { |config| config.halt = true }
      end

      it "stops on first validation error" do
        result = interactor_class.call(email: "", username: "", age: -5)
        expect(result).to be_failure
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:email)
      end
    end

    context "per-interactor configuration" do
      let(:halt_interactor) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure { |config| config.halt = true }

          params :name, :email
          validates :name, presence: true
          validates :email, presence: true
        end
      end

      it "uses interactor-specific configuration" do
        result = halt_interactor.call(name: "", email: "")
        expect(result).to be_failure
        expect(result.errors.size).to eq(1)
      end
    end
  end

  describe "mode configuration" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :email, :username
        validates :email, presence: true
        validates :username, length: { minimum: 3 }
      end
    end

    context "default mode" do
      it "returns human-readable error format" do
        result = interactor_class.call(email: "", username: "ab")
        expect(result).to be_failure
        expect(result.errors.first).to include(:attribute, :type, :message)
        expect(result.errors.first[:attribute]).to eq(:email)
        expect(result.errors.first[:type]).to eq(:blank)
        expect(result.errors.first[:message]).to match(/can't be blank/)
      end
    end

    context "code mode" do
      before do
        Interactor::Validation.configure { |config| config.mode = :code }
      end

      it "returns machine-readable error codes" do
        result = interactor_class.call(email: "", username: "ab")
        expect(result).to be_failure
        expect(result.errors.first).to have_key(:code)
        expect(result.errors.first[:code]).to match(/\A[A-Z_]+\z/)
      end

      it "generates SCREAMING_SNAKE_CASE codes" do
        result = interactor_class.call(email: "", username: "ab")
        expect(result.errors.map { |e| e[:code] }).to all(match(/\A[A-Z_]+\z/))
      end
    end
  end

  # ============================================================================
  # PARAMS DELEGATION
  # ============================================================================

  describe "params delegation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :user_id, :email

        validates :email, format: { with: /@/ }

        def call
          context.result = "#{user_id}:#{email}"
        end
      end
    end

    it "provides direct access to context values" do
      result = interactor_class.call(user_id: 123, email: "test@example.com")
      expect(result).to be_success
      expect(result.result).to eq("123:test@example.com")
    end

    it "delegates to context internally" do
      instance = interactor_class.new(Interactor::Context.build(user_id: 456, email: "user@example.com"))
      expect(instance.send(:user_id)).to eq(456)
      expect(instance.send(:email)).to eq("user@example.com")
    end
  end

  # ============================================================================
  # INHERITANCE
  # ============================================================================

  describe "inheritance behavior" do
    let(:base_interactor) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure do |config|
          config.mode = :code
          config.halt = true
        end
      end
    end

    let(:child_interactor) do
      Class.new(base_interactor) do
        params :name, :email
        validates :name, presence: true
        validates :email, presence: true
      end
    end

    it "inherits configuration from parent" do
      expect(child_interactor._validation_config[:mode]).to eq(:code)
      expect(child_interactor._validation_config[:halt]).to eq(true)
    end

    it "does not modify parent when child adds validations" do
      expect(base_interactor._validations.keys).not_to include(:name)
      expect(child_interactor._validations.keys).to include(:name)
    end

    it "allows child to override configuration" do
      override_child = Class.new(base_interactor) do
        configure { |config| config.mode = :default }
      end

      expect(base_interactor._validation_config[:mode]).to eq(:code)
      expect(override_child._validation_config[:mode]).to eq(:default)
    end
  end

  # ============================================================================
  # EDGE CASES
  # ============================================================================

  describe "edge cases" do
    it "handles nil context values gracefully" do
      interactor = Class.new do
        include Interactor
        include Interactor::Validation

        params :name
        validates :name, presence: true
      end

      result = interactor.call
      expect(result).to be_failure
    end

    it "validates empty arrays" do
      interactor = Class.new do
        include Interactor
        include Interactor::Validation

        params :items
        validates :items do
          attribute :name, presence: true
        end
      end

      result = interactor.call(items: [])
      expect(result).to be_success
    end

    it "handles multiple validators on same attribute" do
      interactor = Class.new do
        include Interactor
        include Interactor::Validation

        params :email
        validates :email, presence: true, format: { with: /@/ }
      end

      result = interactor.call(email: "invalid")
      expect(result).to be_failure
      expect(result.errors.first[:attribute]).to eq(:email)
      expect(result.errors.first[:type]).to eq(:invalid)
    end
  end
end
