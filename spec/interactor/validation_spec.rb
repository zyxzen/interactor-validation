# frozen_string_literal: true

RSpec.describe Interactor::Validation do
  it "has a version number" do
    expect(Interactor::Validation::VERSION).not_to be nil
  end

  describe "params declaration" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :username, :password
      end
    end

    it "declares params as class attributes" do
      expect(interactor_class._declared_params).to include(:username, :password)
    end

    it "delegates params to context" do
      context = Interactor::Context.build(username: "john", password: "secret")
      interactor = interactor_class.new(context)

      expect(interactor.username).to eq("john")
      expect(interactor.password).to eq("secret")
    end

    it "does not duplicate params when declared multiple times" do
      interactor_class.params :username
      expect(interactor_class._declared_params.count(:username)).to eq(1)
    end
  end

  describe "validates with presence validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :username, :password

        validates :username, presence: true
        validates :password, presence: true
      end
    end

    context "when params are present" do
      it "succeeds" do
        result = interactor_class.call(username: "john", password: "secret")
        expect(result).to be_success
      end
    end

    context "when params are missing" do
      it "fails with error codes" do
        result = interactor_class.call(username: "", password: nil)
        expect(result).to be_failure
        expect(result.errors).to match_array([
                                               { code: "USERNAME_IS_REQUIRED" },
                                               { code: "PASSWORD_IS_REQUIRED" }
                                             ])
      end
    end
  end

  describe "validates with format validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :email

        validates :email, format: { with: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i }
      end
    end

    context "when format is valid" do
      it "succeeds" do
        result = interactor_class.call(email: "user@example.com")
        expect(result).to be_success
      end
    end

    context "when format is invalid" do
      it "fails with error code" do
        result = interactor_class.call(email: "invalid-email")
        expect(result).to be_failure
        expect(result.errors).to include({ code: "EMAIL_INVALID_FORMAT" })
      end
    end

    context "when value is blank" do
      it "succeeds (skips validation)" do
        result = interactor_class.call(email: "")
        expect(result).to be_success
      end
    end
  end

  describe "validates with length validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :title

        validates :title, length: { minimum: 3, maximum: 50 }
      end
    end

    context "when length is within range" do
      it "succeeds" do
        result = interactor_class.call(title: "Valid Title")
        expect(result).to be_success
      end
    end

    context "when too short" do
      it "fails with error code" do
        result = interactor_class.call(title: "ab")
        expect(result).to be_failure
        expect(result.errors).to include({ code: "TITLE_BELOW_MIN_LENGTH_3" })
      end
    end

    context "when too long" do
      it "fails with error code" do
        result = interactor_class.call(title: "a" * 51)
        expect(result).to be_failure
        expect(result.errors).to include({ code: "TITLE_EXCEEDS_MAX_LENGTH_50" })
      end
    end
  end

  describe "validates with inclusion validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :status

        validates :status, inclusion: { in: %w[active inactive pending] }
      end
    end

    context "when value is included" do
      it "succeeds" do
        result = interactor_class.call(status: "active")
        expect(result).to be_success
      end
    end

    context "when value is not included" do
      it "fails with error code" do
        result = interactor_class.call(status: "invalid")
        expect(result).to be_failure
        expect(result.errors).to include({ code: "STATUS_NOT_IN_ALLOWED_VALUES" })
      end
    end
  end

  describe "validates with numericality validation" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :age

        validates :age, numericality: { greater_than: 0, less_than: 150 }
      end
    end

    context "when value is numeric and within constraints" do
      it "succeeds" do
        result = interactor_class.call(age: 25)
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

    context "when value violates constraints" do
      it "fails with appropriate error code" do
        result = interactor_class.call(age: 0)
        expect(result).to be_failure
        expect(result.errors).to include({ code: "AGE_MUST_BE_GREATER_THAN_0" })
      end
    end
  end

  describe "multiple validations on same param" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :email

        validates :email, presence: true
        validates :email, format: { with: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i }
      end
    end

    context "when all validations pass" do
      it "succeeds" do
        result = interactor_class.call(email: "user@example.com")
        expect(result).to be_success
      end
    end

    context "when multiple validations fail" do
      it "reports all errors" do
        result = interactor_class.call(email: "")
        expect(result).to be_failure
        expect(result.errors.size).to eq(1) # Only presence error since format skips blank values
      end
    end
  end

  describe "integration with interactor call method" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :username

        validates :username, presence: true

        def call
          context.result = "Hello, #{username}!"
        end
      end
    end

    context "when validation passes" do
      it "executes the call method" do
        result = interactor_class.call(username: "John")
        expect(result).to be_success
        expect(result.result).to eq("Hello, John!")
      end
    end

    context "when validation fails" do
      it "does not execute the call method" do
        result = interactor_class.call(username: "")
        expect(result).to be_failure
        expect(result.result).to be_nil
      end
    end
  end
end
