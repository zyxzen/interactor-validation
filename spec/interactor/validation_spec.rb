# frozen_string_literal: true

RSpec.describe Interactor::Validation, "presence validation" do
  describe "basic presence validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :name

        validates :name, presence: true
      end
    end

    context "with valid value" do
      it "succeeds when value is present" do
        result = interactor_class.call(name: "John")
        expect(result).to be_success
      end

      it "succeeds with non-empty string" do
        result = interactor_class.call(name: "Hello World")
        expect(result).to be_success
      end

      it "succeeds with whitespace-containing string" do
        result = interactor_class.call(name: "  content  ")
        expect(result).to be_success
      end
    end

    context "with blank value" do
      it "fails when value is empty string" do
        result = interactor_class.call(name: "")
        expect(result).to be_failure
        expect(result.errors).to include(
          hash_including(
            attribute: :name,
            type: :blank,
            message: "Name can't be blank"
          )
        )
      end

      it "fails when value is nil" do
        result = interactor_class.call(name: nil)
        expect(result).to be_failure
        expect(result.errors).to include(
          hash_including(
            attribute: :name,
            type: :blank,
            message: "Name can't be blank"
          )
        )
      end

      it "fails when param is not provided" do
        result = interactor_class.call({})
        expect(result).to be_failure
        expect(result.errors).to include(
          hash_including(
            attribute: :name,
            type: :blank
          )
        )
      end
    end

    context "with boolean false value" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :is_active

          validates :is_active, presence: true
        end
      end

      it "succeeds when value is false" do
        result = interactor_class.call(is_active: false)
        expect(result).to be_success
      end

      it "succeeds when value is true" do
        result = interactor_class.call(is_active: true)
        expect(result).to be_success
      end
    end
  end

  # describe "presence validation with custom message" do
  #   let(:interactor_class) do
  #     Class.new do
  #       include Interactor
  #       include Interactor::Validation

  #       params :email

  #       validates :email, presence: { message: "Email is required" }
  #     end
  #   end

  #   it "uses custom message when validation fails" do
  #     result = interactor_class.call(email: "")
  #     expect(result).to be_failure
  #     expect(result.errors).to include(
  #       hash_including(
  #         attribute: :email,
  #         type: :blank,
  #         message: "Email Email is required"
  #       )
  #     )
  #   end

  #   it "succeeds when value is present" do
  #     result = interactor_class.call(email: "test@example.com")
  #     expect(result).to be_success
  #   end
  # end

  # describe "presence validation error modes" do
  #   let(:interactor_class) do
  #     Class.new do
  #       include Interactor
  #       include Interactor::Validation

  #       params :username

  #       validates :username, presence: true
  #     end
  #   end

  #   context "with default mode" do
  #     before do
  #       Interactor::Validation.configure do |config|
  #         config.mode = :default
  #       end
  #     end

  #     after do
  #       Interactor::Validation.configuration = Interactor::Validation::Configuration.new
  #     end

  #     it "returns errors with default format" do
  #       result = interactor_class.call(username: "")
  #       expect(result).to be_failure
  #       expect(result.errors).to include(
  #         hash_including(
  #           attribute: :username,
  #           type: :blank,
  #           message: "Username can't be blank"
  #         )
  #       )
  #     end
  #   end

  #   context "with code mode" do
  #     before do
  #       Interactor::Validation.configure do |config|
  #         config.mode = :code
  #       end
  #     end

  #     after do
  #       Interactor::Validation.configuration = Interactor::Validation::Configuration.new
  #     end

  #     it "returns errors with code format" do
  #       result = interactor_class.call(username: "")
  #       expect(result).to be_failure
  #       expect(result.errors).to include(
  #         hash_including(code: "USERNAME_IS_REQUIRED")
  #       )
  #     end
  #   end
  # end

  # describe "presence validation with nested hash" do
  #   let(:interactor_class) do
  #     Class.new do
  #       include Interactor
  #       include Interactor::Validation

  #       params :user

  #       validates :user, presence: true do
  #         attribute :name, presence: true
  #         attribute :email, presence: true
  #       end
  #     end
  #   end

  #   it "validates nested attributes" do
  #     result = interactor_class.call(user: { name: "", email: "" })
  #     expect(result).to be_failure
  #     expect(result.errors).to include(
  #       hash_including(
  #         attribute: :"user.name",
  #         type: :blank,
  #         message: "User name can't be blank"
  #       )
  #     )
  #     expect(result.errors).to include(
  #       hash_including(
  #         attribute: :"user.email",
  #         type: :blank,
  #         message: "User email can't be blank"
  #       )
  #     )
  #   end

  #   it "succeeds when nested attributes are present" do
  #     result = interactor_class.call(user: { name: "John", email: "john@example.com" })
  #     expect(result).to be_success
  #   end

  #   it "fails when parent hash is nil" do
  #     result = interactor_class.call(user: nil)
  #     expect(result).to be_failure
  #     expect(result.errors).to include(
  #       hash_including(
  #         attribute: :user,
  #         type: :blank
  #       )
  #     )
  #   end
  # end

  # describe "presence validation with array elements" do
  #   let(:interactor_class) do
  #     Class.new do
  #       include Interactor
  #       include Interactor::Validation

  #       params :items

  #       validates :items do
  #         attribute :name, presence: true
  #       end
  #     end
  #   end

  #   it "validates each array element" do
  #     result = interactor_class.call(items: [
  #                                      { name: "Widget" },
  #                                      { name: "" },
  #                                      { name: "Gadget" }
  #                                    ])
  #     expect(result).to be_failure
  #     expect(result.errors).to include(
  #       hash_including(
  #         attribute: :"items[1].name",
  #         type: :blank,
  #         message: "Items[1] name can't be blank"
  #       )
  #     )
  #   end

  #   it "succeeds when all elements are valid" do
  #     result = interactor_class.call(items: [
  #                                      { name: "Widget" },
  #                                      { name: "Gadget" }
  #                                    ])
  #     expect(result).to be_success
  #   end
  # end

  # describe "multiple validations with presence" do
  #   let(:interactor_class) do
  #     Class.new do
  #       include Interactor
  #       include Interactor::Validation

  #       params :email, :username, :age

  #       validates :email, presence: true
  #       validates :username, presence: true
  #       validates :age, presence: true
  #     end
  #   end

  #   it "validates all fields" do
  #     result = interactor_class.call(email: "", username: "", age: nil)
  #     expect(result).to be_failure
  #     expect(result.errors.size).to eq(3)
  #     expect(result.errors).to include(
  #       hash_including(attribute: :email, type: :blank)
  #     )
  #     expect(result.errors).to include(
  #       hash_including(attribute: :username, type: :blank)
  #     )
  #     expect(result.errors).to include(
  #       hash_including(attribute: :age, type: :blank)
  #     )
  #   end

  #   it "succeeds when all fields are present" do
  #     result = interactor_class.call(email: "test@example.com", username: "john", age: 30)
  #     expect(result).to be_success
  #   end

  #   it "reports only failed validations" do
  #     result = interactor_class.call(email: "test@example.com", username: "", age: 30)
  #     expect(result).to be_failure
  #     expect(result.errors.size).to eq(1)
  #     expect(result.errors).to include(
  #       hash_including(attribute: :username, type: :blank)
  #     )
  #   end
  # end

  # describe "presence validation with halt configuration" do
  #   let(:interactor_class) do
  #     Class.new do
  #       include Interactor
  #       include Interactor::Validation

  #       params :name, :email

  #       validates :name, presence: true
  #       validates :email, presence: true
  #     end
  #   end

  #   context "with halt enabled" do
  #     before do
  #       Interactor::Validation.configure do |config|
  #         config.halt = true
  #       end
  #     end

  #     after do
  #       Interactor::Validation.configuration = Interactor::Validation::Configuration.new
  #     end

  #     it "stops on first error" do
  #       result = interactor_class.call(name: "", email: "")
  #       expect(result).to be_failure
  #       expect(result.errors.size).to eq(1)
  #     end
  #   end

  #   context "with halt disabled" do
  #     before do
  #       Interactor::Validation.configure do |config|
  #         config.halt = false
  #       end
  #     end

  #     after do
  #       Interactor::Validation.configuration = Interactor::Validation::Configuration.new
  #     end

  #     it "collects all errors" do
  #       result = interactor_class.call(name: "", email: "")
  #       expect(result).to be_failure
  #       expect(result.errors.size).to eq(2)
  #     end
  #   end
  # end

  # describe "presence validation without params declaration" do
  #   let(:interactor_class) do
  #     Class.new do
  #       include Interactor
  #       include Interactor::Validation

  #       validates :title, presence: true
  #     end
  #   end

  #   it "validates without declaring params" do
  #     result = interactor_class.call(title: "")
  #     expect(result).to be_failure
  #     expect(result.errors).to include(
  #       hash_including(attribute: :title, type: :blank)
  #     )
  #   end

  #   it "succeeds when value is present" do
  #     result = interactor_class.call(title: "My Title")
  #     expect(result).to be_success
  #   end
  # end
end
