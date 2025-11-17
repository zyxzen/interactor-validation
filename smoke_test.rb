#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/interactor/validation"

# Test 1: Basic validation
class TestBasicValidation
  include Interactor
  include Interactor::Validation

  params :email, :username, :age

  validates :email, presence: true, format: { with: /@/ }
  validates :username, presence: true
  validates :age, numericality: { greater_than: 0 }

  def call
    context.result = "User created: #{email}, #{username}, #{age}"
  end
end

puts "Test 1: Basic Validation"
puts "=" * 50

# Should succeed
result = TestBasicValidation.call(email: "user@example.com", username: "john", age: 25)
puts "✓ Valid params: #{result.success? ? 'PASS' : 'FAIL'}"
puts "  Result: #{result.result}" if result.success?

# Should fail
result = TestBasicValidation.call(email: "", username: "", age: -5)
puts "✗ Invalid params: #{result.failure? ? 'PASS' : 'FAIL'}"
puts "  Errors: #{result.errors.size} errors" if result.failure?
result.errors.each { |e| puts "    - #{e[:attribute]}: #{e[:message]}" } if result.failure?

puts

# Test 2: Nested validation
class TestNestedValidation
  include Interactor
  include Interactor::Validation

  params :user

  validates :user, presence: true do
    attribute :name, presence: true
    attribute :email, format: { with: /@/ }
    attribute :age, numericality: { greater_than: 0 }
  end

  def call
    context.result = "User created: #{user[:name]}"
  end
end

puts "Test 2: Nested Validation"
puts "=" * 50

# Should succeed
result = TestNestedValidation.call(user: { name: "John", email: "john@example.com", age: 30 })
puts "✓ Valid nested params: #{result.success? ? 'PASS' : 'FAIL'}"
puts "  Result: #{result.result}" if result.success?

# Should fail
result = TestNestedValidation.call(user: { name: "", email: "invalid", age: -5 })
puts "✗ Invalid nested params: #{result.failure? ? 'PASS' : 'FAIL'}"
puts "  Errors: #{result.errors.size} errors" if result.failure?
result.errors.each { |e| puts "    - #{e[:attribute]}: #{e[:message]}" } if result.failure?

puts

# Test 3: Array validation
class TestArrayValidation
  include Interactor
  include Interactor::Validation

  params :items

  validates :items do
    attribute :name, presence: true
    attribute :price, numericality: { greater_than: 0 }
  end

  def call
    context.result = "Processed #{items.size} items"
  end
end

puts "Test 3: Array Validation"
puts "=" * 50

# Should succeed
result = TestArrayValidation.call(items: [
  { name: "Widget", price: 10 },
  { name: "Gadget", price: 20 }
])
puts "✓ Valid array: #{result.success? ? 'PASS' : 'FAIL'}"
puts "  Result: #{result.result}" if result.success?

# Should fail
result = TestArrayValidation.call(items: [
  { name: "Widget", price: 10 },
  { name: "", price: -5 }
])
puts "✗ Invalid array item: #{result.failure? ? 'PASS' : 'FAIL'}"
puts "  Errors: #{result.errors.size} errors" if result.failure?
result.errors.each { |e| puts "    - #{e[:attribute]}: #{e[:message]}" } if result.failure?

puts

# Test 4: Custom validation
class TestCustomValidation
  include Interactor
  include Interactor::Validation

  params :product_id, :quantity

  validates :product_id, presence: true
  validates :quantity, numericality: { greater_than: 0 }

  def validate!
    super

    # Custom business logic
    if product_id == 999
      errors.add(:product_id, :not_found, message: "Product not found")
    end
  end

  def call
    context.result = "Order created for product #{product_id}"
  end
end

puts "Test 4: Custom Validation"
puts "=" * 50

# Should succeed
result = TestCustomValidation.call(product_id: 123, quantity: 5)
puts "✓ Valid with custom validation: #{result.success? ? 'PASS' : 'FAIL'}"
puts "  Result: #{result.result}" if result.success?

# Should fail with custom error
result = TestCustomValidation.call(product_id: 999, quantity: 5)
puts "✗ Custom validation error: #{result.failure? ? 'PASS' : 'FAIL'}"
puts "  Errors: #{result.errors.size} errors" if result.failure?
result.errors.each { |e| puts "    - #{e[:attribute]}: #{e[:message]}" } if result.failure?

puts

# Test 5: Halt on first error (disabled by default)
class TestHaltDisabled
  include Interactor
  include Interactor::Validation

  params :email, :username, :age

  validates :email, presence: true, format: { with: /@/ }
  validates :username, presence: true
  validates :age, numericality: { greater_than: 0 }

  def call
    context.result = "User created"
  end
end

puts "Test 5: Halt Disabled (Default Behavior)"
puts "=" * 50

# Should collect all errors
result = TestHaltDisabled.call(email: "", username: "", age: -5)
puts "✗ All errors collected: #{result.failure? && result.errors.size == 3 ? 'PASS' : 'FAIL'}"
puts "  Expected 3 errors, got #{result.errors.size}" if result.failure?
result.errors.each { |e| puts "    - #{e[:attribute]}: #{e[:type]}" } if result.failure?

puts

# Test 6: Halt on first error (enabled)
class TestHaltEnabled
  include Interactor
  include Interactor::Validation

  params :email, :username, :age

  validates :email, presence: true, format: { with: /@/ }
  validates :username, presence: true
  validates :age, numericality: { greater_than: 0 }

  def call
    context.result = "User created"
  end
end

puts "Test 6: Halt Enabled (Stop on First Error)"
puts "=" * 50

# Enable halt
Interactor::Validation.configure do |config|
  config.halt = true
end

# Should stop at first error
result = TestHaltEnabled.call(email: "", username: "", age: -5)
puts "✗ Halted on first error: #{result.failure? && result.errors.size == 1 ? 'PASS' : 'FAIL'}"
puts "  Expected 1 error, got #{result.errors.size}" if result.failure?
result.errors.each { |e| puts "    - #{e[:attribute]}: #{e[:type]}" } if result.failure?

# Reset configuration
Interactor::Validation.configure do |config|
  config.halt = false
end

puts

# Test 7: Halt with valid first param, invalid second
class TestHaltPartialErrors
  include Interactor
  include Interactor::Validation

  params :email, :username, :age

  validates :email, presence: true, format: { with: /@/ }
  validates :username, presence: true, length: { minimum: 3 }
  validates :age, numericality: { greater_than: 0 }

  def call
    context.result = "User created"
  end
end

puts "Test 7: Halt with Valid First Param"
puts "=" * 50

# Enable halt
Interactor::Validation.configure do |config|
  config.halt = true
end

# Valid email, invalid username and age - should stop at username
result = TestHaltPartialErrors.call(email: "valid@example.com", username: "", age: -5)
puts "✗ Halted at username error: #{result.failure? && result.errors.size == 1 && result.errors.first[:attribute] == :username ? 'PASS' : 'FAIL'}"
puts "  Expected 1 error on username, got #{result.errors.size} errors" if result.failure?
result.errors.each { |e| puts "    - #{e[:attribute]}: #{e[:type]}" } if result.failure?

# Reset configuration
Interactor::Validation.configure do |config|
  config.halt = false
end

puts
puts "=" * 50
puts "Smoke tests complete!"
