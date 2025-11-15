# Interactor::Validation

Add declarative parameter validation to your [Interactor](https://github.com/collectiveidea/interactor) service objects with Rails-style syntax.

## Installation

```ruby
gem "interactor-validation"
```

## Quick Start

```ruby
class CreateUser
  include Interactor
  include Interactor::Validation

  params :email, :username, :age

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :username, presence: true, length: { minimum: 3, maximum: 20 }
  validates :age, numericality: { greater_than: 0, less_than: 150 }

  def call
    user = User.create!(email: email, username: username, age: age)
    context.user = user
  end
end

# Validation runs automatically before call
result = CreateUser.call(email: "", username: "ab", age: -5)
result.failure? # => true
result.errors   # => [
                #      { attribute: :email, type: :blank, message: "Email can't be blank" },
                #      { attribute: :username, type: :too_short, message: "Username is too short (minimum is 3 characters)" },
                #      { attribute: :age, type: :greater_than, message: "Age must be greater than 0" }
                #    ]
```

## Validation Types

### Presence

```ruby
validates :name, presence: true
# Error: { attribute: :name, type: :blank, message: "Name can't be blank" }
```

### Format (Regex)

```ruby
validates :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
# Error: { attribute: :email, type: :invalid, message: "Email is invalid" }
```

### Length

```ruby
validates :password, length: { minimum: 8, maximum: 128 }
validates :code, length: { is: 6 }
# Errors: { attribute: :password, type: :too_short, message: "Password is too short (minimum is 8 characters)" }
#         { attribute: :code, type: :wrong_length, message: "Code is the wrong length (should be 6 characters)" }
```

### Inclusion

```ruby
validates :status, inclusion: { in: %w[active pending inactive] }
# Error: { attribute: :status, type: :inclusion, message: "Status is not included in the list" }
```

### Numericality

```ruby
validates :price, numericality: { greater_than_or_equal_to: 0 }
validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
validates :count, numericality: true  # Just check if numeric

# Available constraints:
# - greater_than, greater_than_or_equal_to
# - less_than, less_than_or_equal_to
# - equal_to
```

### Boolean

```ruby
validates :is_active, boolean: true
# Ensures value is true or false (not truthy/falsy)
```

### Nested Validation

Validate nested hashes and arrays:

```ruby
# Hash validation
params :user
validates :user do
  attribute :name, presence: true
  attribute :email, format: { with: /@/ }
  attribute :age, numericality: { greater_than: 0 }
end

# Array validation
params :items
validates :items do
  attribute :name, presence: true
  attribute :price, numericality: { greater_than: 0 }
end
```

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
  config.halt_on_first_error = false

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
    config.halt_on_first_error = true
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

Improve performance by stopping validation early:

```ruby
configure_validation do |config|
  config.halt_on_first_error = true
end

validates :field1, presence: true
validates :field2, presence: true  # Won't run if field1 fails
validates :field3, presence: true  # Won't run if earlier fields fail
```

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

## Requirements

- Ruby >= 3.2.0
- Interactor ~> 3.0
- ActiveModel >= 6.0
- ActiveSupport >= 6.0

## License

MIT License - see [LICENSE.txt](LICENSE.txt)

## Contributing

Issues and pull requests are welcome at [https://github.com/zyxzen/interactor-validation](https://github.com/zyxzen/interactor-validation)
