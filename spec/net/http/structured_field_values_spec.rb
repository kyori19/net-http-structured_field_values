# frozen_string_literal: true

RSpec.describe Net::HTTP::StructuredFieldValues do
  it 'has a version number' do
    expect(Net::HTTP::StructuredFieldValues::VERSION).not_to be_nil
  end
end
