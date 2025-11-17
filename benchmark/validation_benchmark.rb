# frozen_string_literal: true

require "bundler/setup"
require "benchmark/ips"
require "interactor"
require "interactor/validation"

# Benchmark different validation scenarios
puts "Interactor::Validation Performance Benchmarks"
puts "=" * 60

# Setup test interactors
class SimplePresenceInteractor
  include Interactor
  include Interactor::Validation

  params :username, :email

  validates :username, presence: true
  validates :email, presence: true

  def call; end
end

class ComplexValidationInteractor
  include Interactor
  include Interactor::Validation

  params :username, :email, :age, :bio

  validates :username, presence: true, length: { minimum: 3, maximum: 20 }
  validates :email, presence: true, format: { with: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i }
  validates :age, numericality: { greater_than: 0, less_than: 150 }
  validates :bio, length: { maximum: 500 }

  def call; end
end

class NestedValidationInteractor
  include Interactor
  include Interactor::Validation

  params :user_data

  validates :user_data do |v|
    v.attribute :name, presence: true, length: { minimum: 2 }
    v.attribute :email, presence: true, format: { with: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i }
    v.attribute :age, numericality: { greater_than: 0 }
  end

  def call; end
end

class ArrayValidationInteractor
  include Interactor
  include Interactor::Validation

  params :items

  validates :items do |v|
    v.attribute :name, presence: true
    v.attribute :price, numericality: { greater_than: 0 }
  end

  def call; end
end

# Valid test data
valid_simple_data = { username: "john_doe", email: "john@example.com" }
valid_complex_data = {
  username: "john_doe",
  email: "john@example.com",
  age: 25,
  bio: "Software developer"
}
valid_nested_data = {
  user_data: {
    name: "John Doe",
    email: "john@example.com",
    age: 25
  }
}
valid_array_data = {
  items: [
    { name: "Item 1", price: 10.99 },
    { name: "Item 2", price: 20.50 },
    { name: "Item 3", price: 15.75 }
  ]
}

# Invalid test data
invalid_simple_data = { username: "", email: "" }

# Benchmark: Simple presence validation
puts "\n1. Simple Presence Validation (2 fields)"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("valid data") do
    SimplePresenceInteractor.call(valid_simple_data)
  end

  x.report("invalid data") do
    result = SimplePresenceInteractor.call(invalid_simple_data)
    result.failure?
  end

  x.compare!
end

# Benchmark: Complex multi-rule validation
puts "\n2. Complex Validation (4 fields, multiple rules)"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("valid data") do
    ComplexValidationInteractor.call(valid_complex_data)
  end

  x.compare!
end

# Benchmark: Nested validation
puts "\n3. Nested Hash Validation"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("valid nested data") do
    NestedValidationInteractor.call(valid_nested_data)
  end

  x.compare!
end

# Benchmark: Array validation
puts "\n4. Array Validation (3 items)"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("valid array") do
    ArrayValidationInteractor.call(valid_array_data)
  end

  x.compare!
end

# Benchmark: Regex caching impact
puts "\n5. Regex Pattern Caching (100 iterations)"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("with caching") do
    Interactor::Validation.configure { |c| c.cache_regex_patterns = true }
    100.times { ComplexValidationInteractor.call(valid_complex_data) }
  end

  x.report("without caching") do
    Interactor::Validation.configure { |c| c.cache_regex_patterns = false }
    100.times { ComplexValidationInteractor.call(valid_complex_data) }
  end

  x.compare!
end

# Benchmark: Halt on first error
puts "\n6. Halt on First Error (invalid data, 4 fields)"
invalid_all_data = { username: "", email: "invalid", age: -1, bio: "a" * 600 }

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("halt enabled") do
    Interactor::Validation.configure { |c| c.halt_on_first_error = true }
    ComplexValidationInteractor.call(invalid_all_data)
  end

  x.report("halt disabled") do
    Interactor::Validation.configure { |c| c.halt_on_first_error = false }
    ComplexValidationInteractor.call(invalid_all_data)
  end

  x.compare!
end

# Benchmark: Error mode comparison
puts "\n7. Error Formatting Mode"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("code mode") do
    Interactor::Validation.configure { |c| c.error_mode = :code }
    SimplePresenceInteractor.call(invalid_simple_data)
  end

  x.report("default mode") do
    Interactor::Validation.configure { |c| c.error_mode = :default }
    SimplePresenceInteractor.call(invalid_simple_data)
  end

  x.compare!
end

# Benchmark: Large array validation
puts "\n8. Large Array Validation (100 items)"
large_array_data = {
  items: Array.new(100) { |i| { name: "Item #{i}", price: rand(1.0..100.0).round(2) } }
}

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("100 items") do
    ArrayValidationInteractor.call(large_array_data)
  end

  x.compare!
end

puts "\n#{"=" * 60}"
puts "Benchmarks complete!"
puts "\nTo run these benchmarks:"
puts "  bundle exec ruby benchmark/validation_benchmark.rb"
puts "\nTo add benchmark-ips to your Gemfile:"
puts "  gem 'benchmark-ips', '~> 2.0', group: :development"
