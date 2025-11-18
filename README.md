# Interactor::Validation

Structured, lightweight parameter validation designed specifically for [Interactor](https://github.com/collectiveidea/interactor) service objects.

## Features

- **Built for Interactor** - Seamless integration with service objects
- **Comprehensive validators** - Presence, format, length, inclusion, numericality, boolean
- **Nested validation** - Validate complex hashes and arrays
- **Custom validations** - `validate!` for other business logic
- **Flexible error formats** - Human-readable messages or machine-readable codes
- **Zero dependencies** - Just Interactor and Ruby stdlib
- **Configurable** - Control validation behavior and error handling

## Table of Contents

- [Installation](#installation)
- [Quick Example](#quick-example)
- [Validations](#validations)
  - [Presence](#presence)
  - [Format](#format)
  - [Length](#length)
  - [Inclusion](#inclusion)
  - [Numericality](#numericality)
  - [Boolean](#boolean)
  - [Nested Validation](#nested-validation)
- [Custom Validations](#custom-validations)
- [Configuration](#configuration)
- [Error Format](#error-format)
- [Parameter Delegation](#parameter-delegation)
- [Requirements](#requirements)
- [Design Philosophy](#design-philosophy)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Installation

Add to your Gemfile:

```ruby
gem "interactor-validation"
```

Then run:

```bash
bundle install
```

## Usage

### Quick Example

Define validations directly in your interactor:

```ruby
class CreateUser
  include Interactor
  include Interactor::Validation

  # Declare expected parameters
  params :email, :username, :age

  # Define validation rules
  validates :email, presence: true, format: { with: /@/ }
  validates :username, presence: true, length: { maximum: 100 }
  validates :age, numericality: { greater_than: 0 }

  def call
    # Validations run automatically before this
    User.create!(email: email, username: username, age: age)
  end
end
```

When validation fails, the interactor automatically halts with errors:

```ruby
result = CreateUser.call(email: "", username: "", age: -5)
result.failure? # => true
result.errors   # => Array of error hashes
```

**Default mode** (human-readable messages):
```ruby
result.errors
# => [
#      { attribute: :email, type: :blank, message: "Email can't be blank" },
#      { attribute: :username, type: :blank, message: "Username can't be blank" },
#      { attribute: :age, type: :greater_than, message: "Age must be greater than 0" }
#    ]
```

**Code mode** (machine-readable codes):
```ruby
# Set mode to :code in configuration
Interactor::Validation.configure { |config| config.mode = :code }

result.errors
# => [
#      { code: 'EMAIL_IS_REQUIRED' },
#      { code: 'USERNAME_IS_REQUIRED' },
#      { code: 'AGE_MUST_BE_GREATER_THAN_0' }
#    ]
```

## Validations

All validators support custom error messages via the `message` option.

### Presence

Validates that a value is not `nil`, empty string, or blank.

```ruby
validates :name, presence: true
validates :email, presence: { message: "Email is required" }
```

### Format

Validates that a value matches a regular expression pattern.

```ruby
validates :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
validates :username, format: { with: /\A[a-z0-9_]+\z/, message: "Invalid username" }
```

### Length

Validates the length of a string.

**Options:** `minimum`, `maximum`, `is`

```ruby
validates :password, length: { minimum: 8, maximum: 128 }
validates :code, length: { is: 6 }
validates :bio, length: { maximum: 500 }
```

### Inclusion

Validates that a value is included in a set of allowed values.

```ruby
validates :status, inclusion: { in: %w[active pending inactive] }
validates :role, inclusion: { in: ["admin", "user", "guest"], message: "Invalid role" }
```

### Numericality

Validates numeric values and comparisons.

**Options:** `greater_than`, `greater_than_or_equal_to`, `less_than`, `less_than_or_equal_to`, `equal_to`

```ruby
validates :age, numericality: { greater_than: 0 }
validates :price, numericality: { greater_than_or_equal_to: 0 }
validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
validates :rating, numericality: { equal_to: 5 }
validates :count, numericality: true  # Just verify it's numeric

# Shorthand: 'numeric' alias
validates :age, numeric: { greater_than: 0 }
```

### Boolean

Validates that a value is exactly `true` or `false` (not truthy/falsy).

```ruby
validates :is_active, boolean: true
validates :terms_accepted, boolean: true
```

### Nested Validation

Validate complex nested structures like hashes and arrays using block syntax.

#### Hash Validation

Use a block to define validations for hash attributes:

```ruby
class CreateUser
  include Interactor
  include Interactor::Validation

  params :user

  validates :user, presence: true do
    attribute :name, presence: true
    attribute :email, format: { with: /@/ }
    attribute :age, numericality: { greater_than: 0 }
  end

  def call
    User.create!(user)
  end
end

result = CreateUser.call(user: { name: "", email: "bad" })
result.errors
# => [
#      { attribute: :"user.name", type: :blank, message: "User name can't be blank" },
#      { attribute: :"user.email", type: :invalid, message: "User email is invalid" }
#    ]
```

#### Array Validation

Validate each element in an array by passing a block without additional options:

```ruby
class BulkCreateItems
  include Interactor
  include Interactor::Validation

  params :items

  validates :items do
    attribute :name, presence: true
    attribute :price, numericality: { greater_than: 0 }
  end

  def call
    items.each { |item| Item.create!(item) }
  end
end

result = BulkCreateItems.call(items: [
  { name: "Widget", price: 10 },
  { name: "", price: -5 }
])
result.errors
# => [
#      { attribute: :"items[1].name", type: :blank, message: "Items[1] name can't be blank" },
#      { attribute: :"items[1].price", type: :greater_than, message: "Items[1] price must be greater than 0" }
#    ]
```

## Custom Validations

Override `validate!` for custom business logic that requires external dependencies (database queries, API calls, etc.):

```ruby
class CreateOrder
  include Interactor
  include Interactor::Validation

  params :product_id, :quantity, :user_id

  validates :product_id, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :user_id, presence: true

  def validate!
    # Parameter validations have already run at this point
    # No need to call super - there is no parent validate! method

    product = Product.find_by(id: product_id)
    if product.nil?
      errors.add(:product_id, :not_found, message: "Product not found")
    elsif product.stock < quantity
      errors.add(:quantity, :insufficient, message: "Insufficient stock")
    end
  end

  def call
    Order.create!(product_id: product_id, quantity: quantity, user_id: user_id)
  end
end
```

**Important:** Parameter validations (defined via `validates`) run automatically before `validate!`. You should never call `super` in your `validate!` method as there is no parent implementation.

## Configuration

Configuration can be set at three levels (in order of precedence):

### 1. Per-Interactor Configuration

Configure individual interactors using either a `configure` block or dedicated methods:

```ruby
class CreateUser
  include Interactor
  include Interactor::Validation

  # Option 1: Using configure block
  configure do |config|
    config.halt = true
    config.mode = :code
  end

  # Option 2: Using dedicated methods
  validation_halt true
  validation_mode :code
  validation_skip_validate false

  # ... validations and call method
end
```

Configuration is inherited from parent classes and can be overridden in child classes.

### 2. Global Configuration

Configure global defaults in an initializer or before your interactors are loaded:

```ruby
Interactor::Validation.configure do |config|
  config.skip_validate = true  # Skip custom validate! if params fail (default: true)
  config.mode = :default       # Error format: :default or :code (default: :default)
  config.halt = false          # Stop on first error (default: false)
end
```

### Configuration Options

#### skip_validate

**Default:** `true`

Skip the custom `validate!` method when parameter validations fail. This prevents executing expensive custom validation logic (like database queries) when basic parameter checks have already failed.

```ruby
Interactor::Validation.configure do |config|
  config.skip_validate = false  # Always run custom validate! even if params fail
end
```

#### mode

**Default:** `:default`

Controls error message format. Choose between human-readable messages (`:default`) or machine-readable codes (`:code`).

**Default mode** - Human-readable messages with full context:
```ruby
Interactor::Validation.configure do |config|
  config.mode = :default
end

result = CreateUser.call(email: "", age: -5)
result.errors
# => [
#      { attribute: :email, type: :blank, message: "Email can't be blank" },
#      { attribute: :age, type: :greater_than, message: "Age must be greater than 0" }
#    ]
```

**Code mode** - Minimal error codes for API responses:
```ruby
Interactor::Validation.configure do |config|
  config.mode = :code
end

result = CreateUser.call(email: "", age: -5)
result.errors
# => [
#      { code: "EMAIL_IS_REQUIRED" },
#      { code: "AGE_GREATER_THAN" }
#    ]
```

#### halt

**Default:** `false`

Stop validation on the first error instead of collecting all validation failures.

```ruby
Interactor::Validation.configure do |config|
  config.halt = true
end

result = CreateUser.call(email: "", username: "", age: -5)
result.errors.size # => 1 (only the first error is captured)
```

## Error Format

Validations run automatically before the `call` method executes. If any validation fails, the interactor halts with `context.fail!` and populates `context.errors`.

Errors are returned as an array of hashes. The format depends on the `mode` configuration:

**Default mode** (verbose with full context):
```ruby
{
  attribute: :email,                    # The field that failed
  type: :blank,                         # The validation type
  message: "Email can't be blank"       # Human-readable message
}
```

**Code mode** (minimal for API responses):
```ruby
{
  code: "EMAIL_IS_REQUIRED"  # Machine-readable error code (SCREAMING_SNAKE_CASE)
}
```

Access errors via `result.errors` after calling an interactor:
```ruby
result = CreateUser.call(email: "")
result.failure?
# => true

result.errors
# => [
#      { attribute: :email, type: :blank, message: "Email can't be blank" }
#    ]
```

## Parameter Delegation

The `params` macro provides convenient access to context values, allowing you to reference parameters directly without the `context.` prefix.

```ruby
class UpdateUser
  include Interactor
  include Interactor::Validation

  params :user_id, :email

  validates :email, format: { with: /@/ }

  def call
    # Access params directly instead of context.user_id, context.email
    user = User.find(user_id)
    user.update!(email: email)
  end
end
```

This is purely syntactic sugar - under the hood, `user_id` and `email` still reference `context.user_id` and `context.email`.

## Requirements

- Ruby >= 3.2.0
- Interactor ~> 3.0

## Design Philosophy

This gem follows a minimalist philosophy:

- **Sensible defaults** - Works out of the box; configure only when needed
- **Core validations only** - Essential validators without bloat
- **Zero dependencies** - Only requires Interactor and Ruby stdlib
- **Simple & readable** - Straightforward code over clever optimizations
- **Interactor-first** - Built specifically for service object patterns

### Why Not ActiveModel::Validations?

While ActiveModel::Validations is powerful, it's designed for ActiveRecord models and carries assumptions about persistence. Interactor::Validation is:

- Lighter weight
- Designed specifically for transient service objects
- Simpler API tailored to interactor patterns
- Configurable error formats for API responses

## Development

### Setup

```bash
bundle install
```

### Running Tests

```bash
bundle exec rspec                                      # Run all tests
bundle exec rspec spec/interactor/validation_spec.rb  # Run specific test file
bundle exec rspec spec/interactor/validation_spec.rb:42  # Run specific test at line 42
```

### Linting

```bash
bundle exec rubocop     # Check code style
bundle exec rubocop -a  # Auto-fix safe issues
bundle exec rubocop -A  # Auto-fix all issues (use with caution)
```

### Combined (Default Rake Task)

```bash
bundle exec rake  # Runs both rspec and rubocop
```

### Interactive Console

```bash
bundle exec irb -r ./lib/interactor/validation  # Load gem in IRB
```

### Gem Management

```bash
bundle exec rake build     # Build gem file
bundle exec rake install   # Install gem locally
bundle exec rake release   # Release gem (requires permissions)
```

## Contributing

Contributions welcome! Please open an issue or pull request at:
https://github.com/zyxzen/interactor-validation

## License

MIT License - see [LICENSE.txt](LICENSE.txt)
