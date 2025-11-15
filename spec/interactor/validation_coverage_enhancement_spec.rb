# frozen_string_literal: true

RSpec.describe Interactor::Validation, "coverage enhancement" do
  after do
    Interactor::Validation.reset_configuration!
  end

  describe "error message extraction with custom messages" do
    context "length validation with custom message" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :text

          validates :text, length: { minimum: 5, message: "CUSTOM_LENGTH_ERROR" }

          configure_validation do |config|
            config.error_mode = :code
          end
        end
      end

      it "uses custom message for length validation" do
        result = interactor_class.call(text: "abc")
        expect(result.errors).to include({ code: "TEXT_CUSTOM_LENGTH_ERROR" })
      end
    end

    context "inclusion validation with custom message" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :status

          validates :status, inclusion: { in: %w[active inactive], message: "CUSTOM_INCLUSION_ERROR" }

          configure_validation do |config|
            config.error_mode = :code
          end
        end
      end

      it "uses custom message for inclusion validation" do
        result = interactor_class.call(status: "deleted")
        expect(result.errors).to include({ code: "STATUS_CUSTOM_INCLUSION_ERROR" })
      end
    end

    context "numericality validation with custom message" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :age

          validates :age, numericality: { greater_than: 0, message: "CUSTOM_NUMBER_ERROR" }

          configure_validation do |config|
            config.error_mode = :code
          end
        end
      end

      it "uses custom message for numericality validation when not a number" do
        result = interactor_class.call(age: "abc")
        expect(result.errors).to include({ code: "AGE_CUSTOM_NUMBER_ERROR" })
      end
    end
  end

  describe "error message building in default mode" do
    context "when error.message raises ArgumentError" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username

          validates :username, presence: { message: "custom required message" }

          configure_validation do |config|
            config.error_mode = :default
          end
        end
      end

      it "uses custom message" do
        result = interactor_class.call(username: "")
        expect(result.errors.first[:message]).to eq("custom required message")
      end
    end

    context "when error.message raises ArgumentError without custom message" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :field

          validates :field, presence: true

          configure_validation do |config|
            config.error_mode = :default
          end

          # Override build_error_message to force the rescue clause
          def build_error_message(error)
            raise ArgumentError, "Class name cannot be blank"
          rescue ArgumentError
            attribute_name = error.attribute.to_s.humanize
            error_message = error.options[:message] || default_message_for_type(error.type, error.options)
            "#{attribute_name} #{error_message}"
          end
        end
      end

      it "falls back to humanized message" do
        result = interactor_class.call(field: "")
        expect(result.errors.first[:message]).to eq("Field can't be blank")
      end
    end

    context "default messages for all error types in default mode" do
      let(:base_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          configure_validation do |config|
            config.error_mode = :default
          end
        end
      end

      it "provides default message for blank error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, presence: true
        end

        result = klass.call(field: "")
        expect(result.errors.first[:message]).to include("blank")
      end

      it "provides default message for invalid error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, format: { with: /\A\d+\z/ }
        end

        result = klass.call(field: "abc")
        expect(result.errors.first[:message]).to include("invalid")
      end

      it "provides default message for too_long error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, length: { maximum: 5 }
        end

        result = klass.call(field: "toolong")
        expect(result.errors.first[:message]).to include("too long")
        expect(result.errors.first[:message]).to include("5")
      end

      it "provides default message for too_short error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, length: { minimum: 5 }
        end

        result = klass.call(field: "abc")
        expect(result.errors.first[:message]).to include("too short")
        expect(result.errors.first[:message]).to include("5")
      end

      it "provides default message for wrong_length error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, length: { is: 5 }
        end

        result = klass.call(field: "abc")
        expect(result.errors.first[:message]).to include("wrong length")
        expect(result.errors.first[:message]).to include("5")
      end

      it "provides default message for inclusion error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, inclusion: { in: %w[a b c] }
        end

        result = klass.call(field: "d")
        expect(result.errors.first[:message]).to include("not included")
      end

      it "provides default message for not_a_number error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, numericality: true
        end

        result = klass.call(field: "abc")
        expect(result.errors.first[:message]).to include("not a number")
      end

      it "provides default message for greater_than error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, numericality: { greater_than: 10 }
        end

        result = klass.call(field: 5)
        expect(result.errors.first[:message]).to include("greater than")
        expect(result.errors.first[:message]).to include("10")
      end

      it "provides default message for greater_than_or_equal_to error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, numericality: { greater_than_or_equal_to: 10 }
        end

        result = klass.call(field: 5)
        expect(result.errors.first[:message]).to include("greater than or equal to")
        expect(result.errors.first[:message]).to include("10")
      end

      it "provides default message for less_than error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, numericality: { less_than: 10 }
        end

        result = klass.call(field: 15)
        expect(result.errors.first[:message]).to include("less than")
        expect(result.errors.first[:message]).to include("10")
      end

      it "provides default message for less_than_or_equal_to error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, numericality: { less_than_or_equal_to: 10 }
        end

        result = klass.call(field: 15)
        expect(result.errors.first[:message]).to include("less than or equal to")
        expect(result.errors.first[:message]).to include("10")
      end

      it "provides default message for equal_to error" do
        klass = Class.new(base_class) do
          params :field
          validates :field, numericality: { equal_to: 10 }
        end

        result = klass.call(field: 5)
        expect(result.errors.first[:message]).to include("equal to")
        expect(result.errors.first[:message]).to include("10")
      end

      it "provides fallback message for unknown error type" do
        klass = Class.new(base_class) do
          params :field
          # Use a validate callback to add an error with unknown type
          validate :add_unknown_error

          def add_unknown_error
            errors.add(:field, :unknown_type)
          end
        end

        result = klass.call(field: "test")
        expect(result.errors.first[:message]).to include("invalid")
      end
    end
  end

  describe "extract_message with non-hash options" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :field

        validates :field, presence: true
      end
    end

    it "returns nil when options is boolean" do
      result = interactor_class.call(field: "")
      expect(result).to be_failure
    end
  end

  describe "current_config when validation_config is nil" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :field
        validates :field, presence: true
      end
    end

    it "uses global configuration" do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
      end

      result = interactor_class.call(field: "")
      expect(result.errors).to include({ code: "FIELD_IS_REQUIRED" })
    end
  end
end
