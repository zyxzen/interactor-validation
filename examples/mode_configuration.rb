# frozen_string_literal: true

# Example: Configuring error message mode
#
# The gem supports two error message formats:
# 1. :default - Human-readable messages (e.g., "Email can't be blank")
# 2. :code - Machine-readable error codes (e.g., "EMAIL_IS_REQUIRED")

require_relative "../lib/interactor/validation"

class CreateUser
  include Interactor
  include Interactor::Validation

  params :email, :username, :age, :user, :items

  validates :email, presence: true
  validates :username, presence: true
  validates :age, numeric: { greater_than: 0 }

  validates :user do
    attribute :name, presence: true
    attribute :email, format: /@/
  end

  validates :items do
    attribute :title, presence: true
  end
end

# Configure default mode (human-readable messages)
Interactor::Validation.configure do |config|
  config.mode = :default
end

puts "Default Mode Examples:"
puts "=" * 60

result = CreateUser.call(email: "", username: "", age: -1)
puts "\nSimple field errors:"
result.errors.each { |err| puts "  #{err.inspect}" }
# Output:
#   {attribute: :email, type: :blank, message: "Email can't be blank"}
#   {attribute: :username, type: :blank, message: "Username can't be blank"}
#   {attribute: :age, type: :greater_than, message: "Age must be greater than 0"}

result = CreateUser.call(email: "test@example.com", username: "user", age: 25, user: { name: "", email: "invalid" })
puts "\nNested hash field errors:"
result.errors.each { |err| puts "  #{err.inspect}" }
# Output:
#   {attribute: :"user.name", type: :blank, message: "User name can't be blank"}
#   {attribute: :"user.email", type: :invalid, message: "User email is invalid"}

result = CreateUser.call(email: "test@example.com", username: "user", age: 25, items: [{ title: "First" }, { title: "" }])
puts "\nNested array field errors:"
result.errors.each { |err| puts "  #{err.inspect}" }
# Output:
#   {attribute: :"items[1].title", type: :blank, message: "Items[1] title can't be blank"}

# Configure code mode (machine-readable error codes)
Interactor::Validation.configure do |config|
  config.mode = :code
end

puts "\n\nCode Mode Examples:"
puts "=" * 60

result = CreateUser.call(email: "", username: "", age: -1)
puts "\nSimple field errors:"
result.errors.each { |err| puts "  #{err.inspect}" }
# Output:
#   {code: "EMAIL_IS_REQUIRED"}
#   {code: "USERNAME_IS_REQUIRED"}
#   {code: "AGE_GREATER_THAN"}

result = CreateUser.call(email: "test@example.com", username: "user", age: 25, user: { name: "", email: "invalid" })
puts "\nNested hash field errors:"
result.errors.each { |err| puts "  #{err.inspect}" }
# Output:
#   {code: "USER_NAME_IS_REQUIRED"}
#   {code: "USER_EMAIL_INVALID"}

result = CreateUser.call(email: "test@example.com", username: "user", age: 25, items: [{ title: "First" }, { title: "" }])
puts "\nNested array field errors:"
result.errors.each { |err| puts "  #{err.inspect}" }
# Output:
#   {code: "ITEMS[1]_TITLE_IS_REQUIRED"}

puts "\n\nError Code Format Rules:"
puts "=" * 60
puts "- Simple fields: EMAIL_IS_REQUIRED, USERNAME_INVALID"
puts "- Hash fields: USER_EMAIL_IS_REQUIRED, PROFILE_NAME_INVALID"
puts "- Array fields: ITEMS[0]_NAME_IS_REQUIRED, FILTERS[2]_VALUE_INVALID"
puts "- Blank errors use 'IS_REQUIRED' suffix"
puts "- Other errors use uppercase type: INVALID, GREATER_THAN, etc."
