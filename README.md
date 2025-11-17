# Interactor::Validation

Minimal, lightweight parameter validation for [Interactor](https://github.com/collectiveidea/interactor) service objects.

## Features

- **Zero dependencies** - Only depends on `interactor` and Ruby stdlib
- **Tiny footprint** - ~400 lines of code total
- **Production-ready** - Battle-tested validation logic
- **Simple API** - Rails-style declarative validations
- **Nested validation** - Validate hashes and arrays
- **Custom validators** - Override `validate!` for business logic

## Installation

```ruby
gem "interactor-validation"
```

## Usage

### Quick Example

```ruby
class CreateUser
  include Interactor
  include Interactor::Validation

  params :email, :username, :age

  validates :email, presence: true, format: { with: /@/ }
  validates :username, presence: true
  validates :age, numericality: { greater_than: 0 }

  def call
    User.create!(email: email, username: username, age: age)
  end
end

result = CreateUser.call(email: "", username: "", age: -5)
result.failure? # => true
result.errors   # => [
                #      { attribute: :email, type: :blank, message: "Email can't be blank" },
                #      { attribute: :username, type: :blank, message: "Username can't be blank" },
                #      { attribute: :age, type: :greater_than, message: "Age must be greater than 0" }
                #    ]
```

## Validations

### Presence

```ruby
validates :name, presence: true
validates :email, presence: { message: "Email is required" }
```

### Format

```ruby
validates :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
validates :username, format: { with: /\A[a-z0-9_]+\z/, message: "Invalid username" }
```

### Length

```ruby
validates :password, length: { minimum: 8, maximum: 128 }
validates :code, length: { is: 6 }
validates :bio, length: { maximum: 500 }
```

Options: `minimum`, `maximum`, `is`

### Inclusion

```ruby
validates :status, inclusion: { in: %w[active pending inactive] }
validates :role, inclusion: { in: ["admin", "user", "guest"], message: "Invalid role" }
```

### Numericality

```ruby
validates :age, numericality: { greater_than: 0 }
validates :price, numericality: { greater_than_or_equal_to: 0 }
validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
validates :rating, numericality: { equal_to: 5 }
validates :count, numericality: true  # Just check if numeric
```

Options: `greater_than`, `greater_than_or_equal_to`, `less_than`, `less_than_or_equal_to`, `equal_to`

### Boolean

```ruby
validates :is_active, boolean: true
validates :terms_accepted, boolean: true
```

Ensures value is exactly `true` or `false` (not truthy/falsy).

### Nested Validation

Validate nested hashes and arrays:

**Hash Validation:**

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
result.errors # => [
              #      { attribute: :"user.name", type: :blank, message: "User name can't be blank" },
              #      { attribute: :"user.email", type: :invalid, message: "User email is invalid" }
              #    ]
```

**Array Validation:**

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
result.errors # => [
              #      { attribute: :"items[1].name", type: :blank, message: "Items[1] name can't be blank" },
              #      { attribute: :"items[1].price", type: :greater_than, message: "Items[1] price must be greater than 0" }
              #    ]
```

## Custom Validations

Override `validate!` for custom business logic:

```ruby
class CreateOrder
  include Interactor
  include Interactor::Validation

  params :product_id, :quantity, :user_id

  validates :product_id, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :user_id, presence: true

  def validate!
    super  # Run parameter validations first

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

## Error Format

Errors are returned as an array of hashes:

```ruby
{
  attribute: :email,        # The field that failed
  type: :blank,             # The validation type
  message: "Email can't be blank"  # Human-readable message
}
```

## Parameter Delegation

The `params` macro automatically delegates to `context`:

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

## Requirements

- Ruby >= 3.2.0
- Interactor ~> 3.0

## Design Philosophy

This gem is intentionally minimal:

- **No configuration** - Opinionated defaults that just work
- **No optional features** - Core validations only
- **No security theater** - Ruby's regex engine is safe enough
- **No performance tricks** - Simple, readable code
- **No external dependencies** - Just Interactor + stdlib

## Development

```bash
bundle install
bundle exec rspec       # Run tests
bundle exec rubocop     # Lint code
```

## License

MIT License - see [LICENSE.txt](LICENSE.txt)

## Contributing

Issues and pull requests welcome at https://github.com/zyxzen/interactor-validation
