# frozen_string_literal: true

RSpec.describe Interactor::Validation, "presence validation" do
  describe "basic presence validation" do
    let(:base_interactor) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure { |config| config.mode = :code }
      end
    end

    let(:interactor_class) do
      Class.new(base_interactor) do
        params :name

        validates :name, presence: true
      end
    end

    context "with invalid value" do
      it "fails when value is blank" do
        result = interactor_class.call(name: "")
        expect(result).to be_failure
        expect(result.errors).to be_present
      end

      it "fails when value is nil" do
        result = interactor_class.call(name: nil)
        expect(result).to be_failure
        expect(result.errors).to be_present
      end
    end

    context "with valid value" do
      it "succeeds when value is present" do
        result = interactor_class.call(name: "John Doe")
        expect(result).to be_success
        expect(result.errors).to be_nil
      end
    end

    context "inheritance behavior" do
      it "inherits configuration from base class" do
        expect(interactor_class._validation_config[:mode]).to eq(:default)
      end

      it "inherits validations from base class and adds its own" do
        expect(interactor_class._validations[:name]).to include(presence: true)
      end

      it "does not modify parent class when child adds validations" do
        # Parent should not have :name in validations
        expect(base_interactor._validations.keys).not_to include(:name)
        # Child should have :name
        expect(interactor_class._validations.keys).to include(:name)
      end
    end
  end
end
