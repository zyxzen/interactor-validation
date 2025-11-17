# frozen_string_literal: true

RSpec.describe Interactor::Validation, "nested validations" do
  describe "hash validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :attributes

        validates :attributes do
          attribute :username, presence: true
          attribute :password, presence: true
        end
      end
    end

    context "when all attributes are valid" do
      it "succeeds" do
        result = interactor_class.call(attributes: { username: "john", password: "secret" })
        expect(result).to be_success
      end
    end

    context "when an attribute is missing" do
      it "fails with error code" do
        result = interactor_class.call(attributes: { username: nil, password: "secret" })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "ATTRIBUTES_USERNAME_IS_REQUIRED" })
      end
    end

    context "when multiple attributes are missing" do
      it "fails with all error codes" do
        result = interactor_class.call(attributes: { username: "", password: nil })
        expect(result).to be_failure
        expect(result.errors).to match_array([
                                               { code: "ATTRIBUTES_USERNAME_IS_REQUIRED" },
                                               { code: "ATTRIBUTES_PASSWORD_IS_REQUIRED" }
                                             ])
      end
    end

    context "when attributes use string keys" do
      it "validates correctly" do
        result = interactor_class.call(attributes: { "username" => "john", "password" => "secret" })
        expect(result).to be_success
      end

      it "fails when missing" do
        result = interactor_class.call(attributes: { "username" => nil, "password" => "secret" })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "ATTRIBUTES_USERNAME_IS_REQUIRED" })
      end
    end

    context "when the parameter is not a hash" do
      it "fails with type error" do
        result = interactor_class.call(attributes: "not a hash")
        expect(result).to be_failure
        expect(result.errors).to include({ code: "ATTRIBUTES_INVALID_TYPE" })
      end
    end
  end

  describe "array of hashes validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :users

        validates :users do
          attribute :username, presence: true
          attribute :email, presence: true
        end
      end
    end

    context "when all items are valid" do
      it "succeeds" do
        result = interactor_class.call(users: [
                                         { username: "john", email: "john@example.com" },
                                         { username: "jane", email: "jane@example.com" }
                                       ])
        expect(result).to be_success
      end
    end

    context "when an item has missing attributes" do
      it "fails with error code including index" do
        result = interactor_class.call(users: [
                                         { username: "john", email: "john@example.com" },
                                         { username: nil, email: "jane@example.com" }
                                       ])
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USERS[1]_USERNAME_IS_REQUIRED" })
      end
    end

    context "when multiple items have errors" do
      it "fails with all error codes" do
        result = interactor_class.call(users: [
                                         { username: nil, email: "john@example.com" },
                                         { username: "jane", email: nil }
                                       ])
        expect(result).to be_failure
        expect(result.errors).to match_array([
                                               { code: "USERS[0]_USERNAME_IS_REQUIRED" },
                                               { code: "USERS[1]_EMAIL_IS_REQUIRED" }
                                             ])
      end
    end

    context "when an array item is not a hash" do
      it "fails with type error" do
        result = interactor_class.call(users: [
                                         { username: "john", email: "john@example.com" },
                                         "not a hash"
                                       ])
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USERS[1]_INVALID_TYPE" })
      end
    end
  end

  describe "nested validation with format" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :user

        validates :user do
          attribute :email, presence: true, format: { with: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i }
        end
      end
    end

    context "when format is valid" do
      it "succeeds" do
        result = interactor_class.call(user: { email: "user@example.com" })
        expect(result).to be_success
      end
    end

    context "when format is invalid" do
      it "fails with error code" do
        result = interactor_class.call(user: { email: "invalid-email" })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USER_EMAIL_INVALID_FORMAT" })
      end
    end
  end

  describe "nested validation with length" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :user

        validates :user do
          attribute :username, length: { minimum: 3, maximum: 20 }
        end
      end
    end

    context "when length is valid" do
      it "succeeds" do
        result = interactor_class.call(user: { username: "john" })
        expect(result).to be_success
      end
    end

    context "when too short" do
      it "fails with error code" do
        result = interactor_class.call(user: { username: "ab" })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USER_USERNAME_BELOW_MIN_LENGTH_3" })
      end
    end

    context "when too long" do
      it "fails with error code" do
        result = interactor_class.call(user: { username: "a" * 21 })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USER_USERNAME_EXCEEDS_MAX_LENGTH_20" })
      end
    end

    context "when exact length is specified" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :user

          validates :user do
            attribute :code, length: { is: 6 }
          end
        end
      end

      it "succeeds when length matches" do
        result = interactor_class.call(user: { code: "123456" })
        expect(result).to be_success
      end

      it "fails when length doesn't match" do
        result = interactor_class.call(user: { code: "12345" })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USER_CODE_MUST_BE_LENGTH_6" })
      end
    end
  end

  describe "nested validation with inclusion" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :user

        validates :user do
          attribute :role, inclusion: { in: %w[admin user guest] }
        end
      end
    end

    context "when value is included" do
      it "succeeds" do
        result = interactor_class.call(user: { role: "admin" })
        expect(result).to be_success
      end
    end

    context "when value is not included" do
      it "fails with error code" do
        result = interactor_class.call(user: { role: "superadmin" })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USER_ROLE_NOT_IN_ALLOWED_VALUES" })
      end
    end
  end

  describe "nested validation with numericality" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :user

        validates :user do
          attribute :age, numericality: { greater_than: 0, less_than: 150 }
        end
      end
    end

    context "when value is numeric and valid" do
      it "succeeds" do
        result = interactor_class.call(user: { age: 25 })
        expect(result).to be_success
      end
    end

    context "when value is not numeric" do
      it "fails with error code" do
        result = interactor_class.call(user: { age: "not a number" })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USER_AGE_MUST_BE_A_NUMBER" })
      end
    end

    context "when value violates greater_than constraint" do
      it "fails with error code" do
        result = interactor_class.call(user: { age: 0 })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USER_AGE_MUST_BE_GREATER_THAN_0" })
      end
    end

    context "when value violates less_than constraint" do
      it "fails with error code" do
        result = interactor_class.call(user: { age: 150 })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USER_AGE_MUST_BE_LESS_THAN_150" })
      end
    end

    context "with greater_than_or_equal_to constraint" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :product

          validates :product do
            attribute :price, numericality: { greater_than_or_equal_to: 0 }
          end
        end
      end

      it "succeeds when value equals constraint" do
        result = interactor_class.call(product: { price: 0 })
        expect(result).to be_success
      end

      it "fails when value is below constraint" do
        result = interactor_class.call(product: { price: -1 })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "PRODUCT_PRICE_MUST_BE_AT_LEAST_0" })
      end
    end

    context "with less_than_or_equal_to constraint" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :product

          validates :product do
            attribute :discount, numericality: { less_than_or_equal_to: 100 }
          end
        end
      end

      it "succeeds when value equals constraint" do
        result = interactor_class.call(product: { discount: 100 })
        expect(result).to be_success
      end

      it "fails when value is above constraint" do
        result = interactor_class.call(product: { discount: 101 })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "PRODUCT_DISCOUNT_MUST_BE_AT_MOST_100" })
      end
    end

    context "with equal_to constraint" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :config

          validates :config do
            attribute :version, numericality: { equal_to: 2 }
          end
        end
      end

      it "succeeds when value equals constraint" do
        result = interactor_class.call(config: { version: 2 })
        expect(result).to be_success
      end

      it "fails when value doesn't equal constraint" do
        result = interactor_class.call(config: { version: 1 })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "CONFIG_VERSION_MUST_BE_EQUAL_TO_2" })
      end
    end
  end

  describe "skip validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :username, :optional_field

        validates :username, presence: true
        validates :optional_field # No validation rules, just tracking
      end
    end

    context "when username is provided but optional_field is not" do
      it "succeeds" do
        result = interactor_class.call(username: "john", optional_field: nil)
        expect(result).to be_success
      end
    end

    context "when username is missing" do
      it "fails only for username" do
        result = interactor_class.call(username: nil, optional_field: nil)
        expect(result).to be_failure
        expect(result.errors).to eq([{ code: "USERNAME_IS_REQUIRED" }])
      end
    end

    context "when optional_field has any value" do
      it "succeeds" do
        result = interactor_class.call(username: "john", optional_field: "anything")
        expect(result).to be_success
      end
    end
  end

  describe "nested validation in default error mode" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :default
        end

        params :user

        validates :user do
          attribute :username, presence: true
          attribute :email, format: { with: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i }
        end
      end
    end

    context "when validation fails" do
      it "returns default error format" do
        result = interactor_class.call(user: { username: nil, email: "invalid" })
        expect(result).to be_failure
        expect(result.errors).to include(
          hash_including(
            attribute: :"user.username",
            type: :blank
          )
        )
        expect(result.errors).to include(
          hash_including(
            attribute: :"user.email",
            type: :invalid
          )
        )
      end
    end
  end

  describe "nested validation with custom messages" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :user

        validates :user do
          attribute :username, presence: { message: "Username is mandatory" }
          attribute :email, format: { with: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i,
                                      message: "Email format is wrong" }
        end
      end
    end

    context "when validation fails in code mode" do
      it "uses custom messages" do
        result = interactor_class.call(user: { username: nil, email: "invalid" })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USER_USERNAME_Username is mandatory" })
        expect(result.errors).to include({ code: "USER_EMAIL_Email format is wrong" })
      end
    end
  end

  describe "complex nested validation scenarios" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :items

        validates :items do
          attribute :name, presence: true, length: { minimum: 2, maximum: 50 }
          attribute :quantity, presence: true, numericality: { greater_than: 0 }
          attribute :status, inclusion: { in: %w[active inactive] }
        end
      end
    end

    context "with array of items" do
      it "validates all items and attributes" do
        result = interactor_class.call(items: [
                                         { name: "Item 1", quantity: 5, status: "active" },
                                         { name: "Item 2", quantity: 10, status: "inactive" }
                                       ])
        expect(result).to be_success
      end

      it "reports errors for specific items and attributes" do
        result = interactor_class.call(items: [
                                         { name: "A", quantity: 0, status: "invalid" },
                                         { name: "", quantity: -5, status: "active" }
                                       ])
        expect(result).to be_failure
        expect(result.errors).to include({ code: "ITEMS[0]_NAME_BELOW_MIN_LENGTH_2" })
        expect(result.errors).to include({ code: "ITEMS[0]_QUANTITY_MUST_BE_GREATER_THAN_0" })
        expect(result.errors).to include({ code: "ITEMS[0]_STATUS_NOT_IN_ALLOWED_VALUES" })
        expect(result.errors).to include({ code: "ITEMS[1]_NAME_IS_REQUIRED" })
        expect(result.errors).to include({ code: "ITEMS[1]_QUANTITY_MUST_BE_GREATER_THAN_0" })
      end
    end
  end

  describe "empty arrays and hashes" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :data

        validates :data do
          attribute :field, presence: true
        end
      end
    end

    context "when array is empty" do
      it "succeeds" do
        result = interactor_class.call(data: [])
        expect(result).to be_success
      end
    end

    context "when hash is empty" do
      it "succeeds (empty hash is treated as not provided when parent has no presence requirement)" do
        result = interactor_class.call(data: {})
        expect(result).to be_success
      end
    end
  end

  describe "numericality with boolean value" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :user

        validates :user do
          attribute :age, numericality: true
        end
      end
    end

    context "when value is numeric" do
      it "succeeds" do
        result = interactor_class.call(user: { age: 25 })
        expect(result).to be_success
      end
    end

    context "when value is not numeric" do
      it "fails" do
        result = interactor_class.call(user: { age: "abc" })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "USER_AGE_MUST_BE_A_NUMBER" })
      end
    end
  end

  describe "optional vs required nested validation" do
    describe "optional nested validation (without presence)" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :filters

          validates :filters do
            attribute :type, presence: true
            attribute :value
          end
        end
      end

      context "when filters is nil" do
        it "succeeds (optional parameter)" do
          result = interactor_class.call(filters: nil)
          expect(result).to be_success
        end
      end

      context "when filters is missing completely" do
        it "succeeds (optional parameter)" do
          result = interactor_class.call({})
          expect(result).to be_success
        end
      end

      context "when filters is an empty hash" do
        it "succeeds (empty hash is treated as not provided when parent has no presence requirement)" do
          result = interactor_class.call(filters: {})
          expect(result).to be_success
        end
      end

      context "when filters is present with valid data" do
        it "succeeds" do
          result = interactor_class.call(filters: { type: "search", value: "test" })
          expect(result).to be_success
        end
      end

      context "when filters is present but nested attribute is missing" do
        it "fails with nested validation error" do
          result = interactor_class.call(filters: { value: "test" })
          expect(result).to be_failure
          expect(result.errors).to include({ code: "FILTERS_TYPE_IS_REQUIRED" })
        end
      end
    end

    describe "required nested validation (with presence: true)" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :filters

          validates :filters, presence: true do
            attribute :type, presence: true
            attribute :value
          end
        end
      end

      context "when filters is nil" do
        it "fails with presence error" do
          result = interactor_class.call(filters: nil)
          expect(result).to be_failure
          expect(result.errors).to include({ code: "FILTERS_IS_REQUIRED" })
        end
      end

      context "when filters is missing completely" do
        it "fails with presence error" do
          result = interactor_class.call({})
          expect(result).to be_failure
          expect(result.errors).to include({ code: "FILTERS_IS_REQUIRED" })
        end
      end

      context "when filters is an empty hash" do
        it "fails with presence error (empty hash is not present)" do
          result = interactor_class.call(filters: {})
          expect(result).to be_failure
          expect(result.errors).to include({ code: "FILTERS_IS_REQUIRED" })
        end
      end

      context "when filters is present with valid data" do
        it "succeeds" do
          result = interactor_class.call(filters: { type: "search", value: "test" })
          expect(result).to be_success
        end
      end

      context "when filters is present but nested attribute is missing" do
        it "fails with nested validation error" do
          result = interactor_class.call(filters: { value: "test" })
          expect(result).to be_failure
          expect(result.errors).to include({ code: "FILTERS_TYPE_IS_REQUIRED" })
        end
      end
    end

    describe "required nested validation with arrays" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :items

          validates :items, presence: true do
            attribute :name, presence: true
          end
        end
      end

      context "when items is nil" do
        it "fails with presence error" do
          result = interactor_class.call(items: nil)
          expect(result).to be_failure
          expect(result.errors).to include({ code: "ITEMS_IS_REQUIRED" })
        end
      end

      context "when items is an empty array" do
        it "fails with presence error (empty array is not present)" do
          result = interactor_class.call(items: [])
          expect(result).to be_failure
          expect(result.errors).to include({ code: "ITEMS_IS_REQUIRED" })
        end
      end

      context "when items is present with valid data" do
        it "succeeds" do
          result = interactor_class.call(items: [{ name: "Item 1" }, { name: "Item 2" }])
          expect(result).to be_success
        end
      end
    end

    describe "required nested validation with halt on first error" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
            config.halt = true
          end

          params :filters

          validates :filters, presence: true do
            attribute :type, presence: true
            attribute :value, presence: true
          end
        end
      end

      context "when filters is nil with halt enabled" do
        it "halts after presence error without running nested validation" do
          result = interactor_class.call(filters: nil)
          expect(result).to be_failure
          # Should only have presence error, not nested validation errors
          expect(result.errors).to eq([{ code: "FILTERS_IS_REQUIRED" }])
        end
      end
    end

    describe "optional nested validation without presence or other rules" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :code
          end

          params :filters

          # Only nested validation, no presence or other rules
          validates :filters do
            attribute :type
          end
        end
      end

      context "when filters is nil" do
        it "succeeds (no validation rules, filters is optional)" do
          result = interactor_class.call(filters: nil)
          expect(result).to be_success
        end
      end

      context "when filters is present" do
        it "succeeds (type has no validation rules)" do
          result = interactor_class.call(filters: { type: nil })
          expect(result).to be_success
        end
      end
    end
  end
end
