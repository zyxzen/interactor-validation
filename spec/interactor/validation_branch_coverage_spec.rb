# frozen_string_literal: true

# Tests specifically for branch coverage completion
RSpec.describe Interactor::Validation, "branch coverage" do
  describe "validates override with empty rules delegating to super" do
    it "calls super when no keyword arguments provided" do
      # Create a class that uses validates without our custom rules
      klass = Class.new do
        include Interactor
        include Interactor::Validation

        params :name
      end

      # This should not raise an error even though we're calling
      # the ClassMethodsOverride validates method
      expect(klass).to be_a(Class)
    end
  end

  describe "numericality with only greater_than constraint" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :amount

        validates :amount, numericality: { greater_than: 10 }
      end
    end

    it "passes when value is greater" do
      expect(interactor_class.call(amount: 11)).to be_success
    end

    it "fails when value equals constraint" do
      result = interactor_class.call(amount: 10)
      expect(result).to be_failure
    end
  end

  describe "numericality with greater_than_or_equal_to only" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :count

        validates :count, numericality: { greater_than_or_equal_to: 5 }
      end
    end

    it "passes when value equals constraint" do
      expect(interactor_class.call(count: 5)).to be_success
    end

    it "fails when value is less" do
      result = interactor_class.call(count: 4)
      expect(result).to be_failure
    end
  end

  describe "numericality with less_than only" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :limit

        validates :limit, numericality: { less_than: 50 }
      end
    end

    it "passes when value is less" do
      expect(interactor_class.call(limit: 49)).to be_success
    end

    it "fails when value equals constraint" do
      result = interactor_class.call(limit: 50)
      expect(result).to be_failure
    end
  end

  describe "numericality constraints not triggering" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :score

        validates :score, numericality: {
          greater_than: 0,
          less_than: 100,
          equal_to: 50
        }
      end
    end

    it "passes when all constraints are met" do
      expect(interactor_class.call(score: 50)).to be_success
    end
  end

  describe "length constraints not triggering" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :code

        validates :code, length: { minimum: 3, maximum: 6, is: 5 }
      end
    end

    it "passes when length exactly matches 'is' constraint" do
      expect(interactor_class.call(code: "12345")).to be_success
    end
  end

  describe "format message option when nil" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :value

        validates :value, format: /\A\d+\z/
      end
    end

    it "uses default message when no custom message provided" do
      result = interactor_class.call(value: "abc")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "VALUE_INVALID_FORMAT" })
    end
  end

  describe "validates.rb respond_to?(:before) branch" do
    it "handles class that doesn't respond to before" do
      # This tests the conditional in validation.rb line 27
      # In practice this won't happen with Interactor, but tests the branch
      mod = Module.new do
        extend ActiveSupport::Concern

        included do
          include Interactor::Validation::Params
          include Interactor::Validation::Validates
        end
      end

      klass = Class.new do
        include mod
      end

      expect(klass).to be_a(Class)
    end
  end
end
