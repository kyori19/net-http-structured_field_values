#!/usr/bin/env ruby
# frozen_string_literal: true

case ARGV[0]
when 'source'
  require_relative '../../lib/net/http/structured_field_values/version'
when 'gem'
  require 'bundler/inline'

  gemfile do
    source 'https://rubygems.org'

    gem 'net-http-structured_field_values'
  end
else
  raise ArgumentError, "Unknown argument: #{ARGV[0]}"
end

puts Net::HTTP::StructuredFieldValues::VERSION
