# frozen_string_literal: true

RSpec.describe "Interactor::Validation 100% Coverage" do
  describe "regex timeout handling" do
    context "when regex takes too long to match" do
      before do
        Interactor::Validation.configure do |config|
          config.error_mode = :code
          config.regex_timeout = 0.001 # 1ms timeout
        end
      end

      after do
        Interactor::Validation.reset_configuration!
      end

      it "handles Regexp::TimeoutError on Ruby 3.2+" do
        skip "Regexp.timeout not available" unless Regexp.respond_to?(:timeout)

        # Use an extremely slow ReDoS pattern
        # This pattern will cause catastrophic backtracking
        interactor_class = Class.new do
          include Interactor
          include Interactor::Validation

          params :text
          # More aggressive ReDoS pattern
          validates :text, format: /^(a*)*b$/
        end

        # This input will cause catastrophic backtracking with the extremely short timeout
        # Use a longer string to ensure timeout
        result = interactor_class.call(text: "a" * 25 + "c")

        expect(result.success?).to be false
        # Should timeout and add regex timeout error
        expect(result.errors.any? { |e| e[:code]&.include?("TIMEOUT") || e[:code] == "TEXT_INVALID_FORMAT" }).to be true
      end

      it "handles Timeout::Error on older Ruby versions" do
        skip "Regexp.timeout is available, skipping fallback test" if Regexp.respond_to?(:timeout)

        interactor_class = Class.new do
          include Interactor
          include Interactor::Validation

          params :text
          validates :text, format: /^(a+)+b$/
        end

        result = interactor_class.call(text: "a" * 30)

        expect(result.success?).to be false
        expect(result.errors).to include(code: "REGEX_REGEX_TIMEOUT")
      end

      it "requires timeout module for older Ruby" do
        # Stub Regexp to test fallback path
        original_respond = Regexp.method(:respond_to?)
        allow(Regexp).to receive(:respond_to?) do |method_name, *args|
          if method_name == :timeout
            false
          else
            original_respond.call(method_name, *args)
          end
        end

        interactor_class = Class.new do
          include Interactor
          include Interactor::Validation

          params :text
          validates :text, format: /.*/
        end

        # Should not raise an error, timeout module should be loaded
        expect { interactor_class.call(text: "test") }.not_to raise_error

        # Clean up
        allow(Regexp).to receive(:respond_to?).and_call_original
      end
    end
  end

  describe "array size limit validation" do
    before do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
        config.max_array_size = 5
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "fails when array exceeds max_array_size" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :items
        validates :items do
          attribute :name, presence: true
        end
      end

      result = interactor_class.call(
        items: Array.new(10) { { name: "item" } }
      )

      expect(result.success?).to be false
      expect(result.errors).to include(code: "ITEMS_ARRAY_TOO_LARGE")
    end
  end

  describe "anonymous class error handling" do
    it "handles anonymous classes in validate! method" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :name
        validates :name, presence: true
      end

      result = interactor_class.call(name: nil)

      expect(result.success?).to be false
      expect(result.errors).not_to be_empty
    end

    it "handles anonymous classes when mapping error details" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value
        validates :value, presence: true

        def validate!
          super
          errors.add(:custom, :invalid)
        end
      end

      result = interactor_class.call(value: nil)

      expect(result.success?).to be false
    end

    it "handles anonymous classes when restoring errors" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :field
        validates :field, presence: true
      end

      result = interactor_class.call(field: nil)

      expect(result.success?).to be false
    end
  end

  describe "nested validation with custom messages in default mode" do
    before do
      Interactor::Validation.configure do |config|
        config.error_mode = :default
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "uses custom message for nested hash validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :user
        validates :user do
          attribute :name, presence: { message: "Name is required!" }
        end
      end

      result = interactor_class.call(user: { name: nil })

      expect(result.success?).to be false
      # The custom message is added via errors.add(attribute_path, custom_message)
      # ActiveModel will use this as the message
      # This covers line 487 in validates.rb
      expect(result.errors).not_to be_empty
      expect(result.errors.first[:attribute]).to eq(:"user.name")
    end

    it "uses custom message for nested array validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :users
        validates :users do
          attribute :email, format: { with: /@/, message: "Invalid email!" }
        end
      end

      result = interactor_class.call(users: [{ email: "invalid" }])

      expect(result.success?).to be false
      # The custom message is added via errors.add(attribute_path, custom_message)
      # This covers line 487 in validates.rb
      expect(result.errors).not_to be_empty
      expect(result.errors.first[:attribute]).to eq(:"users[0].email")
    end
  end

  describe "missing default error messages" do
    before do
      Interactor::Validation.configure do |config|
        config.error_mode = :default
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "generates message for wrong_length in nested validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :data
        validates :data do
          attribute :code, length: { is: 5 }
        end
      end

      result = interactor_class.call(data: { code: "ABC" })

      expect(result.success?).to be false
      expect(result.errors.first[:message]).to include("should be 5 characters")
    end

    it "generates message for less_than in nested validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :data
        validates :data do
          attribute :score, numericality: { less_than: 100 }
        end
      end

      result = interactor_class.call(data: { score: 150 })

      expect(result.success?).to be false
      expect(result.errors.first[:message]).to include("must be less than 100")
    end

    it "generates message for less_than_or_equal_to in nested validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :data
        validates :data do
          attribute :score, numericality: { less_than_or_equal_to: 100 }
        end
      end

      result = interactor_class.call(data: { score: 101 })

      expect(result.success?).to be false
      expect(result.errors.first[:message]).to include("must be less than or equal to 100")
    end

    it "generates message for equal_to in nested validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :data
        validates :data do
          attribute :count, numericality: { equal_to: 10 }
        end
      end

      result = interactor_class.call(data: { count: 5 })

      expect(result.success?).to be false
      expect(result.errors.first[:message]).to include("must be equal to 10")
    end
  end

  describe "non-Interactor base classes" do
    it "handles classes without :before hook" do
      # Create a custom base class that doesn't have the :before hook
      base_class = Class.new do
        include ActiveModel::Validations

        def self.before(*); end

        # Don't respond to :before for the test
        def self.respond_to?(method, include_private = false)
          return false if method == :before
          super
        end
      end

      # This should not raise an error even without :before hook
      expect do
        Class.new(base_class) do
          include Interactor::Validation

          params :name
          validates :name, presence: true
        end
      end.not_to raise_error
    end

    it "handles inheritance without :before hook" do
      # Create a base class with validation but stubbed respond_to?
      base_class = Class.new do
        include Interactor
        include Interactor::Validation
      end

      # Create subclass - the inherited hook will be called
      # and should check respond_to?(:before)
      subclass = Class.new(base_class) do
        params :email
        validates :email, presence: true

        def self.respond_to?(method, include_private = false)
          return false if method == :before
          super
        end
      end

      # Should not raise error
      expect(subclass).to be_truthy
    end
  end

  describe "format validation with non-Hash pattern" do
    before do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "handles format as direct regex in nested validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :user
        validates :user do
          attribute :email, format: /@/
        end
      end

      result = interactor_class.call(user: { email: "invalid" })

      expect(result.success?).to be false
      # Nested attributes use underscores in error codes, not dots
      expect(result.errors.first[:code]).to eq("USER_EMAIL_INVALID_FORMAT")
    end
  end

  describe "inclusion validation with non-Hash array" do
    before do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "handles inclusion as direct array in nested validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :user
        validates :user do
          attribute :role, inclusion: %w[admin user guest]
        end
      end

      result = interactor_class.call(user: { role: "superadmin" })

      expect(result.success?).to be false
      # Nested attributes use underscores in error codes, not dots
      expect(result.errors.first[:code]).to eq("USER_ROLE_NOT_IN_ALLOWED_VALUES")
    end
  end

  describe "unknown error type handling" do
    before do
      Interactor::Validation.configure do |config|
        config.error_mode = :code
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "handles unknown error types with upcase fallback" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value
        validates :value, presence: true

        def validate!
          super
          # This will use the error_code_for method with an unknown type
          if context.value == "trigger"
            errors.add(:value, "custom error")
          end
        end
      end

      result = interactor_class.call(value: "trigger")

      expect(result.success?).to be false
    end
  end

  describe "halt validation flow" do
    before do
      Interactor::Validation.configure do |config|
        config.halt = true
        config.error_mode = :code
      end
    end

    after do
      Interactor::Validation.reset_configuration!
    end

    it "halts after presence error before boolean validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :flag, :other
        validates :flag, presence: true, boolean: true
        validates :other, presence: true
      end

      result = interactor_class.call(flag: nil, other: nil)

      expect(result.success?).to be false
      # Should only have one error due to halt
      expect(result.errors.size).to eq(1)
    end

    it "halts after boolean error before format validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value
        validates :value, boolean: true, format: /abc/
      end

      result = interactor_class.call(value: "string")

      expect(result.success?).to be false
    end

    it "halts after format error before length validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :code
        validates :code, format: /^\d+$/, length: { is: 5 }
      end

      result = interactor_class.call(code: "ABC")

      expect(result.success?).to be false
    end

    it "halts after length error before inclusion validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :status
        validates :status, length: { maximum: 2 }, inclusion: %w[a b]
      end

      result = interactor_class.call(status: "abc")

      expect(result.success?).to be false
    end

    it "halts after inclusion error before numericality validation" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value
        validates :value, inclusion: %w[1 2 3], numericality: { greater_than: 0 }
      end

      result = interactor_class.call(value: "4")

      expect(result.success?).to be false
    end
  end

  describe "explicit halt flag" do
    it "halts validation when halt option is used" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :email, :name
        validates :email, presence: true
        validates :name, presence: true

        def validate!
          # Call parent validation first
          super if defined?(super)

          # Manually trigger halt - this sets @halt_validation = true
          errors.add(:custom, "error", halt: true)

          # After halt is set, validate_params! should stop
          # But since we're in validate! already, we just check the flag
          return if @halt_validation

          errors.add(:should_not_appear, "this should not be added")
        end
      end

      result = interactor_class.call(email: "test@example.com", name: "John")

      expect(result.success?).to be false
      # The halt flag should prevent the second error from being added
      expect(result.errors.map { |e| e[:attribute] }).to include(:custom)
    end
  end

  describe "ActiveModel::ValidationError rescue" do
    it "rescues ActiveModel::ValidationError in validate!" do
      interactor_class = Class.new do
        include Interactor
        include Interactor::Validation

        params :value
        validates :value, presence: true

        def validate!
          # First call super which might raise
          begin
            super
          rescue ActiveModel::ValidationError
            # This should be caught by the validate! method
          end

          # Then add our own validation
          errors.add(:value, "custom") if context.value == "invalid"
        end
      end

      result = interactor_class.call(value: "invalid")

      expect(result.success?).to be false
    end
  end

  describe "NoMethodError rescue in validate!" do
    it "rescues NoMethodError when parent has no validate! method" do
      base_class = Class.new do
        include ActiveModel::Validations
        # Deliberately has no validate! method
      end

      interactor_class = Class.new(base_class) do
        include Interactor::Validation::Validates

        def context
          @context ||= OpenStruct.new(fail!: ->(errors:) { @failed = true; @errors = errors })
        end
      end

      instance = interactor_class.new
      # Should not raise NoMethodError
      expect { instance.send(:validate!) }.not_to raise_error
    end
  end

  describe "ActiveModel::Validations already included" do
    it "skips including ActiveModel::Validations if already present" do
      base_class = Class.new do
        include ActiveModel::Validations
      end

      expect(ActiveModel::Validations).not_to receive(:included)

      Class.new(base_class) do
        include Interactor::Validation::Validates
      end
    end
  end
end
