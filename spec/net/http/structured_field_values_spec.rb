# frozen_string_literal: true

RSpec.describe Net::Http::StructuredFieldValues do
  it 'has a version number' do
    expect(Net::Http::StructuredFieldValues::VERSION).not_to be_nil
  end
end
