# frozen_string_literal: true

RSpec.describe Interactor::Validation, "boolean validation" do
  describe "validates with boolean validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :is_active

        validates :is_active, boolean: true
      end
    end

    context "when value is true" do
      it "succeeds" do
        result = interactor_class.call(is_active: true)
        expect(result).to be_success
      end
    end

    context "when value is false" do
      it "succeeds" do
        result = interactor_class.call(is_active: false)
        expect(result).to be_success
      end
    end

    context "when value is nil" do
      it "fails with error code" do
        result = interactor_class.call(is_active: nil)
        expect(result).to be_failure
        expect(result.errors).to include({ code: "IS_ACTIVE_MUST_BE_BOOLEAN" })
      end
    end

    context "when value is a string" do
      it "fails with error code" do
        result = interactor_class.call(is_active: "true")
        expect(result).to be_failure
        expect(result.errors).to include({ code: "IS_ACTIVE_MUST_BE_BOOLEAN" })
      end
    end

    context "when value is a number" do
      it "fails with error code" do
        result = interactor_class.call(is_active: 1)
        expect(result).to be_failure
        expect(result.errors).to include({ code: "IS_ACTIVE_MUST_BE_BOOLEAN" })
      end
    end

    context "when value is missing from context" do
      it "fails with error code" do
        result = interactor_class.call({})
        expect(result).to be_failure
        expect(result.errors).to include({ code: "IS_ACTIVE_MUST_BE_BOOLEAN" })
      end
    end
  end

  describe "boolean validation with custom message" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :enabled

        validates :enabled, boolean: { message: "Must be true or false" }
      end
    end

    context "when validation fails in code mode" do
      it "uses custom message" do
        result = interactor_class.call(enabled: "yes")
        expect(result).to be_failure
        expect(result.errors).to include({ code: "ENABLED_Must be true or false" })
      end
    end
  end

  describe "boolean validation in default error mode" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :default
        end

        params :is_admin

        validates :is_admin, boolean: true
      end
    end

    context "when validation fails" do
      it "returns default error format" do
        result = interactor_class.call(is_admin: "no")
        expect(result).to be_failure
        expect(result.errors).to include(
          hash_including(
            attribute: :is_admin,
            type: :not_boolean
          )
        )
      end
    end
  end

  describe "boolean validation combined with presence" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :terms_accepted

        validates :terms_accepted, presence: true, boolean: true
      end
    end

    context "when value is true" do
      it "succeeds" do
        result = interactor_class.call(terms_accepted: true)
        expect(result).to be_success
      end
    end

    context "when value is false" do
      it "succeeds (false is a valid boolean)" do
        result = interactor_class.call(terms_accepted: false)
        expect(result).to be_success
      end
    end

    context "when value is nil" do
      it "fails with both presence and boolean errors" do
        result = interactor_class.call(terms_accepted: nil)
        expect(result).to be_failure
        expect(result.errors).to include({ code: "TERMS_ACCEPTED_IS_REQUIRED" })
        expect(result.errors).to include({ code: "TERMS_ACCEPTED_MUST_BE_BOOLEAN" })
      end
    end
  end

  describe "nested boolean validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :settings

        validates :settings do
          attribute :enabled, boolean: true
          attribute :verified, boolean: true
        end
      end
    end

    context "when all boolean values are valid" do
      it "succeeds" do
        result = interactor_class.call(settings: { enabled: true, verified: false })
        expect(result).to be_success
      end
    end

    context "when a boolean value is invalid" do
      it "fails with error code" do
        result = interactor_class.call(settings: { enabled: "yes", verified: false })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "SETTINGS_ENABLED_MUST_BE_BOOLEAN" })
      end
    end

    context "when multiple boolean values are invalid" do
      it "fails with all error codes" do
        result = interactor_class.call(settings: { enabled: 1, verified: 0 })
        expect(result).to be_failure
        expect(result.errors).to match_array([
                                               { code: "SETTINGS_ENABLED_MUST_BE_BOOLEAN" },
                                               { code: "SETTINGS_VERIFIED_MUST_BE_BOOLEAN" }
                                             ])
      end
    end
  end

  describe "nested boolean validation in arrays" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :items

        validates :items do
          attribute :active, boolean: true
        end
      end
    end

    context "when all items have valid boolean values" do
      it "succeeds" do
        result = interactor_class.call(items: [
                                         { active: true },
                                         { active: false }
                                       ])
        expect(result).to be_success
      end
    end

    context "when an item has invalid boolean value" do
      it "fails with error code including index" do
        result = interactor_class.call(items: [
                                         { active: true },
                                         { active: "yes" }
                                       ])
        expect(result).to be_failure
        expect(result.errors).to include({ code: "ITEMS[1]_ACTIVE_MUST_BE_BOOLEAN" })
      end
    end
  end

  describe "boolean validation with custom message in nested attributes" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :config

        validates :config do
          attribute :debug, boolean: { message: "Debug must be boolean" }
        end
      end
    end

    context "when validation fails" do
      it "uses custom message" do
        result = interactor_class.call(config: { debug: "on" })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "CONFIG_DEBUG_Debug must be boolean" })
      end
    end
  end
