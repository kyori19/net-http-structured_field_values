# frozen_string_literal: true

require 'simplecov'
require 'simplecov-html'
require 'simplecov-cobertura'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
                                                                 SimpleCov::Formatter::HTMLFormatter,
                                                                 SimpleCov::Formatter::CoberturaFormatter,
                                                               ])
SimpleCov.start do
  enable_coverage :branch
  primary_coverage :branch
end

require 'bundler/setup'
require 'net/http/structured_field_values'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
