# frozen_string_literal: true

require 'spec_helper'

require 'net/http/structured_field_values/serializer'

# rubocop:disable Naming/VariableNumber

RSpec.describe Net::HTTP::StructuredFieldValues::Serializer do
  def self.parameterized_value(value, parameters)
    Net::HTTP::StructuredFieldValues::ParameterizedValue.new(value, parameters)
  end

  valid_tests = [
    {
      name: 'Foo-Example',
      input: parameterized_value(2, { 'foourl' => 'https://foo.example.com/' }),
      expected: '2;foourl="https://foo.example.com/"',
    },
    {
      name: 'Example-StrListHeader',
      input: [
        parameterized_value('foo', {}),
        parameterized_value('bar', {}),
        parameterized_value('It was the best of times.', {}),
      ],
      expected: '"foo", "bar", "It was the best of times."',
    },
    {
      name: 'Example-Hdr (list on one line)',
      input: [parameterized_value(:foo, {}), parameterized_value(:bar, {})],
      expected: 'foo, bar',
    },
    {
      name: 'Example-StrListListHeader',
      input: [
        parameterized_value([parameterized_value('foo', {}), parameterized_value('bar', {})], {}),
        parameterized_value([parameterized_value('baz', {})], {}),
        parameterized_value([parameterized_value('bat', {}), parameterized_value('one', {})], {}),
        parameterized_value([], {}),
      ],
      expected: '("foo" "bar"), ("baz"), ("bat" "one"), ()',
    },
    {
      name: 'Example-ListListParam',
      input: [
        parameterized_value([parameterized_value('foo', { 'a' => 1, 'b' => 2 })], { 'lvl' => 5 }),
        parameterized_value([parameterized_value('bar', {}), parameterized_value('baz', {})], { 'lvl' => 1 }),
      ],
      expected: '("foo";a=1;b=2);lvl=5, ("bar" "baz");lvl=1',
    },
    {
      name: 'Example-ParamListHeader',
      input: [
        parameterized_value(:abc, { 'a' => 1, 'b' => 2, 'cde_456' => true }),
        parameterized_value(
          [parameterized_value(:ghi, { 'jk' => 4 }), parameterized_value(:l, {})],
          { 'q' => '9', 'r' => :w },
        ),
      ],
      expected: 'abc;a=1;b=2;cde_456, (ghi;jk=4 l);q="9";r=w',
    },
    {
      name: 'Example-IntHeader',
      input: parameterized_value(1, { 'a' => true, 'b' => false }),
      expected: '1;a;b=?0',
    },
    {
      name: 'Example-DictHeader',
      input: {
        'en' => parameterized_value('Applepie', {}),
        'da' => parameterized_value("\xC3\x86blet\xC3\xA6rte".b, {}),
      },
      expected: 'en="Applepie", da=:w4ZibGV0w6ZydGU=:',
    },
    {
      name: 'Example-DictHeader (boolean values)',
      input: {
        'a' => parameterized_value(false, {}),
        'b' => parameterized_value(true, {}),
        'c' => parameterized_value(true, { 'foo' => :bar }),
      },
      expected: 'a=?0, b, c;foo=bar',
    },
    {
      name: 'Example-DictListHeader',
      input: {
        'rating' => parameterized_value(1.5, {}),
        'feelings' => parameterized_value([parameterized_value(:joy, {}), parameterized_value(:sadness, {})], {}),
      },
      expected: 'rating=1.5, feelings=(joy sadness)',
    },
    {
      name: 'Example-MixDict',
      input: {
        'a' => parameterized_value([parameterized_value(1, {}), parameterized_value(2, {})], {}),
        'b' => parameterized_value(3, {}),
        'c' => parameterized_value(4, { 'aa' => :bb }),
        'd' => parameterized_value([parameterized_value(5, {}), parameterized_value(6, {})], { 'valid' => true }),
      },
      expected: 'a=(1 2), b=3, c=4;aa=bb, d=(5 6);valid',
    },
    {
      name: 'Example-Hdr (dictionary on one line)',
      input: {
        'foo' => parameterized_value(1, {}),
        'bar' => parameterized_value(2, {}),
      },
      expected: 'foo=1, bar=2',
    },
    {
      name: 'Example-IntItemHeader',
      input: parameterized_value(5, {}),
      expected: '5',
    },
    {
      name: 'Example-IntItemHeader (params)',
      input: parameterized_value(5, { 'foo' => :bar }),
      expected: '5;foo=bar',
    },
    {
      name: 'Example-IntegerHeader',
      input: parameterized_value(42, {}),
      expected: '42',
    },
    {
      name: 'Example-FloatHeader',
      input: parameterized_value(4.5, {}),
      expected: '4.5',
    },
    {
      name: 'Example-StringHeader',
      input: parameterized_value('hello world', {}),
      expected: '"hello world"',
    },
    {
      name: 'Example-BinaryHdr',
      input: parameterized_value('pretend this is binary content.'.b, {}),
      expected: ':cHJldGVuZCB0aGlzIGlzIGJpbmFyeSBjb250ZW50Lg==:',
    },
    {
      name: 'Example-BoolHdr',
      input: parameterized_value(true, {}),
      expected: '?1',
    },
    {
      name: 'basic binary',
      input: parameterized_value('hello'.b, {}),
      expected: ':aGVsbG8=:',
    },
    {
      name: 'empty binary',
      input: parameterized_value(''.b, {}),
      expected: '::',
    },
    {
      name: 'non-ASCII binary',
      input: parameterized_value("\xFF\xE0!".b, {}),
      expected: ':/+Ah:',
    },
    {
      name: 'basic true boolean',
      input: parameterized_value(true, {}),
      expected: '?1',
    },
    {
      name: 'basic false boolean',
      input: parameterized_value(false, {}),
      expected: '?0',
    },
    {
      name: 'basic dictionary',
      input: {
        'en' => parameterized_value('Applepie', {}),
        'da' => parameterized_value("\xC3\x86blet\xC3\xA6rte\n".b, {}),
      },
      expected: 'en="Applepie", da=:w4ZibGV0w6ZydGUK:',
    },
    {
      name: 'empty dictionary',
      input: {},
      expected: '',
    },
    {
      name: 'single item dictionary',
      input: {
        'a' => parameterized_value(1, {}),
      },
      expected: 'a=1',
    },
    {
      name: 'list item dictionary',
      input: {
        'a' => parameterized_value([parameterized_value(1, {}), parameterized_value(2, {})], {}),
      },
      expected: 'a=(1 2)',
    },
    {
      name: 'single list item dictionary',
      input: {
        'a' => parameterized_value([parameterized_value(1, {})], {}),
      },
      expected: 'a=(1)',
    },
    {
      name: 'empty list item dictionary',
      input: {
        'a' => parameterized_value([], {}),
      },
      expected: 'a=()',
    },
    {
      name: 'missing value dictionary',
      input: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(true, {}),
        'c' => parameterized_value(3, {}),
      },
      expected: 'a=1, b, c=3',
    },
    {
      name: 'all missing value dictionary',
      input: {
        'a' => parameterized_value(true, {}),
        'b' => parameterized_value(true, {}),
        'c' => parameterized_value(true, {}),
      },
      expected: 'a, b, c',
    },
    {
      name: 'start missing value dictionary',
      input: {
        'a' => parameterized_value(true, {}),
        'b' => parameterized_value(2, {}),
      },
      expected: 'a, b=2',
    },
    {
      name: 'end missing value dictionary',
      input: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(true, {}),
      },
      expected: 'a=1, b',
    },
    {
      name: 'missing value with params dictionary',
      input: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(true, { 'foo' => 9 }),
        'c' => parameterized_value(3, {}),
      },
      expected: 'a=1, b;foo=9, c=3',
    },
    {
      name: 'duplicate key dictionary',
      input: {
        'a' => parameterized_value(3, {}),
        'b' => parameterized_value(2, {}),
      },
      expected: 'a=3, b=2',
    },
    {
      name: 'basic integer',
      input: parameterized_value(42, {}),
      expected: '42',
    },
    {
      name: 'zero integer',
      input: parameterized_value(0, {}),
      expected: '0',
    },
    {
      name: 'negative integer',
      input: parameterized_value(-42, {}),
      expected: '-42',
    },
    {
      name: 'long integer',
      input: parameterized_value(123456789012345, {}),
      expected: '123456789012345',
    },
    {
      name: 'long negative integer',
      input: parameterized_value(-123456789012345, {}),
      expected: '-123456789012345',
    },
    {
      name: 'simple decimal',
      input: parameterized_value(1.23, {}),
      expected: '1.23',
    },
    {
      name: 'negative decimal',
      input: parameterized_value(-1.23, {}),
      expected: '-1.23',
    },
    {
      name: 'tricky precision decimal',
      input: parameterized_value(123456789012.1, {}),
      expected: '123456789012.1',
    },
    {
      name: 'decimal with three fractional digits',
      input: parameterized_value(1.123, {}),
      expected: '1.123',
    },
    {
      name: 'negative decimal with three fractional digits',
      input: parameterized_value(-1.123, {}),
      expected: '-1.123',
    },
    {
      name: 'round positive odd decimal',
      input: parameterized_value(0.0015, {}),
      expected: '0.002',
    },
    {
      name: 'round positive even decimal',
      input: parameterized_value(0.0025, {}),
      expected: '0.002',
    },
    {
      name: 'round negative odd decimal',
      input: parameterized_value(-0.0015, {}),
      expected: '-0.002',
    },
    {
      name: 'round negative even decimal',
      input: parameterized_value(-0.0025, {}),
      expected: '-0.002',
    },
    {
      name: 'decimal round up to integer part',
      input: parameterized_value(9.9995, {}),
      expected: '10.0',
    },
    {
      name: 'basic parameterised dict',
      input: {
        'abc' => parameterized_value(123, { 'a' => 1, 'b' => 2 }),
        'def' => parameterized_value(456, {}),
        'ghi' => parameterized_value(789, { 'q' => 9, 'r' => '+w' }),
      },
      expected: 'abc=123;a=1;b=2, def=456, ghi=789;q=9;r="+w"',
    },
    {
      name: 'single item parameterised dict',
      input: {
        'a' => parameterized_value(:b, { 'q' => 1.0 }),
      },
      expected: 'a=b;q=1.0',
    },
    {
      name: 'list item parameterised dictionary',
      input: {
        'a' => parameterized_value([parameterized_value(1, {}), parameterized_value(2, {})], { 'q' => 1.0 }),
      },
      expected: 'a=(1 2);q=1.0',
    },
    {
      name: 'missing parameter value parameterised dict',
      input: {
        'a' => parameterized_value(3, { 'c' => true, 'd' => 5 }),
      },
      expected: 'a=3;c;d=5',
    },
    {
      name: 'terminal missing parameter value parameterised dict',
      input: {
        'a' => parameterized_value(3, { 'c' => 5, 'd' => true }),
      },
      expected: 'a=3;c=5;d',
    },
    {
      name: 'basic string',
      input: parameterized_value('foo bar', {}),
      expected: '"foo bar"',
    },
    {
      name: 'empty string',
      input: parameterized_value('', {}),
      expected: '""',
    },
    {
      name: 'long string',
      input: parameterized_value('foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo ', {}), # rubocop:disable Layout/LineLength
      expected: '"foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo "', # rubocop:disable Layout/LineLength
    },
    {
      name: 'whitespace string',
      input: parameterized_value('   ', {}),
      expected: '"   "',
    },
    {
      name: 'string quoting',
      input: parameterized_value('foo "bar" \\ baz', {}),
      expected: '"foo \\"bar\\" \\\\ baz"',
    },
    {
      name: 'basic token - item',
      input: parameterized_value(:'a_b-c.d3:f%00/*', {}),
      expected: 'a_b-c.d3:f%00/*',
    },
    {
      name: 'token with capitals - item',
      input: parameterized_value(:fooBar, {}),
      expected: 'fooBar',
    },
    {
      name: 'token starting with capitals - item',
      input: parameterized_value(:FooBar, {}),
      expected: 'FooBar',
    },
    {
      name: 'basic token - list',
      input: [parameterized_value(:'a_b-c3/*', {})],
      expected: 'a_b-c3/*',
    },
    {
      name: 'token with capitals - list',
      input: [parameterized_value(:fooBar, {})],
      expected: 'fooBar',
    },
    {
      name: 'token starting with capitals - list',
      input: [parameterized_value(:FooBar, {})],
      expected: 'FooBar',
    },
    {
      name: 'basic list',
      input: [parameterized_value(1, {}), parameterized_value(42, {})],
      expected: '1, 42',
    },
    {
      name: 'empty list',
      input: [],
      expected: '',
    },
    {
      name: 'leading SP list',
      input: [parameterized_value(42, {}), parameterized_value(43, {})],
      expected: '42, 43',
    },
    {
      name: 'single item list',
      input: [parameterized_value(42, {})],
      expected: '42',
    },
    {
      name: 'basic list of lists',
      input: [
        parameterized_value([parameterized_value(1, {}), parameterized_value(2, {})], {}),
        parameterized_value([parameterized_value(42, {}), parameterized_value(43, {})], {}),
      ],
      expected: '(1 2), (42 43)',
    },
    {
      name: 'single item list of lists',
      input: [parameterized_value([parameterized_value(42, {})], {})],
      expected: '(42)',
    },
    {
      name: 'empty item list of lists',
      input: [parameterized_value([], {})],
      expected: '()',
    },
    {
      name: 'empty middle item list of lists',
      input: [
        parameterized_value([parameterized_value(1, {})], {}),
        parameterized_value([], {}),
        parameterized_value([parameterized_value(42, {})], {}),
      ],
      expected: '(1), (), (42)',
    },
    {
      name: 'extra whitespace list of lists',
      input: [parameterized_value([parameterized_value(1, {}), parameterized_value(42, {})], {})],
      expected: '(1 42)',
    },
    {
      name: 'basic parameterised list',
      input: [
        parameterized_value(:abc_123, { 'a' => 1, 'b' => 2, 'cdef_456' => true }),
        parameterized_value(:ghi, { 'q' => 9, 'r' => '+w' }),
      ],
      expected: 'abc_123;a=1;b=2;cdef_456, ghi;q=9;r="+w"',
    },
    {
      name: 'single item parameterised list',
      input: [parameterized_value(:'text/html', { 'q' => 1.0 })],
      expected: 'text/html;q=1.0',
    },
    {
      name: 'missing parameter value parameterised list',
      input: [parameterized_value(:'text/html', { 'a' => true, 'q' => 1.0 })],
      expected: 'text/html;a;q=1.0',
    },
    {
      name: 'missing terminal parameter value parameterised list',
      input: [parameterized_value(:'text/html', { 'q' => 1.0, 'a' => true })],
      expected: 'text/html;q=1.0;a',
    },
    {
      name: 'parameterised inner list',
      input: [
        parameterized_value([parameterized_value(:abc_123, {})], { 'a' => 1, 'b' => 2 }),
        parameterized_value(:cdef_456, {}),
      ],
      expected: '(abc_123);a=1;b=2, cdef_456',
    },
    {
      name: 'parameterised inner list item',
      input: [parameterized_value([parameterized_value(:abc_123, { 'a' => 1, 'b' => 2, 'cdef_456' => true })], {})],
      expected: '(abc_123;a=1;b=2;cdef_456)',
    },
    {
      name: 'parameterised inner list with parameterised item',
      input: [parameterized_value([parameterized_value(:abc_123, { 'a' => 1, 'b' => 2 })], { 'cdef_456' => true })],
      expected: '(abc_123;a=1;b=2);cdef_456',
    },
    {
      name: 'unparameterized dictionary',
      input: {
        'a' => 123,
        'b' => :cde,
      },
      expected: 'a=123, b=cde',
    },
    {
      name: 'unparameterized list',
      input: [[1, 2, 3], '456'],
      expected: '(1 2 3), "456"',
    },
    {
      name: 'unparameterized item',
      input: 12,
      expected: '12',
    },
    {
      name: 'parameterized item in unparameterized list',
      input: [1, 2, parameterized_value(34, { 'q' => 5 })],
      expected: '1, 2, 34;q=5',
    },
  ]

  valid_tests.each do |test|
    it "serializes #{test[:name]}" do
      expect(described_class.serialize(test[:input])).to eq(test[:expected])
    end
  end

  invalid_tests = [
    {
      name: 'too big positive integer',
      input: parameterized_value(1000000000000000, {}),
    },
    {
      name: 'too big negative integer',
      input: parameterized_value(-1000000000000000, {}),
    },
    {
      name: 'too big positive decimal',
      input: parameterized_value(1000000000000.1, {}),
    },
    {
      name: 'too big negative decimal',
      input: parameterized_value(-1000000000000.1, {}),
    },
    {
      name: 'unsupported object',
      input: parameterized_value(Object.new, {}),
    },
    {
      name: 'unparameterized unsupported object',
      input: Object.new,
    },
    {
      name: 'nil',
      input: parameterized_value(nil, {}),
    },
    {
      name: 'unparameterized nil',
      input: nil,
    },
    {
      name: 'invalid leading character in dictionary key',
      input: {
        '/abc' => 12,
      },
    },
    {
      name: 'another invalid character in dictionary key',
      input: {
        '_abc' => 12,
      },
    },
    {
      name: 'invalid character in dictionary key',
      input: {
        'a/bc' => 12,
      },
    },
    {
      name: 'invalid leading character in token',
      input: parameterized_value(:'/abc', {}),
    },
    {
      name: 'invalid character in token',
      input: parameterized_value(:'a{bc', {}),
    },
    {
      name: 'another invalid character in token',
      input: parameterized_value(:'a"bc', {}),
    },
    {
      name: 'non-ascii character in string',
      input: "\x8a",
    },
    {
      name: 'invalid character in string',
      input: "\x19",
    },
  ]

  invalid_tests.each do |test|
    it "fails to serialize #{test[:name]}" do
      expect do
        described_class.serialize(test[:input])
      end.to raise_error(Net::HTTP::StructuredFieldValues::Serializer::SerializationError)
    end
  end
end

# rubocop:enable Naming/VariableNumber
