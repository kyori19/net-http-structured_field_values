# frozen_string_literal: true

require 'spec_helper'

require 'net/http/structured_field_values/parameterized_value'

RSpec.describe Net::HTTP::StructuredFieldValues::ParameterizedValue do
  describe '#==' do
    subject(:value) { described_class.new('value', { 'ab' => 123, 'cd' => 'efg' }) }

    it 'returns true when both value and params are equal' do
      expect(value).to eq(described_class.new('value', { 'ab' => 123, 'cd' => 'efg' }))
    end

    it 'returns false when value is not equal' do
      expect(value).not_to eq(described_class.new('value2', { 'ab' => 123, 'cd' => 'efg' }))
    end

    it 'returns false when params are not equal' do
      expect(value).not_to eq(described_class.new('value', { 'ab' => 123, 'cd' => 'efg2' }))
      expect(value).not_to eq(described_class.new('value', { 'ab' => 123, 'cd' => 'efg', 'hi' => true }))
      expect(value).not_to eq(described_class.new('value', { 'ab' => 123 }))
    end
  end
end
