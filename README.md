# Interactor::Validation

Add Rails-style parameter validation to your [Interactor](https://github.com/collectiveidea/interactor) service objects with simple, declarative syntax.

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

# Success
result = CreateUser.call(email: "dev@example.com", username: "developer", age: 25)
result.success? # => true
result.user     # => #<User...>

# Failure - automatic validation
result = CreateUser.call(email: "", username: "ab", age: -5)
result.failure? # => true
result.errors   # => [
                #      { code: "EMAIL_IS_REQUIRED" },
                #      { code: "USERNAME_BELOW_MIN_LENGTH_3" },
                #      { code: "AGE_MUST_BE_GREATER_THAN_0" }
                #    ]
```

## Features

### Parameter Declaration

Use `params` to declare expected parameters - they're automatically delegated to context:

```ruby
params :user_id, :action

def call
  # Access directly instead of context.user_id
  user = User.find(user_id)
  user.perform(action)
end
```

### Validation Rules

All validations run **before** your `call` method. If validation fails, the interactor stops and returns structured errors.

**Presence**
```ruby
validates :name, presence: true
# Error: { code: "NAME_IS_REQUIRED" }
```

**Format (Regex)**
```ruby
validates :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
# Error: { code: "EMAIL_INVALID_FORMAT" }
```

**Length**
```ruby
validates :password, length: { minimum: 8, maximum: 128 }
validates :code, length: { is: 6 }
# Errors: { code: "PASSWORD_BELOW_MIN_LENGTH_8" }
#         { code: "CODE_INVALID_LENGTH_6" }
```

**Inclusion**
```ruby
validates :status, inclusion: { in: %w[active pending inactive] }
# Error: { code: "STATUS_NOT_IN_LIST" }
```

**Numericality**
```ruby
validates :price, numericality: { greater_than_or_equal_to: 0 }
validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
# Errors: { code: "PRICE_MUST_BE_GREATER_THAN_OR_EQUAL_TO_0" }
```

### Error Formats

The gem supports two error formatting modes:

#### Code Mode (Default)

Returns structured error codes ideal for APIs and i18n:

```ruby
result.errors # => [
              #      { code: "EMAIL_IS_REQUIRED" },
              #      { code: "USERNAME_BELOW_MIN_LENGTH_3" }
              #    ]
```

#### Default Mode

Returns ActiveModel-style errors with human-readable messages:

```ruby
Interactor::Validation.configure do |config|
  config.error_mode = :default
end

result.errors # => [
              #      { attribute: :email, type: :blank, message: "Email can't be blank" },
              #      { attribute: :username, type: :too_short, message: "Username is too short (minimum is 3 characters)" }
              #    ]
```

## Configuration

### Global Configuration

Configure validation behavior for all interactors:

```ruby
# config/initializers/interactor_validation.rb
Interactor::Validation.configure do |config|
  # Error format mode: :code (default) or :default
  config.error_mode = :code

  # Stop validation at first error (default: false)
  config.halt_on_first_error = false

  # Security: Regex timeout in seconds (default: 0.1)
  config.regex_timeout = 0.1

  # Security: Maximum array size for nested validation (default: 1000)
  config.max_array_size = 1000

  # Performance: Cache compiled regex patterns (default: true)
  config.cache_regex_patterns = true

  # Monitoring: Enable ActiveSupport::Notifications (default: false)
  config.enable_instrumentation = false
end
```

### Per-Interactor Configuration

Override global settings for specific interactors:

```ruby
class CreateUser
  include Interactor
  include Interactor::Validation

  configure_validation do |config|
    config.error_mode = :default
    config.halt_on_first_error = true
  end

  validates :username, presence: true
  validates :email, presence: true
end
```

### Custom Error Messages

Provide custom error messages for any validation:

```ruby
# With :code mode
configure_validation do |config|
  config.error_mode = :code
end

validates :username, presence: { message: "CUSTOM_REQUIRED_ERROR" }
validates :email, format: { with: /@/, message: "CUSTOM_FORMAT_ERROR" }
# => { code: "USERNAME_CUSTOM_REQUIRED_ERROR" }
# => { code: "EMAIL_CUSTOM_FORMAT_ERROR" }

# With :default mode
configure_validation do |config|
  config.error_mode = :default
end

validates :bio, length: { maximum: 500, message: "is too long (max 500 chars)" }
# => { attribute: :bio, type: :too_long, message: "is too long (max 500 chars)" }
```

### Advanced Usage

#### Halt on First Error

Improve performance by stopping validation at the first failure:

```ruby
configure_validation do |config|
  config.halt_on_first_error = true  # Stop at first error
end

validates :field1, presence: true
validates :field2, presence: true  # Won't run if field1 fails
validates :field3, presence: true  # Won't run if field1 or field2 fails
```

#### Integration with ActiveModel Validations

Use ActiveModel's custom validation callbacks:

```ruby
class CreateUser
  include Interactor
  include Interactor::Validation

  params :user_data

  validate :check_user_data_structure
  validates :username, presence: true

  def check_user_data_structure
    errors.add(:user_data, "must be a Hash") unless user_data.is_a?(Hash)
  end
end
```

## Security

This gem includes built-in protection against common security vulnerabilities:

### ReDoS Protection (v0.2.0+)

Regular Expression Denial of Service attacks are prevented with automatic timeouts:

```ruby
config.regex_timeout = 0.1 # 100ms default timeout
```

If a regex takes longer than the configured timeout, validation will fail safely instead of hanging.

### Memory Protection (v0.2.0+)

Array validation includes automatic size limits to prevent memory exhaustion:

```ruby
config.max_array_size = 1000 # Default limit
```

### Thread Safety (v0.2.0+)

Validation rule registration is thread-safe and can be used safely in multi-threaded environments (Puma, Sidekiq).

### Best Practices

1. **Use simple regex patterns** - Avoid nested quantifiers that can cause backtracking
2. **Sanitize outputs** - Always escape error messages when rendering in HTML
3. **Set appropriate limits** - Configure `max_array_size` based on your application needs
4. **Monitor performance** - Enable instrumentation in production to detect slow validations

For detailed security information, see [SECURITY.md](SECURITY.md).

## Performance

### Benchmarking

Run the included benchmark suite to measure performance:

```bash
bundle exec ruby benchmark/validation_benchmark.rb
```

### Monitoring

Enable instrumentation to track validation performance in production:

```ruby
config.enable_instrumentation = true

ActiveSupport::Notifications.subscribe('validate_params.interactor_validation') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Rails.logger.info "Validation took #{event.duration}ms for #{event.payload[:interactor]}"
end
```

## Development

```bash
bin/setup              # Install dependencies
bundle exec rspec      # Run tests
bundle exec rubocop    # Lint code
bin/console            # Interactive console
```

## Requirements

- Ruby >= 3.2.0
- Interactor ~> 3.0
- ActiveModel >= 6.0

## License

MIT License - see [LICENSE.txt](LICENSE.txt)
