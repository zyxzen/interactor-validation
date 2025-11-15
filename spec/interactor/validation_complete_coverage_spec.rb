# frozen_string_literal: true

RSpec.describe Interactor::Validation, "complete coverage" do
  describe "default_message_for_type covering all error types" do
    let(:base_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :default
        end

        def self.model_name
          ActiveModel::Name.new(self, nil, "TestInteractor")
        end
      end
    end

    it "provides message for not_boolean error" do
      klass = Class.new(base_class) do
        params :flag
        validates :flag, boolean: true
      end

      result = klass.call(flag: "not_boolean")
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("must be a boolean")
    end

    it "provides message for too_long error" do
      klass = Class.new(base_class) do
        params :text
        validates :text, length: { maximum: 5 }
      end

      result = klass.call(text: "too long text")
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("too long")
      expect(result.errors.first[:message]).to include("5")
    end

    it "provides message for too_short error" do
      klass = Class.new(base_class) do
        params :text
        validates :text, length: { minimum: 10 }
      end

      result = klass.call(text: "short")
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("too short")
      expect(result.errors.first[:message]).to include("10")
    end

    it "provides message for wrong_length error" do
      klass = Class.new(base_class) do
        params :code
        validates :code, length: { is: 6 }
      end

      result = klass.call(code: "12345")
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("wrong length")
      expect(result.errors.first[:message]).to include("6")
    end

    it "provides message for inclusion error" do
      klass = Class.new(base_class) do
        params :status
        validates :status, inclusion: { in: %w[active inactive] }
      end

      result = klass.call(status: "pending")
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("not included")
    end

    it "provides message for not_a_number error" do
      klass = Class.new(base_class) do
        params :count
        validates :count, numericality: true
      end

      result = klass.call(count: "abc")
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("not a number")
    end

    it "provides message for greater_than error" do
      klass = Class.new(base_class) do
        params :score
        validates :score, numericality: { greater_than: 10 }
      end

      result = klass.call(score: 5)
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("greater than")
      expect(result.errors.first[:message]).to include("10")
    end

    it "provides message for greater_than_or_equal_to error" do
      klass = Class.new(base_class) do
        params :age
        validates :age, numericality: { greater_than_or_equal_to: 18 }
      end

      result = klass.call(age: 17)
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("greater than or equal to")
      expect(result.errors.first[:message]).to include("18")
    end

    it "provides message for less_than error" do
      klass = Class.new(base_class) do
        params :percent
        validates :percent, numericality: { less_than: 100 }
      end

      result = klass.call(percent: 150)
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("less than")
      expect(result.errors.first[:message]).to include("100")
    end

    it "provides message for less_than_or_equal_to error" do
      klass = Class.new(base_class) do
        params :max_value
        validates :max_value, numericality: { less_than_or_equal_to: 100 }
      end

      result = klass.call(max_value: 101)
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("less than or equal to")
      expect(result.errors.first[:message]).to include("100")
    end

    it "provides message for equal_to error" do
      klass = Class.new(base_class) do
        params :expected
        validates :expected, numericality: { equal_to: 42 }
      end

      result = klass.call(expected: 41)
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("equal to")
      expect(result.errors.first[:message]).to include("42")
    end

    it "provides message for invalid_type error in nested validation" do
      klass = Class.new(base_class) do
        params :data

        validates :data do
          attribute :name, presence: true
        end
      end

      result = klass.call(data: "not_a_hash")
      expect(result).to be_failure
      expect(result.errors.first[:message]).to include("Hash or Array")
    end
  end

  describe "error_code_for covering all error types in code mode" do
    let(:base_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end
      end
    end

    it "generates code for blank error" do
      klass = Class.new(base_class) do
        params :field
        validates :field, presence: true
      end

      result = klass.call(field: "")
      expect(result.errors.first[:code]).to include("IS_REQUIRED")
    end

    it "generates code for not_boolean error" do
      klass = Class.new(base_class) do
        params :flag
        validates :flag, boolean: true
      end

      result = klass.call(flag: "yes")
      expect(result.errors.first[:code]).to include("MUST_BE_BOOLEAN")
    end

    it "generates code for invalid format error" do
      klass = Class.new(base_class) do
        params :email
        validates :email, format: { with: /@/ }
      end

      result = klass.call(email: "notanemail")
      expect(result.errors.first[:code]).to include("INVALID_FORMAT")
    end

    it "generates code for too_long error" do
      klass = Class.new(base_class) do
        params :text
        validates :text, length: { maximum: 5 }
      end

      result = klass.call(text: "toolong")
      expect(result.errors.first[:code]).to include("EXCEEDS_MAX_LENGTH_5")
    end

    it "generates code for too_short error" do
      klass = Class.new(base_class) do
        params :text
        validates :text, length: { minimum: 10 }
      end

      result = klass.call(text: "short")
      expect(result.errors.first[:code]).to include("BELOW_MIN_LENGTH_10")
    end

    it "generates code for wrong_length error" do
      klass = Class.new(base_class) do
        params :code
        validates :code, length: { is: 6 }
      end

      result = klass.call(code: "12345")
      expect(result.errors.first[:code]).to include("MUST_BE_LENGTH_6")
    end

    it "generates code for inclusion error" do
      klass = Class.new(base_class) do
        params :status
        validates :status, inclusion: { in: %w[active inactive] }
      end

      result = klass.call(status: "pending")
      expect(result.errors.first[:code]).to include("NOT_IN_ALLOWED_VALUES")
    end

    it "generates code for not_a_number error" do
      klass = Class.new(base_class) do
        params :count
        validates :count, numericality: true
      end

      result = klass.call(count: "abc")
      expect(result.errors.first[:code]).to include("MUST_BE_A_NUMBER")
    end

    it "generates code for greater_than error" do
      klass = Class.new(base_class) do
        params :score
        validates :score, numericality: { greater_than: 10 }
      end

      result = klass.call(score: 5)
      expect(result.errors.first[:code]).to include("MUST_BE_GREATER_THAN_10")
    end

    it "generates code for greater_than_or_equal_to error" do
      klass = Class.new(base_class) do
        params :age
        validates :age, numericality: { greater_than_or_equal_to: 18 }
      end

      result = klass.call(age: 17)
      expect(result.errors.first[:code]).to include("MUST_BE_AT_LEAST_18")
    end

    it "generates code for less_than error" do
      klass = Class.new(base_class) do
        params :percent
        validates :percent, numericality: { less_than: 100 }
      end

      result = klass.call(percent: 150)
      expect(result.errors.first[:code]).to include("MUST_BE_LESS_THAN_100")
    end

    it "generates code for less_than_or_equal_to error" do
      klass = Class.new(base_class) do
        params :max_value
        validates :max_value, numericality: { less_than_or_equal_to: 100 }
      end

      result = klass.call(max_value: 101)
      expect(result.errors.first[:code]).to include("MUST_BE_AT_MOST_100")
    end

    it "generates code for equal_to error" do
      klass = Class.new(base_class) do
        params :expected
        validates :expected, numericality: { equal_to: 42 }
      end

      result = klass.call(expected: 41)
      expect(result.errors.first[:code]).to include("MUST_BE_EQUAL_TO_42")
    end

    it "generates code for invalid_type error" do
      klass = Class.new(base_class) do
        params :data

        validates :data do
          attribute :name, presence: true
        end
      end

      result = klass.call(data: "not_a_hash")
      expect(result.errors.first[:code]).to include("INVALID_TYPE")
    end

    it "generates code for array too_large error" do
      klass = Class.new(base_class) do
        configure_validation do |config|
          config.error_mode = :code
          config.max_array_size = 2
        end

        params :items

        validates :items do
          attribute :name, presence: true
        end
      end

      result = klass.call(items: [{ name: "a" }, { name: "b" }, { name: "c" }])
      expect(result.errors.first[:code]).to include("ARRAY_TOO_LARGE")
    end
  end

  describe "extract_message method coverage" do
    it "returns nil when options is not a hash" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :field
        validates :field, presence: true # presence: true is not a hash
      end

      result = klass.call(field: "")
      expect(result).to be_failure
      expect(result.errors.first[:code]).to include("IS_REQUIRED")
    end

    it "returns message when options is a hash with message key" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :field
        validates :field, presence: { message: "CUSTOM_MESSAGE" }
      end

      result = klass.call(field: "")
      expect(result).to be_failure
      expect(result.errors.first[:code]).to include("CUSTOM_MESSAGE")
    end
  end

  describe "validates with block for nested validation" do
    it "builds nested rules from block" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :user

        validates :user do
          attribute :name, presence: true
          attribute :email, format: { with: /@/ }
        end
      end

      result = klass.call(user: { name: "", email: "invalid" })
      expect(result).to be_failure
      expect(result.errors.size).to be >= 2
    end
  end

  describe "get_nested_value with symbol and string keys" do
    it "handles symbol keys" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :data

        validates :data do
          attribute :name, presence: true
        end
      end

      result = klass.call(data: { name: "test" })
      expect(result).to be_success
    end

    it "handles string keys" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :data

        validates :data do
          attribute :name, presence: true
        end
      end

      result = klass.call(data: { "name" => "test" })
      expect(result).to be_success
    end

    it "handles missing keys" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :data

        validates :data do
          attribute :name, presence: true
        end
      end

      result = klass.call(data: { other: "value" })
      expect(result).to be_failure
    end
  end

  describe "coerce_to_numeric method" do
    it "preserves Numeric values" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        params :count
        validates :count, numericality: { greater_than: 0 }
      end

      expect(klass.call(count: 42)).to be_success
      expect(klass.call(count: 3.14)).to be_success
    end

    it "converts integer strings to integers" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        params :count
        validates :count, numericality: { greater_than: 0 }
      end

      expect(klass.call(count: "42")).to be_success
    end

    it "converts float strings to floats" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        params :price
        validates :price, numericality: { greater_than: 0 }
      end

      expect(klass.call(price: "3.14")).to be_success
    end
  end

  describe "boolean? method" do
    it "returns true for true" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        params :flag
        validates :flag, boolean: true
      end

      expect(klass.call(flag: true)).to be_success
    end

    it "returns true for false" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        params :flag
        validates :flag, boolean: true
      end

      expect(klass.call(flag: false)).to be_success
    end

    it "returns false for non-boolean values" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :flag
        validates :flag, boolean: true
      end

      expect(klass.call(flag: "yes")).to be_failure
      expect(klass.call(flag: 1)).to be_failure
      expect(klass.call(flag: nil)).to be_failure
    end
  end

  describe "format_attribute_for_code with dots and brackets" do
    it "replaces dots with underscores for nested attributes" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :user

        validates :user do
          attribute :name, presence: true
        end
      end

      result = klass.call(user: { name: "" })
      expect(result).to be_failure
      # Should have underscores/dots for nested attributes
      expect(result.errors.first[:code]).to include("USER")
    end

    it "preserves array indices in brackets" do
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :items

        validates :items do
          attribute :value, presence: true
        end
      end

      result = klass.call(items: [{ value: "" }])
      expect(result).to be_failure
      expect(result.errors.first[:code]).to match(/ITEMS\[0\]/)
    end
  end
end
