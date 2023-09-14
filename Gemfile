# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in net-http-structured_field_values.gemspec
gemspec

group :development, :test do
  gem 'bundler', '~> 2.4'
  gem 'rake', '~> 13.0'

  gem 'rubocop', '~> 1.56'
  gem 'rubocop-performance', '~> 1.19'
  gem 'rubocop-rake', '~> 0.4'
  gem 'rubocop-rspec', '~> 2.1'
end

group :test do
  gem 'rspec', '~> 3.12'

  gem 'simplecov', '~> 0.22'
  gem 'simplecov-cobertura', '~> 2.1'
end
