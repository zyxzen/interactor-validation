# frozen_string_literal: true

RSpec.describe Interactor::Validation, "security features" do
  after do
    # Reset configuration after each test
    Interactor::Validation.reset_configuration!
  end

  describe "ReDoS protection" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :data

        validates :data, format: { with: /\A(a+)+b\z/ } # Potential ReDoS pattern
      end
    end

    context "with safe input" do
      it "validates successfully" do
        result = interactor_class.call(data: "aaab")
        expect(result).to be_success
      end
    end

    context "with regex timeout configured" do
      before do
        Interactor::Validation.configure do |config|
          config.regex_timeout = 0.01 # Very short timeout
        end
      end

      it "protects against slow regex" do
        # This should timeout or fail validation, not hang
        result = nil
        expect do
          result = interactor_class.call(data: "aaaaaaaaaaaaaaaaaaaaaa!")
        end.not_to raise_error

        # Should fail validation (either timeout or format mismatch)
        expect(result).to be_failure if result
      end
    end
  end

  describe "array size limits" do
    before do
      # Set error_mode globally for this test
      Interactor::Validation.configure do |config|
        config.error_mode = :code
      end
    end

    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :items

        validates :items do |v|
          v.attribute :name, presence: true
        end
      end
    end

    context "with array within limits" do
      it "validates successfully" do
        items = Array.new(10) { { name: "Item" } }
        result = interactor_class.call(items: items)
        expect(result).to be_success
      end
    end

    context "with array exceeding limit" do
      before do
        Interactor::Validation.configure do |config|
          config.max_array_size = 5
        end
      end

      it "fails validation" do
        items = Array.new(10) { { name: "Item" } }
        result = interactor_class.call(items: items)
        expect(result).to be_failure
        expect(result.errors).to include(a_hash_including(code: "ITEMS_ARRAY_TOO_LARGE"))
      end
    end
  end

  describe "regex pattern caching" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :email

        validates :email, format: { with: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i }
      end
    end

    context "with caching enabled" do
      before do
        Interactor::Validation.configure do |config|
          config.cache_regex_patterns = true
        end
      end

      it "caches regex patterns" do
        # First call should cache the pattern
        result1 = interactor_class.call(email: "test@example.com")
        expect(result1).to be_success

        # Second call should use cached pattern
        result2 = interactor_class.call(email: "test2@example.com")
        expect(result2).to be_success

        # Cache should have the pattern
        expect(interactor_class._regex_cache).not_to be_empty
      end
    end

    context "with caching disabled" do
      before do
        Interactor::Validation.configure do |config|
          config.cache_regex_patterns = false
        end
      end

      it "does not cache patterns" do
        result = interactor_class.call(email: "test@example.com")
        expect(result).to be_success
      end
    end
  end

  describe "instrumentation" do
    before do
      # Set error_mode globally for this test
      Interactor::Validation.configure do |config|
        config.error_mode = :code
      end
    end

    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :username

        validates :username, presence: true
      end
    end

    context "with instrumentation enabled" do
      before do
        Interactor::Validation.configure do |config|
          config.enable_instrumentation = true
        end
      end

      it "instruments validation" do
        events = []
        subscriber = ActiveSupport::Notifications.subscribe("validate_params.interactor_validation") do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end

        interactor_class.call(username: "test")

        expect(events).not_to be_empty
        expect(events.first.payload).to include(:interactor)

        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
    end

    context "with instrumentation disabled" do
      before do
        Interactor::Validation.configure do |config|
          config.enable_instrumentation = false
        end
      end

      it "does not instrument validation" do
        events = []
        subscriber = ActiveSupport::Notifications.subscribe("validate_params.interactor_validation") do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end

        interactor_class.call(username: "test")

        expect(events).to be_empty

        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
    end
  end

  describe "numeric precision" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :amount

        validates :amount, numericality: { greater_than: 0 }
      end
    end

    context "with integer strings" do
      it "preserves integer precision" do
        result = interactor_class.call(amount: "999999999999999999")
        expect(result).to be_success
      end
    end

    context "with float strings" do
      it "uses float precision" do
        result = interactor_class.call(amount: "123.45")
        expect(result).to be_success
      end
    end
  end

  describe "hash value handling" do
    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :user_data

        validates :user_data do |v|
          v.attribute :active, boolean: true
        end
      end
    end

    context "with false value" do
      it "treats false as valid boolean" do
        result = interactor_class.call(user_data: { active: false })
        expect(result).to be_success
      end
    end

    context "with nil value" do
      it "fails boolean validation for nil" do
        result = interactor_class.call(user_data: { active: nil })
        expect(result).to be_failure
      end
    end

    context "with string keys" do
      it "handles string keys properly" do
        result = interactor_class.call(user_data: { "active" => true })
        expect(result).to be_success
      end
    end
  end

  describe "configuration memoization" do
    before do
      # Set error_mode globally for this test
      Interactor::Validation.configure do |config|
        config.error_mode = :code
      end
    end

    let(:interactor_class) do
      Class.new do
        include Interactor
        include Interactor::Validation

        params :value1, :value2

        validates :value1, presence: true
        validates :value2, presence: true
      end
    end

    it "memoizes config during validation" do
      # Configure halt on first error
      Interactor::Validation.configure do |config|
        config.halt_on_first_error = true
      end

      result = interactor_class.call(value1: "", value2: "")

      # Should halt on first error
      expect(result).to be_failure
      expect(result.errors.size).to eq(1)
    end
  end

  describe "thread safety" do
    let(:interactor_class1) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :field1
        validates :field1, presence: true
      end
    end

    let(:interactor_class2) do
      Class.new do
        include Interactor
        include Interactor::Validation

        configure_validation do |config|
          config.error_mode = :code
        end

        params :field2
        validates :field2, presence: true
      end
    end

    it "handles concurrent validation rule registration" do
      threads = []

      10.times do
        threads << Thread.new do
          Class.new do
            include Interactor
            include Interactor::Validation

            params :test
            validates :test, presence: true
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end
  end
end
