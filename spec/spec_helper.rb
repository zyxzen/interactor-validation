# frozen_string_literal: true

require "pry"
require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
  enable_coverage :branch
  minimum_coverage line: 97, branch: 92
end

require "interactor"
require "interactor/validation"

RSpec.configure do |config|
  # Use Fuubar for better progress output
  config.formatter = "Fuubar"
  config.add_formatter "documentation" if ENV["VERBOSE"]

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
