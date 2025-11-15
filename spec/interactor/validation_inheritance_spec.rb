# frozen_string_literal: true

RSpec.describe Interactor::Validation, "inheritance" do
  describe "when included in a base class" do
    let(:base_interactor) do
      Class.new do
        include Interactor
        include Interactor::Validation
      end
    end

    let(:child_interactor) do
      Class.new(base_interactor) do
        configure_validation do |config|
          config.error_mode = :code
        end

        params :username

        validates :username, presence: true
      end
    end

    it "automatically calls validate_params! on child class" do
      result = child_interactor.call(username: "")
      expect(result).to be_failure
      expect(result.errors).to include({ code: "USERNAME_IS_REQUIRED" })
    end

    it "succeeds when params are valid" do
      result = child_interactor.call(username: "john")
      expect(result).to be_success
    end

    it "explicitly verifies validate_params! is called before execution" do
      # Track whether validate_params! was called using instance variable on class
      test_interactor = Class.new(base_interactor) do
        configure_validation do |config|
          config.error_mode = :code
        end

        params :username
        validates :username, presence: true

        @validate_called = false

        class << self
          attr_accessor :validate_called
        end
      end

      test_interactor.define_method(:validate_params!) do
        self.class.validate_called = true
        super()
      end

      test_interactor.call(username: "john")

      expect(test_interactor.validate_called).to be true
    end

    it "verifies validate_params! is called even when validation fails" do
      test_interactor = Class.new(base_interactor) do
        configure_validation do |config|
          config.error_mode = :code
        end

        params :username
        validates :username, presence: true

        @validate_called = false

        class << self
          attr_accessor :validate_called
        end
      end

      test_interactor.define_method(:validate_params!) do
        self.class.validate_called = true
        super()
      end

      test_interactor.call(username: "")

      expect(test_interactor.validate_called).to be true
    end

    it "prevents call method execution when validate_params! fails" do
      # Create an interactor with a call method that should NOT execute
      test_interactor = Class.new(base_interactor) do
        configure_validation do |config|
          config.error_mode = :code
        end

        params :username
        validates :username, presence: true

        def call
          context.call_executed = true
        end
      end

      result = test_interactor.call(username: "")

      # Validation failed, so call method should not have executed
      expect(result).to be_failure
      expect(result.call_executed).to be_nil
    end

    it "allows call method execution when validate_params! succeeds" do
      # Create an interactor with a call method that SHOULD execute
      test_interactor = Class.new(base_interactor) do
        configure_validation do |config|
          config.error_mode = :code
        end

        params :username
        validates :username, presence: true

        def call
          context.call_executed = true
        end
      end

      result = test_interactor.call(username: "john")

      # Validation passed, so call method should have executed
      expect(result).to be_success
      expect(result.call_executed).to be true
    end
  end

  describe "when child class inherits from base with validations" do
    let(:base_interactor) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :username

        validates :username, presence: true
      end
    end

    let(:child_interactor) do
      Class.new(base_interactor) do
        params :email

        validates :email, presence: true
      end
    end

    it "validates both parent and child params" do
      result = child_interactor.call(username: "", email: "")
      expect(result).to be_failure
      expect(result.errors).to match_array([
                                             { code: "USERNAME_IS_REQUIRED" },
                                             { code: "EMAIL_IS_REQUIRED" }
                                           ])
    end

    it "succeeds when all params are valid" do
      result = child_interactor.call(username: "john", email: "john@example.com")
      expect(result).to be_success
    end
  end

  describe "when grandchild inherits from child" do
    let(:base_interactor) do
      Class.new do
        include Interactor
        include Interactor::Validation
      end
    end

    let(:child_interactor) do
      Class.new(base_interactor) do
        configure_validation do |config|
          config.error_mode = :code
        end

        params :username

        validates :username, presence: true
      end
    end

    let(:grandchild_interactor) do
      Class.new(child_interactor) do
        params :email

        validates :email, presence: true
      end
    end

    it "validates all inherited and own params" do
      result = grandchild_interactor.call(username: "", email: "")
      expect(result).to be_failure
      expect(result.errors).to match_array([
                                             { code: "USERNAME_IS_REQUIRED" },
                                             { code: "EMAIL_IS_REQUIRED" }
                                           ])
    end
  end
end
