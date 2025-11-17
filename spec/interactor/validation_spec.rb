# frozen_string_literal: true

RSpec.describe Interactor::Validation, "presence validation" do
  describe "basic presence validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure { |config| config.mode = :default }

        params :name

        validates :name, presence: true
      end
    end

    context "with valid value" do
      it "succeeds when value is present" do
        result = interactor_class.call(name: "")
        expect(result).to be_success
      end
    end

    context "with invalid value" do
      it "fails with code format error" do
        result = interactor_class.call(name: "")
        expect(result).to be_failure
        expect(result.errors).to include(
          hash_including(code: "NAME_IS_REQUIRED")
        )
      end
    end
  end

  describe "inline configuration with multiple options" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure do |config|
          config.mode = :code
          config.halt = true
        end

        params :name, :email

        validates :name, presence: true
        validates :email, presence: true
      end
    end

    it "stops on first error when halt is enabled" do
      result = interactor_class.call(name: "", email: "")
      expect(result).to be_failure
      expect(result.errors.size).to eq(1)
      expect(result.errors).to include(
        hash_including(code: "NAME_IS_REQUIRED")
      )
    end
  end
end
