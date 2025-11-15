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

### Error Format

Errors follow a consistent format: `PARAM_NAME_ERROR_TYPE` in uppercase.

```ruby
result.errors # => [
              #      { code: "EMAIL_IS_REQUIRED" },
              #      { code: "USERNAME_BELOW_MIN_LENGTH_3" }
              #    ]
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
