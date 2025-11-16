## [Unreleased]

## [0.4.0] - 2025-11-17

### New Features

- **Added per-error halt support** - Use `errors.add(:field, "message", halt: true)` for fine-grained control over validation flow
- **Renamed `halt_on_first_error` to `halt`** - Simpler, more concise configuration option
- **Enhanced halt behavior** - Now supports both within-parameter and across-parameter early returns

### Improvements

- Validation halts immediately when `halt: true` is used in custom validations
- Global `halt` configuration stops validation after first error across all parameters
- Within-parameter halt skips remaining validation rules for that specific parameter
- Added `ErrorsWrapper` class to intercept `errors.add` calls and extract `halt:` option

### Deprecations

- `config.halt_on_first_error` is deprecated in favor of `config.halt` (backward compatible with alias)

### Documentation

- Updated README with comprehensive halt feature documentation and examples
- Added usage examples for both global and per-error halt configurations
- Documented halt behavior and use cases

### Testing

- Added 16 new tests specifically for halt functionality
- All 322 tests passing with no regressions
- Line coverage: 95.37% | Branch coverage: 85.09%

## [0.2.0] - 2024-11-16

### Security

- **CRITICAL:** Added ReDoS (Regular Expression Denial of Service) protection with configurable timeout
- **HIGH:** Fixed thread safety issues in validation rule registration using mutex locks
- Added memory protection with configurable maximum array size for nested validations
- Added regex pattern caching to prevent recompilation attacks

### Bug Fixes

- Fixed numeric precision loss bug - now uses `to_i` for integers and `to_f` for floats
- Fixed ambiguous handling of `nil` vs missing hash keys in nested validation
- Improved boolean validation to properly distinguish between `nil`, `false`, and missing values

### Performance Improvements

- Implemented regex pattern caching for up to 10x performance improvement on repeated validations
- Added configuration memoization during validation to reduce overhead
- Optimized string-to-numeric coercion to preserve integer precision

### New Features

- Added `config.regex_timeout` - Configurable timeout for regex validation (default: 100ms)
- Added `config.max_array_size` - Maximum array size for nested validation (default: 1000)
- Added `config.enable_instrumentation` - ActiveSupport::Notifications integration for monitoring
- Added `config.cache_regex_patterns` - Enable/disable regex pattern caching (default: true)
- Created `ErrorCodes` module with constants for all error types
- Added comprehensive YARD documentation for public API methods

### Documentation

- Added SECURITY.md with vulnerability reporting process and security best practices
- Added benchmark suite in `benchmark/validation_benchmark.rb`
- Enhanced inline documentation with YARD tags for all public methods
- Improved code organization by extracting error codes into separate module

### Breaking Changes

None - this release is fully backward compatible with 0.1.x

### Upgrade Notes

To take advantage of the new security features, no changes are required. However, you may want to configure:

```ruby
Interactor::Validation.configure do |config|
  config.regex_timeout = 0.05        # Stricter timeout for high-security contexts
  config.max_array_size = 100        # Lower limit for your use case
  config.enable_instrumentation = true # Monitor validation performance
end
```

## [0.1.1] - 2025-11-16

- Minor version bump for release preparation

## [0.1.0] - 2025-11-16

- Initial release
