# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Validation Halt Feature" do
  describe "halt option in errors.add" do
    context "when using halt: true in custom validations" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email, :age

          validate :check_username_and_email

          validates :age, presence: true

          def check_username_and_email
            # Add error with halt: true
            errors.add(:username, "is required", halt: true) if context.username.blank?

            # This should not be reached if halt is triggered
            errors.add(:email, "is required") if context.email.blank?
          end
        end
      end

      it "halts validation immediately when halt: true is used" do
        result = interactor_class.call(username: "", email: "", age: "")
        # Only username error should be present, age validation should not run
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:username)
      end

      it "continues validation when halt: false (default)" do
        interactor_class = Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email

          validate :check_params

          def check_params
            errors.add(:username, "is required") if context.username.blank?
            errors.add(:email, "is required") if context.email.blank?
          end
        end

        result = interactor_class.call(username: "", email: "")
        expect(result.errors.size).to eq(2)
      end
    end

    context "when using halt: true with nested attribute paths" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email

          validate :custom_validation

          def custom_validation
            # Use errors.add with nested attribute path and halt
            errors.add(:"user.username", "is required", halt: true) if context.username.blank?

            # This will not be reached due to halt above
            errors.add(:"user.email", "is required") if context.email.blank?
          end
        end
      end

      it "halts validation when halt: true is used with nested attribute paths" do
        result = interactor_class.call(username: "", email: "")
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:"user.username")
      end
    end
  end

  describe "parameter-level halt behavior" do
    context "when halt is triggered within a parameter's validations" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email

          validates :username, presence: { message: "is required" },
                               format: { with: /\A[a-z]+\z/, message: "must be lowercase" },
                               length: { minimum: 5, message: "too short" }

          validates :email, presence: true

          validate :add_username_error_with_halt

          def add_username_error_with_halt
            # Add a custom error with halt if username exists but is invalid
            return if context.username.blank?

            return unless context.username.length < 3

            errors.add(:username, "must be at least 3 chars", halt: true)
          end
        end
      end

      it "stops checking other rules for the same parameter when halt is triggered" do
        result = interactor_class.call(username: "ab", email: "test@example.com")
        # Should only have the halt error, not format or length errors
        username_errors = result.errors.select { |e| e[:attribute] == :username }
        expect(username_errors.size).to eq(1)
        expect(username_errors.first[:message]).to eq("must be at least 3 chars")
      end
    end

    context "when global halt config is enabled" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email

          validates :username, presence: true,
                               format: { with: /\A[a-z]+\z/ },
                               length: { minimum: 5 }

          validates :email, presence: true

          configure_validation do |config|
            config.halt = true
          end
        end
      end

      it "stops after first validation error within a parameter" do
        result = interactor_class.call(username: "", email: "")
        # Should stop after presence validation fails for username
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:username)
      end
    end
  end

  describe "global-level halt behavior" do
    context "when halt config is true" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email, :age

          validates :username, presence: true
          validates :email, presence: true
          validates :age, presence: true

          configure_validation do |config|
            config.halt = true
          end
        end
      end

      it "stops validating subsequent parameters after first error" do
        result = interactor_class.call(username: "", email: "", age: "")
        # Should only have username error, not email or age
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:username)
      end
    end

    context "when halt config is false" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email, :age

          validates :username, presence: true
          validates :email, presence: true
          validates :age, presence: true

          configure_validation do |config|
            config.halt = false
          end
        end
      end

      it "collects all validation errors" do
        result = interactor_class.call(username: "", email: "", age: "")
        expect(result.errors.size).to eq(3)
      end
    end
  end

  describe "backward compatibility" do
    context "when using halt_on_first_error (deprecated)" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email, :age

          validates :username, presence: true
          validates :email, presence: true
          validates :age, presence: true

          configure_validation do |config|
            config.halt_on_first_error = true
          end
        end
      end

      it "works the same as halt config" do
        result = interactor_class.call(username: "", email: "", age: "")
        expect(result.errors.size).to eq(1)
      end
    end

    context "when reading halt_on_first_error" do
      it "returns the same value as halt" do
        Interactor::Validation.configure do |config|
          config.halt = true
        end

        expect(Interactor::Validation.configuration.halt_on_first_error).to eq(true)
        expect(Interactor::Validation.configuration.halt).to eq(true)

        Interactor::Validation.reset_configuration!
      end
    end

    context "when setting halt_on_first_error" do
      it "sets the halt value" do
        Interactor::Validation.configure do |config|
          config.halt_on_first_error = true
        end

        expect(Interactor::Validation.configuration.halt).to eq(true)
        expect(Interactor::Validation.configuration.halt_on_first_error).to eq(true)

        Interactor::Validation.reset_configuration!
      end
    end
  end

  describe "halt priority" do
    context "when both halt: true and global halt: false" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email

          validates :email, presence: true

          configure_validation do |config|
            config.halt = false
          end

          validate :check_username

          def check_username
            return unless context.username.blank?

            errors.add(:username, "is required", halt: true)
          end
        end
      end

      it "halt: true takes precedence over global config" do
        result = interactor_class.call(username: "", email: "")
        # Should only have username error because halt: true was used
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:username)
      end
    end
  end

  describe "halt with code error mode" do
    context "when using halt with error_mode: :code" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email

          validates :username, presence: true
          validates :email, presence: true

          configure_validation do |config|
            config.error_mode = :code
          end

          validate :check_username_with_halt

          def check_username_with_halt
            return unless context.username.present?

            return unless context.username.length < 3

            errors.add(:username, "TOO_SHORT", halt: true)
          end
        end
      end

      it "halts validation with code-formatted errors" do
        result = interactor_class.call(username: "ab", email: "")
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:code]).to eq("USERNAME_TOO_SHORT")
      end
    end
  end

  describe "halt with multiple validation types" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :username

        validates :username, presence: true,
                             format: { with: /\A[a-z]+\z/ },
                             length: { minimum: 5, maximum: 20 }

        configure_validation do |config|
          config.halt = true
        end
      end
    end

    it "stops after first validation type fails" do
      result = interactor_class.call(username: "AB")
      # Should only have one error (presence passes, but format fails)
      expect(result.errors.size).to eq(1)
      expect(result.errors.first[:attribute]).to eq(:username)
    end
  end

  describe "halt without explicit return statements" do
    context "when using halt without return in authentication scenario" do
      # Mock User class for testing
      let(:user_class) do
        Struct.new(:authenticated) do
          def authenticate(password)
            password == "correct"
          end
        end
      end

      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :user, :password

          validate :authenticate_user

          def authenticate_user
            errors.add(:unknown, :user, halt: true) unless context.user
            errors.add(:incorrect, :password, halt: true) unless context.user&.authenticate(context.password)
          end
        end
      end

      it "halts on first error without explicit return" do
        result = interactor_class.call(user: nil, password: "correct")
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:unknown)
      end

      it "halts on second error when first passes" do
        user = user_class.new
        result = interactor_class.call(user: user, password: "wrong")
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:incorrect)
      end

      it "succeeds when both validations pass" do
        user = user_class.new
        result = interactor_class.call(user: user, password: "correct")
        expect(result.success?).to be true
      end
    end
  end

  describe "halt with declarative validations" do
    context "when halt is set for a rule and validation fails" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username, :email

          validates :username, presence: true
          validates :email, presence: true

          configure_validation do |config|
            config.halt = true
          end
        end
      end

      it "stops after first parameter fails when halt config is set" do
        result = interactor_class.call(username: "", email: "")
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:username)
      end
    end

    context "when errors.add is called multiple times in same validation" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :username

          validate :multi_error_validation

          def multi_error_validation
            return if context.username.present?

            errors.add(:username, "error 1")
            errors.add(:username, "error 2")
            errors.add(:username, "error 3")
          end
        end
      end

      it "collects all errors when halt is not used" do
        result = interactor_class.call(username: "")
        username_errors = result.errors.select { |e| e[:attribute] == :username }
        expect(username_errors.size).to eq(3)
      end
    end

    context "when errors.add has halt with options hash" do
      let(:interactor_class) do
        Class.new do
          include Interactor
          include Interactor::Validation

          params :age

          validate :check_age

          def check_age
            return unless context.age.present?

            errors.add(:age, :too_young, count: 18, halt: true) if context.age < 18

            errors.add(:age, "too old") if context.age > 100
          end
        end
      end

      it "handles halt option mixed with other options" do
        result = interactor_class.call(age: 10)
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:attribute]).to eq(:age)
      end
    end
  end
end