end

RSpec.describe Interactor::Validation, "numericality: true validation" do
  describe "validates with numericality: true" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :age

        validates :age, numericality: true
      end
    end

    context "when value is an integer" do
      it "succeeds" do
        result = interactor_class.call(age: 25)
        expect(result).to be_success
      end
    end

    context "when value is a float" do
      it "succeeds" do
        result = interactor_class.call(age: 25.5)
        expect(result).to be_success
      end
    end

    context "when value is a numeric string" do
      it "succeeds" do
        result = interactor_class.call(age: "42")
        expect(result).to be_success
      end
    end

    context "when value is a float string" do
      it "succeeds" do
        result = interactor_class.call(age: "3.14")
        expect(result).to be_success
      end
    end

    context "when value is negative" do
      it "succeeds (no constraints)" do
        result = interactor_class.call(age: -10)
        expect(result).to be_success
      end
    end

    context "when value is zero" do
      it "succeeds (no constraints)" do
        result = interactor_class.call(age: 0)
        expect(result).to be_success
      end
    end

    context "when value is not numeric" do
      it "fails with error code" do
        result = interactor_class.call(age: "not a number")
        expect(result).to be_failure
        expect(result.errors).to include({ code: "AGE_MUST_BE_A_NUMBER" })
      end
    end

    context "when value is nil" do
      it "succeeds (skips validation for blank values)" do
        result = interactor_class.call(age: nil)
        expect(result).to be_success
      end
    end

    context "when value is empty string" do
      it "succeeds (skips validation for blank values)" do
        result = interactor_class.call(age: "")
        expect(result).to be_success
      end
    end
  end

  describe "numericality: true with presence validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :count

        validates :count, presence: true, numericality: true
      end
    end

    context "when value is numeric" do
      it "succeeds" do
        result = interactor_class.call(count: 10)
        expect(result).to be_success
      end
    end

    context "when value is nil" do
      it "fails with presence error" do
        result = interactor_class.call(count: nil)
        expect(result).to be_failure
        expect(result.errors).to include({ code: "COUNT_IS_REQUIRED" })
      end
    end

    context "when value is not numeric" do
      it "fails with numericality error" do
        result = interactor_class.call(count: "abc")
        expect(result).to be_failure
        expect(result.errors).to include({ code: "COUNT_MUST_BE_A_NUMBER" })
      end
    end
  end

  describe "nested numericality: true validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :product

        validates :product do
          attribute :price, numericality: true
          attribute :quantity, numericality: true
        end
      end
    end

    context "when all numeric values are valid" do
      it "succeeds" do
        result = interactor_class.call(product: { price: 29.99, quantity: 5 })
        expect(result).to be_success
      end
    end

    context "when a numeric value is invalid" do
      it "fails with error code" do
        result = interactor_class.call(product: { price: "free", quantity: 5 })
        expect(result).to be_failure
        expect(result.errors).to include({ code: "PRODUCT_PRICE_MUST_BE_A_NUMBER" })
      end
    end

    context "when value is zero or negative" do
      it "succeeds (no constraints)" do
        result = interactor_class.call(product: { price: -10.50, quantity: 0 })
        expect(result).to be_success
      end
    end
  end

  describe "numericality: true in default error mode" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :default
        end

        params :score

        validates :score, numericality: true
      end
    end

    context "when validation fails" do
      it "returns default error format" do
        result = interactor_class.call(score: "invalid")
        expect(result).to be_failure
        expect(result.errors).to include(
          hash_including(
            attribute: :score,
            type: :not_a_number
          )
        )
      end
    end
  end
end
