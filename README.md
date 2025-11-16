# Interactor::Validation

Add declarative parameter validation to your [Interactor](https://github.com/collectiveidea/interactor) service objects with Rails-style syntax.

## Installation

Add the gem to your Gemfile:

```ruby
gem "interactor-validation"
```

Install the gem:

```bash
bundle install
```

## Usage

### Quick Example

```ruby
class CreateUser
  include Interactor
  include Interactor::Validation

  # Declare parameters
  params :email, :username, :age, :terms_accepted

  # Add validations
  validates :email, presence: true, format: { with: /@/ }
  validates :username, presence: true
  validates :age, numericality: { greater_than: 0 }
  validates :terms_accepted, boolean: true

  def call
    # Validations run automatically before this
    User.create!(email: email, username: username, age: age)
  end
end

# Use it
result = CreateUser.call(
  email: "user@example.com",
  username: "john",
  age: 25,
  terms_accepted: true
)
result.success? # => true

# Invalid data fails automatically
result = CreateUser.call(email: "", username: "", age: -5, terms_accepted: "yes")
result.failure? # => true
result.errors   # => [
                #      { attribute: :email, type: :blank, message: "Email can't be blank" },
                #      { attribute: :username, type: :blank, message: "Username can't be blank" },
                #      { attribute: :age, type: :greater_than, message: "Age must be greater than 0" },
                #      { attribute: :terms_accepted, type: :invalid, message: "Terms accepted must be true or false" }
                #    ]
```

### Examples by Validation Type

#### Presence

```ruby
validates :name, presence: true
# Error: { attribute: :name, type: :blank, message: "Name can't be blank" }
```

#### Format (Regex)

```ruby
validates :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
# Error: { attribute: :email, type: :invalid, message: "Email is invalid" }
```

#### Numericality

```ruby
validates :price, numericality: { greater_than_or_equal_to: 0 }
validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
validates :count, numericality: true  # Just check if numeric

# Available constraints:
# - greater_than, greater_than_or_equal_to
# - less_than, less_than_or_equal_to
# - equal_to
```

#### Boolean

```ruby
validates :is_active, boolean: true
# Ensures value is true or false (not truthy/falsy)
```

---

## Available Validations

All standard validations support custom error messages:

```ruby
validates :field, presence: { message: "Custom message" }
validates :field, format: { with: /pattern/, message: "Invalid format" }
```

### Presence

Validates that a value is not nil or empty.

```ruby
validates :name, presence: true
validates :email, presence: { message: "Email is required" }
```

**Errors:**
- Default mode: `{ attribute: :name, type: :blank, message: "Name can't be blank" }`
- Code mode: `{ code: "NAME_IS_REQUIRED" }`

### Format

Validates that a value matches a regular expression pattern.

```ruby
validates :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
validates :username, format: { with: /\A[a-z0-9_]+\z/, message: "Only lowercase letters, numbers, and underscores" }
```

**Errors:**
- Default mode: `{ attribute: :email, type: :invalid, message: "Email is invalid" }`
- Code mode: `{ code: "EMAIL_INVALID_FORMAT" }`

### Length

Validates the length of a string or array.

```ruby
validates :password, length: { minimum: 8, maximum: 128 }
validates :code, length: { is: 6 }
validates :bio, length: { maximum: 500 }
```

**Options:** `minimum`, `maximum`, `is`

**Errors:**
- `too_short`: Value is below minimum
- `too_long`: Value exceeds maximum
- `wrong_length`: Value doesn't match exact length

### Inclusion

Validates that a value is in a specific list.

```ruby
validates :status, inclusion: { in: %w[active pending inactive] }
validates :role, inclusion: { in: ["admin", "user", "guest"] }
```

**Errors:**
- Default mode: `{ attribute: :status, type: :inclusion, message: "Status is not included in the list" }`
- Code mode: `{ code: "STATUS_NOT_IN_LIST" }`

### Numericality

Validates that a value is numeric and optionally meets constraints.

```ruby
validates :age, numericality: { greater_than: 0 }
validates :price, numericality: { greater_than_or_equal_to: 0 }
validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
validates :rating, numericality: { equal_to: 5 }
validates :count, numericality: true  # Just check if numeric
```

**Options:**
- `greater_than`
- `greater_than_or_equal_to`
- `less_than`
- `less_than_or_equal_to`
- `equal_to`

**Errors:**
- Default mode: `{ attribute: :age, type: :greater_than, message: "Age must be greater than 0" }`
- Code mode: `{ code: "AGE_BELOW_MIN_VALUE_0" }`

### Boolean

Validates that a value is exactly `true` or `false` (not truthy/falsy).

```ruby
validates :is_active, boolean: true
validates :terms_accepted, boolean: true
```

**Errors:**
- Default mode: `{ attribute: :is_active, type: :invalid, message: "Is active must be true or false" }`
- Code mode: `{ code: "IS_ACTIVE_INVALID_BOOLEAN" }`

### Nested Validation

Validate nested hashes and arrays.

**Hash Validation:**

```ruby
params :user
validates :user do
  attribute :name, presence: true
  attribute :email, format: { with: /@/ }
  attribute :age, numericality: { greater_than: 0 }
end

# Usage
result = CreateUser.call(user: { name: "", email: "bad", age: -1 })
result.errors # => [
              #      { attribute: "user.name", type: :blank, message: "User.name can't be blank" },
              #      { attribute: "user.email", type: :invalid, message: "User.email is invalid" },
              #      { attribute: "user.age", type: :greater_than, message: "User.age must be greater than 0" }
              #    ]
```

**Array Validation:**

```ruby
params :items
validates :items do
  attribute :name, presence: true
  attribute :price, numericality: { greater_than: 0 }
end

# Usage
result = ProcessItems.call(items: [
  { name: "Widget", price: 10 },
  { name: "", price: -5 }
])
result.errors # => [
              #      { attribute: "items[1].name", type: :blank, message: "Items[1].name can't be blank" },
              #      { attribute: "items[1].price", type: :greater_than, message: "Items[1].price must be greater than 0" }
              #    ]
```

---

# Detailed Documentation

## Error Formats

Choose between two error format modes:

### Default Mode (ActiveModel-style)

Human-readable errors with full context - ideal for forms and user-facing applications:

```ruby
# This is the default, no configuration needed
result.errors # => [
              #      { attribute: :email, type: :blank, message: "Email can't be blank" },
              #      { attribute: :username, type: :too_short, message: "Username is too short" }
              #    ]
```

### Code Mode

Structured error codes - ideal for APIs and internationalization:

```ruby
configure_validation do |config|
  config.error_mode = :code
end

result.errors # => [
              #      { code: "EMAIL_IS_REQUIRED" },
              #      { code: "USERNAME_BELOW_MIN_LENGTH_3" }
              #    ]
```

### Custom Messages

Provide custom error messages for any validation:

```ruby
# Works with both modes
validates :username, presence: { message: "Username is required" }
validates :email, format: { with: /@/, message: "Invalid email format" }

# In :code mode, custom messages become part of the code
configure_validation { |c| c.error_mode = :code }
validates :age, numericality: { greater_than: 0, message: "INVALID_AGE" }
# => { code: "AGE_INVALID_AGE" }
```

## Configuration

### Global Configuration

Configure behavior for all interactors:

```ruby
# config/initializers/interactor_validation.rb
Interactor::Validation.configure do |config|
  # Error format mode - Available options:
  #   :default - ActiveModel-style messages (default)
  #              { attribute: :email, type: :blank, message: "Email can't be blank" }
  #   :code    - Structured error codes for APIs
  #              { code: "EMAIL_IS_REQUIRED" }
  config.error_mode = :default

  # Stop at first error for better performance
  config.halt = false  # Set to true to stop on first validation error
  # config.halt_on_first_error = false  # (deprecated, use halt)

  # Security settings
  config.regex_timeout = 0.1        # Regex timeout in seconds (ReDoS protection)
  config.max_array_size = 1000      # Max array size for nested validation

  # Performance settings
  config.cache_regex_patterns = true

  # Monitoring
  config.enable_instrumentation = false
end
```

### Per-Interactor Configuration

Override settings for specific interactors:

```ruby
class CreateUser
  include Interactor
  include Interactor::Validation

  configure_validation do |config|
    config.error_mode = :code
    config.halt = true
  end

  validates :username, presence: true
  validates :email, presence: true
end
```

## Advanced Features

### Parameter Declaration

Declare parameters for automatic delegation to context:

```ruby
params :user_id, :action

def call
  # Access directly instead of context.user_id
  user = User.find(user_id)
  user.perform(action)
end
```

### Halt on First Error

Stop validation early for better performance and user experience:

#### Global Configuration

```ruby
configure_validation do |config|
  config.halt = true  # Stop after first error (recommended)
  # config.halt_on_first_error = true  # (deprecated, use halt)
end

validates :field1, presence: true
validates :field2, presence: true  # Won't run if field1 fails
validates :field3, presence: true  # Won't run if earlier fields fail
```

#### Per-Error Halt

Use `halt: true` with `errors.add` for fine-grained control:

```ruby
class ProcessOrder
  include Interactor
  include Interactor::Validation

  params :order_id, :payment_method

  validates :payment_method, inclusion: { in: %w[credit_card paypal] }

  validate :check_order_exists

  def check_order_exists
    order = Order.find_by(id: context.order_id)

    if order.nil?
      # Halt immediately - no point validating payment if order doesn't exist
      errors.add(:order_id, "not found", halt: true)
      return
    end

    # This won't run if halt was triggered
    if order.cancelled?
      errors.add(:order_id, "order is cancelled")
    end
  end

  def call
    # Process order
  end
end
```

**How it works:**
- **Global `halt` config**: Stops validating subsequent parameters after first error
- **Per-error `halt: true`**: Stops validation immediately when that specific error is added
- **Within-parameter halt**: When halt is triggered, remaining validation rules for that parameter are skipped
- **Across-parameter halt**: Subsequent parameters won't be validated

**Use cases:**
- Stop validating dependent fields when a required field is missing
- Skip expensive validations when basic checks fail
- Improve API response times by failing fast
- Provide cleaner error messages (only the most relevant error)

### ActiveModel Integration

Use ActiveModel's custom validation callbacks:

```ruby
class CreateUser
  include Interactor
  include Interactor::Validation

  params :user_data

  validate :check_custom_logic
  validates :username, presence: true

  private

  def check_custom_logic
    errors.add(:base, "Custom validation failed") unless custom_condition?
  end
end
```

### Performance Monitoring

Track validation performance in production:

```ruby
config.enable_instrumentation = true

ActiveSupport::Notifications.subscribe('validate_params.interactor_validation') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Rails.logger.info "Validation: #{event.duration}ms (#{event.payload[:interactor]})"
end
```

## Security

Built-in protection against common vulnerabilities:

### ReDoS Protection

Automatic timeouts prevent Regular Expression Denial of Service attacks:

```ruby
config.regex_timeout = 0.1  # 100ms default
```

If a regex exceeds the timeout, validation fails safely instead of hanging.

### Memory Protection

Array size limits prevent memory exhaustion:

```ruby
config.max_array_size = 1000  # Default limit
```

### Thread Safety

All validation operations are thread-safe for use with Puma, Sidekiq, etc.

### Best Practices

- Use simple regex patterns (avoid nested quantifiers)
- Sanitize error messages before displaying in HTML
- Set appropriate `max_array_size` limits for your use case
- Enable instrumentation to monitor performance
- Review [SECURITY.md](SECURITY.md) for detailed information

## Custom Validation Hook

Use the `validate!` hook to add custom validation logic that goes beyond standard validations.

### Basic Usage

The `validate!` method runs automatically after parameter validations:

```ruby
class CreateOrder
  include Interactor
  include Interactor::Validation

  params :product_id, :quantity, :user_id

  validates :product_id, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :user_id, presence: true

  def validate!
    # Custom business logic validation
    product = Product.find_by(id: product_id)

    if product.nil?
      errors.add(:product_id, "PRODUCT_NOT_FOUND")
    elsif product.stock < quantity
      errors.add(:quantity, "INSUFFICIENT_STOCK")
    end

    user = User.find_by(id: user_id)
    if user && !user.active?
      errors.add(:user_id, "USER_NOT_ACTIVE")
    end
  end

  def call
    # This only runs if all validations pass
    Order.create!(product_id: product_id, quantity: quantity, user_id: user_id)
  end
end

# Usage
result = CreateOrder.call(product_id: 999, quantity: 100, user_id: 1)
result.failure? # => true
result.errors   # => [{ code: "PRODUCT_ID_PRODUCT_NOT_FOUND" }]
```

### Execution Order

Validations run in this order:

1. **Parameter validations** (`validates :field, ...`)
2. **Custom validate! hook** (your custom logic)
3. **call method** (only if no errors)

```ruby
class ProcessPayment
  include Interactor
  include Interactor::Validation

  params :amount, :card_token

  validates :amount, numericality: { greater_than: 0 }
  validates :card_token, presence: true

  def validate!
    # This runs AFTER parameter validations pass
    # Check payment gateway availability
    errors.add(:base, "PAYMENT_GATEWAY_UNAVAILABLE") unless PaymentGateway.available?
  end

  def call
    # This only runs if both parameter validations AND validate! pass
    PaymentGateway.charge(amount: amount, token: card_token)
  end
end
```

### Combining with Error Modes

Works with both `:default` and `:code` error modes:

```ruby
# With :default mode (ActiveModel-style messages)
class UpdateProfile
  include Interactor
  include Interactor::Validation

  params :username, :bio

  validates :username, presence: true

  def validate!
    if username && username.include?("admin")
      errors.add(:username, "cannot contain 'admin'")
    end
  end
end

result = UpdateProfile.call(username: "admin123")
result.errors # => [{ attribute: :username, type: :invalid, message: "Username cannot contain 'admin'" }]

# With :code mode (structured error codes)
class UpdateProfile
  include Interactor
  include Interactor::Validation

  configure_validation do |config|
    config.error_mode = :code
  end

  params :username, :bio

  validates :username, presence: true

  def validate!
    if username && username.include?("admin")
      errors.add(:username, "RESERVED_WORD")
    end
  end
end

result = UpdateProfile.call(username: "admin123")
result.errors # => [{ code: "USERNAME_RESERVED_WORD" }]
```

## Inheritance

Create base interactors with shared validation logic that child classes automatically inherit.

### Basic Inheritance

```ruby
# Base interactor with common functionality
class ApplicationInteractor
  include Interactor
  include Interactor::Validation

  # All child classes will inherit validation functionality
end

# Child interactor automatically gets validation
class CreateUser < ApplicationInteractor
  params :email, :username

  validates :email, presence: true, format: { with: /@/ }
  validates :username, presence: true

  def call
    User.create!(email: email, username: username)
  end
end

# Another child interactor
class UpdateUser < ApplicationInteractor
  params :user_id, :email

  validates :user_id, presence: true
  validates :email, format: { with: /@/ }

  def call
    User.find(user_id).update!(email: email)
  end
end

# Both work automatically
CreateUser.call(email: "user@example.com", username: "john") # => success
UpdateUser.call(user_id: 1, email: "invalid") # => failure with validation errors
```

### Shared Validation Configuration

Configure validation behavior in the base class:

```ruby
class ApiInteractor
  include Interactor
  include Interactor::Validation

  configure_validation do |config|
    config.error_mode = :code  # All child classes use code mode
    config.halt = true
  end
end

class CreatePost < ApiInteractor
  params :title, :body

  validates :title, presence: true
  validates :body, presence: true

  def call
    Post.create!(title: title, body: body)
  end
end

result = CreatePost.call(title: "", body: "")
result.errors # => [{ code: "TITLE_IS_REQUIRED" }]  # Halted on first error
```

### Shared Custom Validations

Define common validation logic in the base class:

```ruby
class AuthenticatedInteractor
  include Interactor
  include Interactor::Validation

  params :user_id

  validates :user_id, presence: true

  def validate!
    # This validation runs for ALL child classes
    user = User.find_by(id: user_id)

    if user.nil?
      errors.add(:user_id, "USER_NOT_FOUND")
    elsif !user.active?
      errors.add(:user_id, "USER_INACTIVE")
    end
  end
end

class UpdateSettings < AuthenticatedInteractor
  params :user_id, :theme

  validates :theme, inclusion: { in: %w[light dark] }

  def call
    # user_id is already validated by parent
    User.find(user_id).update!(theme: theme)
  end
end

class DeleteAccount < AuthenticatedInteractor
  params :user_id, :confirmation

  validates :confirmation, presence: true

  def validate!
    super  # Call parent's validate! first

    # Add additional validation
    if confirmation != "DELETE"
      errors.add(:confirmation, "INVALID_CONFIRMATION")
    end
  end

  def call
    User.find(user_id).destroy!
  end
end
```

### Multilevel Inheritance

Validation works across multiple inheritance levels:

```ruby
# Level 1: Base
class ApplicationInteractor
  include Interactor
  include Interactor::Validation
end

# Level 2: Feature-specific base
class AdminInteractor < ApplicationInteractor
  params :admin_id

  validates :admin_id, presence: true

  def validate!
    admin = Admin.find_by(id: admin_id)
    errors.add(:admin_id, "NOT_AN_ADMIN") if admin.nil?
  end
end

# Level 3: Specific action
class BanUser < AdminInteractor
  params :admin_id, :target_user_id, :reason

  validates :target_user_id, presence: true
  validates :reason, presence: true, length: { minimum: 10 }

  def validate!
    super  # Validates admin_id

    # Additional validation
    target = User.find_by(id: target_user_id)
    errors.add(:target_user_id, "USER_NOT_FOUND") if target.nil?
  end

  def call
    User.find(target_user_id).ban!(reason: reason, banned_by: admin_id)
  end
end

# All three levels of validation run automatically
result = BanUser.call(admin_id: 1, target_user_id: 999, reason: "Spam")
# Validates: admin_id presence, admin exists, target_user_id presence, target exists, reason presence/length
```

### Override Parent Configuration

Child classes can override parent configuration:

```ruby
class BaseInteractor
  include Interactor
  include Interactor::Validation

  configure_validation do |config|
    config.error_mode = :default
  end
end

class ApiCreateUser < BaseInteractor
  # Override to use code mode for API
  configure_validation do |config|
    config.error_mode = :code
  end

  params :email

  validates :email, presence: true

  def call
    User.create!(email: email)
  end
end

result = ApiCreateUser.call(email: "")
result.errors # => [{ code: "EMAIL_IS_REQUIRED" }]  # Uses :code mode, not :default
```

## Complete Usage Examples

### All Validation Types

```ruby
class CompleteExample
  include Interactor
  include Interactor::Validation

  params :name, :email, :password, :age, :status, :terms, :profile, :tags

  # Presence validation
  validates :name, presence: true
  # Error: { attribute: :name, type: :blank, message: "Name can't be blank" }

  # Format validation (regex)
  validates :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
  # Error: { attribute: :email, type: :invalid, message: "Email is invalid" }

  # Length validations
  validates :password, length: { minimum: 8, maximum: 128 }
  # Errors: { attribute: :password, type: :too_short, message: "Password is too short (minimum is 8 characters)" }
  #         { attribute: :password, type: :too_long, message: "Password is too long (maximum is 128 characters)" }

  validates :name, length: { is: 10 }
  # Error: { attribute: :name, type: :wrong_length, message: "Name is the wrong length (should be 10 characters)" }

  # Numericality validations
  validates :age,
    numericality: {
      greater_than: 0,
      less_than: 150,
      greater_than_or_equal_to: 18,
      less_than_or_equal_to: 100,
      equal_to: 25  # Exact value
    }
  # Errors: { attribute: :age, type: :greater_than, message: "Age must be greater than 0" }
  #         { attribute: :age, type: :less_than, message: "Age must be less than 150" }
  #         { attribute: :age, type: :greater_than_or_equal_to, message: "Age must be greater than or equal to 18" }
  #         { attribute: :age, type: :less_than_or_equal_to, message: "Age must be less than or equal to 100" }
  #         { attribute: :age, type: :equal_to, message: "Age must be equal to 25" }

  # Inclusion validation
  validates :status, inclusion: { in: %w[active pending inactive suspended] }
  # Error: { attribute: :status, type: :inclusion, message: "Status is not included in the list" }

  # Boolean validation
  validates :terms, boolean: true
  # Ensures value is exactly true or false (not truthy/falsy)

  # Nested hash validation
  validates :profile do
    attribute :username, presence: true, length: { minimum: 3 }
    attribute :bio, length: { maximum: 500 }
    attribute :age, numericality: { greater_than: 0 }
  end

  # Nested array validation
  validates :tags do
    attribute :name, presence: true
    attribute :priority, numericality: { greater_than_or_equal_to: 0 }
  end

  def call
    # Your logic here
  end
end
```

### Custom Error Messages

```ruby
class CustomMessages
  include Interactor
  include Interactor::Validation

  params :username, :email, :age

  # Custom message for presence
  validates :username, presence: { message: "Please provide a username" }

  # Custom message for format
  validates :email, format: { with: /@/, message: "Must be a valid email address" }

  # Custom message for numericality
  validates :age, numericality: { greater_than: 0, message: "Age must be positive" }

  def call
    # Your logic
  end
end

# With :default mode
result = CustomMessages.call(username: "", email: "invalid", age: -5)
result.errors # => [
              #      { attribute: :username, type: :blank, message: "Username please provide a username" },
              #      { attribute: :email, type: :invalid, message: "Email must be a valid email address" },
              #      { attribute: :age, type: :greater_than, message: "Age age must be positive" }
              #    ]

# With :code mode
class CustomMessagesCode
  include Interactor
  include Interactor::Validation

  configure_validation { |c| c.error_mode = :code }

  params :username, :age

  validates :username, presence: { message: "REQUIRED" }
  validates :age, numericality: { greater_than: 0, message: "INVALID" }
end

result = CustomMessagesCode.call(username: "", age: -5)
result.errors # => [
              #      { code: "USERNAME_REQUIRED" },
              #      { code: "AGE_INVALID" }
              #    ]
```

### Error Modes Comparison

```ruby
class UserRegistration
  include Interactor
  include Interactor::Validation

  params :email, :password, :age

  validates :email, presence: true, format: { with: /@/ }
  validates :password, length: { minimum: 8 }
  validates :age, numericality: { greater_than_or_equal_to: 18 }

  def call
    User.create!(email: email, password: password, age: age)
  end
end

# Default mode (ActiveModel-style) - human-readable, detailed
result = UserRegistration.call(email: "bad", password: "short", age: 15)
result.errors # => [
              #      { attribute: :email, type: :invalid, message: "Email is invalid" },
              #      { attribute: :password, type: :too_short, message: "Password is too short (minimum is 8 characters)" },
              #      { attribute: :age, type: :greater_than_or_equal_to, message: "Age must be greater than or equal to 18" }
              #    ]

# Code mode - structured, API-friendly, i18n-ready
class ApiUserRegistration
  include Interactor
  include Interactor::Validation

  configure_validation { |c| c.error_mode = :code }

  params :email, :password, :age

  validates :email, presence: true, format: { with: /@/ }
  validates :password, length: { minimum: 8 }
  validates :age, numericality: { greater_than_or_equal_to: 18 }

  def call
    User.create!(email: email, password: password, age: age)
  end
end

result = ApiUserRegistration.call(email: "bad", password: "short", age: 15)
result.errors # => [
              #      { code: "EMAIL_INVALID_FORMAT" },
              #      { code: "PASSWORD_BELOW_MIN_LENGTH_8" },
              #      { code: "AGE_BELOW_MIN_VALUE_18" }
              #    ]
```

### Configuration Examples

```ruby
# Global configuration (config/initializers/interactor_validation.rb)
Interactor::Validation.configure do |config|
  # Error format
  config.error_mode = :code  # or :default

  # Performance
  config.halt = true  # Stop at first validation error

  # Security
  config.regex_timeout = 0.1        # 100ms timeout for regex (ReDoS protection)
  config.max_array_size = 1000      # Max array size for nested validation

  # Optimization
  config.cache_regex_patterns = true # Cache compiled regex patterns

  # Monitoring
  config.enable_instrumentation = true
end

# Per-interactor configuration (overrides global)
class FastValidator
  include Interactor
  include Interactor::Validation

  configure_validation do |config|
    config.halt = true  # Override global setting
    config.error_mode = :code
  end

  params :field1, :field2, :field3

  validates :field1, presence: true
  validates :field2, presence: true  # Won't run if field1 fails
  validates :field3, presence: true  # Won't run if earlier fails

  def call
    # Your logic
  end
end
```

### Nested Validation Examples

```ruby
# Hash validation
class CreateUserWithProfile
  include Interactor
  include Interactor::Validation

  params :user

  validates :user do
    attribute :name, presence: true
    attribute :email, format: { with: /@/ }
    attribute :age, numericality: { greater_than: 0 }
    attribute :bio, length: { maximum: 500 }
  end

  def call
    User.create!(user)
  end
end

# Usage
result = CreateUserWithProfile.call(
  user: {
    name: "",
    email: "invalid",
    age: -5,
    bio: "a" * 600
  }
)
result.errors # => [
              #      { attribute: "user.name", type: :blank, message: "User.name can't be blank" },
              #      { attribute: "user.email", type: :invalid, message: "User.email is invalid" },
              #      { attribute: "user.age", type: :greater_than, message: "User.age must be greater than 0" },
              #      { attribute: "user.bio", type: :too_long, message: "User.bio is too long (maximum is 500 characters)" }
              #    ]

# Array validation
class BulkCreateItems
  include Interactor
  include Interactor::Validation

  params :items

  validates :items do
    attribute :name, presence: true
    attribute :price, numericality: { greater_than: 0 }
    attribute :quantity, numericality: { greater_than_or_equal_to: 1 }
  end

  def call
    items.each { |item| Item.create!(item) }
  end
end

# Usage
result = BulkCreateItems.call(
  items: [
    { name: "Widget", price: 10, quantity: 5 },
    { name: "", price: -5, quantity: 0 }
  ]
)
result.errors # => [
              #      { attribute: "items[1].name", type: :blank, message: "Items[1].name can't be blank" },
              #      { attribute: "items[1].price", type: :greater_than, message: "Items[1].price must be greater than 0" },
              #      { attribute: "items[1].quantity", type: :greater_than_or_equal_to, message: "Items[1].quantity must be greater than or equal to 1" }
              #    ]
```

### ActiveModel Integration

```ruby
class CustomValidations
  include Interactor
  include Interactor::Validation

  params :username, :password, :password_confirmation

  validates :username, presence: true
  validates :password, presence: true

  # Use ActiveModel's validate callback for complex logic
  validate :passwords_match
  validate :username_not_reserved

  private

  def passwords_match
    if password != password_confirmation
      errors.add(:password_confirmation, "doesn't match password")
    end
  end

  def username_not_reserved
    reserved = %w[admin root system]
    if reserved.include?(username&.downcase)
      errors.add(:username, "is reserved")
    end
  end
end

result = CustomValidations.call(
  username: "admin",
  password: "secret123",
  password_confirmation: "different"
)
result.errors # => [
              #      { attribute: :username, type: :invalid, message: "Username is reserved" },
              #      { attribute: :password_confirmation, type: :invalid, message: "Password confirmation doesn't match password" }
              #    ]
```

### Performance Monitoring

```ruby
# Enable instrumentation in configuration
Interactor::Validation.configure do |config|
  config.enable_instrumentation = true
end

# Subscribe to validation events
ActiveSupport::Notifications.subscribe('validate_params.interactor_validation') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  Rails.logger.info({
    event: 'validation',
    interactor: event.payload[:interactor],
    duration_ms: event.duration,
    validation_count: event.payload[:validation_count],
    error_count: event.payload[:error_count],
    halted: event.payload[:halted]
  }.to_json)
end

# Now all validations are instrumented
class SlowValidation
  include Interactor
  include Interactor::Validation

  params :field1, :field2

  validates :field1, presence: true
  validates :field2, format: { with: /complex.*regex/ }

  def call
    # Your logic
  end
end

# Logs: { "event": "validation", "interactor": "SlowValidation", "duration_ms": 2.5, ... }
```

### Real-World Example: API Endpoint

```ruby
# Base API interactor
class ApiInteractor
  include Interactor
  include Interactor::Validation

  configure_validation do |config|
    config.error_mode = :code
    config.halt = false  # Return all errors
  end
end

# User registration endpoint
class Api::V1::RegisterUser < ApiInteractor
  params :email, :password, :password_confirmation, :first_name, :last_name, :terms_accepted

  validates :email,
    presence: { message: "REQUIRED" },
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "INVALID_FORMAT" }

  validates :password,
    presence: { message: "REQUIRED" },
    length: { minimum: 12, message: "TOO_SHORT" }

  validates :first_name, presence: { message: "REQUIRED" }
  validates :last_name, presence: { message: "REQUIRED" }
  validates :terms_accepted, boolean: true

  def validate!
    # Custom validations
    if password != password_confirmation
      errors.add(:password_confirmation, "MISMATCH")
    end

    if User.exists?(email: email)
      errors.add(:email, "ALREADY_TAKEN")
    end

    unless terms_accepted == true
      errors.add(:terms_accepted, "MUST_ACCEPT")
    end
  end

  def call
    user = User.create!(
      email: email,
      password: password,
      first_name: first_name,
      last_name: last_name
    )

    context.user = user
    context.token = generate_token(user)
  end

  private

  def generate_token(user)
    JWT.encode({ user_id: user.id }, Rails.application.secret_key_base)
  end
end

# Controller
class Api::V1::UsersController < ApplicationController
  def create
    result = Api::V1::RegisterUser.call(user_params)

    if result.success?
      render json: {
        user: result.user,
        token: result.token
      }, status: :created
    else
      render json: {
        errors: result.errors
      }, status: :unprocessable_entity
    end
  end
end

# Example error response:
# {
#   "errors": [
#     { "code": "EMAIL_INVALID_FORMAT" },
#     { "code": "PASSWORD_TOO_SHORT" },
#     { "code": "TERMS_ACCEPTED_MUST_ACCEPT" }
#   ]
# }
```

### Real-World Example: Background Job

```ruby
# Background job with validation
class ProcessOrderJob
  include Interactor
  include Interactor::Validation

  configure_validation do |config|
    config.error_mode = :code
  end

  params :order_id, :payment_method, :shipping_address

  validates :order_id, presence: true
  validates :payment_method, inclusion: { in: %w[credit_card paypal stripe] }

  validates :shipping_address do
    attribute :street, presence: true
    attribute :city, presence: true
    attribute :postal_code, presence: true, format: { with: /\A\d{5}\z/ }
    attribute :country, inclusion: { in: %w[US CA UK] }
  end

  def validate!
    order = Order.find_by(id: order_id)

    if order.nil?
      errors.add(:order_id, "NOT_FOUND")
      return
    end

    if order.processed?
      errors.add(:order_id, "ALREADY_PROCESSED")
    end

    if order.total_amount <= 0
      errors.add(:base, "INVALID_ORDER_AMOUNT")
    end
  end

  def call
    order = Order.find(order_id)

    payment = process_payment(order, payment_method)
    shipment = create_shipment(order, shipping_address)

    order.update!(
      status: 'processed',
      payment_id: payment.id,
      shipment_id: shipment.id
    )

    context.order = order
  end
end

# Sidekiq job wrapper
class ProcessOrderWorker
  include Sidekiq::Worker

  def perform(order_id, payment_method, shipping_address)
    result = ProcessOrderJob.call(
      order_id: order_id,
      payment_method: payment_method,
      shipping_address: shipping_address
    )

    unless result.success?
      # Log errors and retry or alert
      Rails.logger.error("Order processing failed: #{result.errors}")
      raise StandardError, "Validation failed: #{result.errors}"
    end
  end
end
```

### Security Best Practices

```ruby
# ReDoS protection
class SecureValidation
  include Interactor
  include Interactor::Validation

  configure_validation do |config|
    config.regex_timeout = 0.05  # 50ms timeout
  end

  params :input

  # Potentially dangerous regex (nested quantifiers)
  validates :input, format: { with: /^(a+)+$/ }

  def call
    # If regex takes > 50ms, validation fails safely
  end
end

# Array size protection
class BulkOperation
  include Interactor
  include Interactor::Validation

  configure_validation do |config|
    config.max_array_size = 100  # Limit to 100 items
  end

  params :items

  validates :items do
    attribute :name, presence: true
  end

  def call
    # If items.length > 100, validation fails
    items.each { |item| process(item) }
  end
end

# Sanitize error messages before displaying
class UserInput
  include Interactor
  include Interactor::Validation

  params :content

  validates :content, presence: true

  def call
    # Always sanitize user input
    sanitized = ActionController::Base.helpers.sanitize(content)
    Content.create!(body: sanitized)
  end
end
```

---

## Requirements

- Ruby >= 3.2.0
- Interactor ~> 3.0
- ActiveModel >= 6.0
- ActiveSupport >= 6.0

## Development

```bash
bin/setup              # Install dependencies
bundle exec rspec      # Run tests (231 examples)
bundle exec rubocop    # Lint code
bin/console            # Interactive console
```

### Benchmarking

```bash
bundle exec ruby benchmark/validation_benchmark.rb
```

## License

MIT License - see [LICENSE.txt](LICENSE.txt)

## Contributing

Issues and pull requests are welcome at [https://github.com/zyxzen/interactor-validation](https://github.com/zyxzen/interactor-validation)
