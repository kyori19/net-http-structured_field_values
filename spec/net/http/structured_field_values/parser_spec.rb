# frozen_string_literal: true

require 'spec_helper'

require 'net/http/structured_field_values/parser'

# rubocop:disable Naming/VariableNumber

# @see {https://github.com/httpwg/structured-field-tests}
RSpec.describe Net::HTTP::StructuredFieldValues::Parser do
  def self.parameterized_value(value, parameters)
    Net::HTTP::StructuredFieldValues::ParameterizedValue.new(value, parameters)
  end

  valid_tests = [
    {
      name: 'Foo-Example',
      type: 'item',
      input: '2; foourl="https://foo.example.com/"',
      expected: parameterized_value(2, { 'foourl' => 'https://foo.example.com/' }),
    },
    {
      name: 'Example-StrListHeader',
      type: 'list',
      input: '"foo", "bar", "It was the best of times."',
      expected: [
        parameterized_value('foo', {}),
        parameterized_value('bar', {}),
        parameterized_value('It was the best of times.', {}),
      ],
    },
    {
      name: 'Example-Hdr (list on one line)',
      type: 'list',
      input: 'foo, bar',
      expected: [parameterized_value(:foo, {}), parameterized_value(:bar, {})],
    },
    {
      name: 'Example-StrListListHeader',
      type: 'list',
      input: '("foo" "bar"), ("baz"), ("bat" "one"), ()',
      expected: [
        parameterized_value([parameterized_value('foo', {}), parameterized_value('bar', {})], {}),
        parameterized_value([parameterized_value('baz', {})], {}),
        parameterized_value([parameterized_value('bat', {}), parameterized_value('one', {})], {}),
        parameterized_value([], {}),
      ],
    },
    {
      name: 'Example-ListListParam',
      type: 'list',
      input: '("foo"; a=1;b=2);lvl=5, ("bar" "baz");lvl=1',
      expected: [
        parameterized_value([parameterized_value('foo', { 'a' => 1, 'b' => 2 })], { 'lvl' => 5 }),
        parameterized_value([parameterized_value('bar', {}), parameterized_value('baz', {})], { 'lvl' => 1 }),
      ],
    },
    {
      name: 'Example-ParamListHeader',
      type: 'list',
      input: 'abc;a=1;b=2; cde_456, (ghi;jk=4 l);q="9";r=w',
      expected: [
        parameterized_value(:abc, { 'a' => 1, 'b' => 2, 'cde_456' => true }),
        parameterized_value(
          [
            parameterized_value(:ghi, { 'jk' => 4 }),
            parameterized_value(:l, {}),
          ],
          { 'q' => '9', 'r' => :w },
        ),
      ],
    },
    {
      name: 'Example-IntHeader',
      type: 'item',
      input: '1; a; b=?0',
      expected: parameterized_value(1, { 'a' => true, 'b' => false }),
    },
    {
      name: 'Example-DictHeader',
      type: 'dictionary',
      input: 'en="Applepie", da=:w4ZibGV0w6ZydGU=:',
      expected: {
        'en' => parameterized_value('Applepie', {}),
        'da' => parameterized_value("\xC3\x86blet\xC3\xA6rte".b, {}),
      },
    },
    {
      name: 'Example-DictHeader (boolean values)',
      type: 'dictionary',
      input: 'a=?0, b, c; foo=bar',
      expected: {
        'a' => parameterized_value(false, {}),
        'b' => parameterized_value(true, {}),
        'c' => parameterized_value(true, { 'foo' => :bar }),
      },
    },
    {
      name: 'Example-DictListHeader',
      type: 'dictionary',
      input: 'rating=1.5, feelings=(joy sadness)',
      expected: {
        'rating' => parameterized_value(1.5, {}),
        'feelings' => parameterized_value([parameterized_value(:joy, {}), parameterized_value(:sadness, {})], {}),
      },
    },
    {
      name: 'Example-MixDict',
      type: 'dictionary',
      input: 'a=(1 2), b=3, c=4;aa=bb, d=(5 6);valid',
      expected: {
        'a' => parameterized_value([parameterized_value(1, {}), parameterized_value(2, {})], {}),
        'b' => parameterized_value(3, {}),
        'c' => parameterized_value(4, { 'aa' => :bb }),
        'd' => parameterized_value([parameterized_value(5, {}), parameterized_value(6, {})], { 'valid' => true }),
      },
    },
    {
      name: 'Example-Hdr (dictionary on one line)',
      type: 'dictionary',
      input: 'foo=1, bar=2',
      expected: {
        'foo' => parameterized_value(1, {}),
        'bar' => parameterized_value(2, {}),
      },
    },
    {
      name: 'Example-IntItemHeader',
      type: 'item',
      input: '5',
      expected: parameterized_value(5, {}),
    },
    {
      name: 'Example-IntItemHeader (params)',
      type: 'item',
      input: '5; foo=bar',
      expected: parameterized_value(5, { 'foo' => :bar }),
    },
    {
      name: 'Example-IntegerHeader',
      type: 'item',
      input: '42',
      expected: parameterized_value(42, {}),
    },
    {
      name: 'Example-FloatHeader',
      type: 'item',
      input: '4.5',
      expected: parameterized_value(4.5, {}),
    },
    {
      name: 'Example-StringHeader',
      type: 'item',
      input: '"hello world"',
      expected: parameterized_value('hello world', {}),
    },
    {
      name: 'Example-BinaryHdr',
      type: 'item',
      input: ':cHJldGVuZCB0aGlzIGlzIGJpbmFyeSBjb250ZW50Lg==:',
      expected: parameterized_value('pretend this is binary content.'.b, {}),
    },
    {
      name: 'Example-BoolHdr',
      type: 'item',
      input: '?1',
      expected: parameterized_value(true, {}),
    },
    {
      name: 'basic binary',
      type: 'item',
      input: ':aGVsbG8=:',
      expected: parameterized_value('hello'.b, {}),
    },
    {
      name: 'empty binary',
      type: 'item',
      input: '::',
      expected: parameterized_value(''.b, {}),
    },
    {
      name: 'bad paddding',
      type: 'item',
      input: ':aGVsbG8:',
      expected: parameterized_value('hello'.b, {}),
    },
    {
      name: 'non-zero pad bits',
      type: 'item',
      input: ':iZ==:',
      expected: parameterized_value("\x89".b, {}),
    },
    {
      name: 'non-ASCII binary',
      type: 'item',
      input: ':/+Ah:',
      expected: parameterized_value("\xFF\xE0!".b, {}),
    },
    {
      name: 'basic true boolean',
      type: 'item',
      input: '?1',
      expected: parameterized_value(true, {}),
    },
    {
      name: 'basic false boolean',
      type: 'item',
      input: '?0',
      expected: parameterized_value(false, {}),
    },
    {
      name: 'basic dictionary',
      type: 'dictionary',
      input: 'en="Applepie", da=:w4ZibGV0w6ZydGUK:',
      expected: {
        'en' => parameterized_value('Applepie', {}),
        'da' => parameterized_value("\xC3\x86blet\xC3\xA6rte\n".b, {}),
      },
    },
    {
      name: 'empty dictionary',
      type: 'dictionary',
      input: '',
      expected: {},
    },
    {
      name: 'single item dictionary',
      type: 'dictionary',
      input: 'a=1',
      expected: {
        'a' => parameterized_value(1, {}),
      },
    },
    {
      name: 'list item dictionary',
      type: 'dictionary',
      input: 'a=(1 2)',
      expected: {
        'a' => parameterized_value([parameterized_value(1, {}), parameterized_value(2, {})], {}),
      },
    },
    {
      name: 'single list item dictionary',
      type: 'dictionary',
      input: 'a=(1)',
      expected: {
        'a' => parameterized_value([parameterized_value(1, {})], {}),
      },
    },
    {
      name: 'empty list item dictionary',
      type: 'dictionary',
      input: 'a=()',
      expected: {
        'a' => parameterized_value([], {}),
      },
    },
    {
      name: 'no whitespace dictionary',
      type: 'dictionary',
      input: 'a=1,b=2',
      expected: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(2, {}),
      },
    },
    {
      name: 'extra whitespace dictionary',
      type: 'dictionary',
      input: 'a=1 ,  b=2',
      expected: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(2, {}),
      },
    },
    {
      name: 'tab separated dictionary',
      type: 'dictionary',
      input: "a=1\t,\tb=2",
      expected: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(2, {}),
      },
    },
    {
      name: 'leading whitespace dictionary',
      type: 'dictionary',
      input: '     a=1 ,  b=2',
      expected: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(2, {}),
      },
    },
    {
      name: 'missing value dictionary',
      type: 'dictionary',
      input: 'a=1, b, c=3',
      expected: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(true, {}),
        'c' => parameterized_value(3, {}),
      },
    },
    {
      name: 'all missing value dictionary',
      type: 'dictionary',
      input: 'a, b, c',
      expected: {
        'a' => parameterized_value(true, {}),
        'b' => parameterized_value(true, {}),
        'c' => parameterized_value(true, {}),
      },
    },
    {
      name: 'start missing value dictionary',
      type: 'dictionary',
      input: 'a, b=2',
      expected: {
        'a' => parameterized_value(true, {}),
        'b' => parameterized_value(2, {}),
      },
    },
    {
      name: 'end missing value dictionary',
      type: 'dictionary',
      input: 'a=1, b',
      expected: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(true, {}),
      },
    },
    {
      name: 'missing value with params dictionary',
      type: 'dictionary',
      input: 'a=1, b;foo=9, c=3',
      expected: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(true, { 'foo' => 9 }),
        'c' => parameterized_value(3, {}),
      },
    },
    {
      name: 'explicit true value with params dictionary',
      type: 'dictionary',
      input: 'a=1, b=?1;foo=9, c=3',
      expected: {
        'a' => parameterized_value(1, {}),
        'b' => parameterized_value(true, { 'foo' => 9 }),
        'c' => parameterized_value(3, {}),
      },
    },
    {
      name: 'duplicate key dictionary',
      type: 'dictionary',
      input: 'a=1,b=2,a=3',
      expected: {
        'a' => parameterized_value(3, {}),
        'b' => parameterized_value(2, {}),
      },
    },
    {
      name: 'leading and trailing space',
      type: 'item',
      input: '  1  ',
      expected: parameterized_value(1, {}),
    },
    {
      name: 'leading and trailing whitespace',
      type: 'item',
      input: '     1  ',
      expected: parameterized_value(1, {}),
    },
    {
      name: 'basic integer',
      type: 'item',
      input: '42',
      expected: parameterized_value(42, {}),
    },
    {
      name: 'zero integer',
      type: 'item',
      input: '0',
      expected: parameterized_value(0, {}),
    },
    {
      name: 'negative zero',
      type: 'item',
      input: '-0',
      expected: parameterized_value(0, {}),
    },
    {
      name: 'negative integer',
      type: 'item',
      input: '-42',
      expected: parameterized_value(-42, {}),
    },
    {
      name: 'leading 0 integer',
      type: 'item',
      input: '042',
      expected: parameterized_value(42, {}),
    },
    {
      name: 'leading 0 negative integer',
      type: 'item',
      input: '-042',
      expected: parameterized_value(-42, {}),
    },
    {
      name: 'leading 0 zero',
      type: 'item',
      input: '00',
      expected: parameterized_value(0, {}),
    },
    {
      name: 'long integer',
      type: 'item',
      input: '123456789012345',
      expected: parameterized_value(123456789012345, {}),
    },
    {
      name: 'long negative integer',
      type: 'item',
      input: '-123456789012345',
      expected: parameterized_value(-123456789012345, {}),
    },
    {
      name: 'simple decimal',
      type: 'item',
      input: '1.23',
      expected: parameterized_value(1.23, {}),
    },
    {
      name: 'negative decimal',
      type: 'item',
      input: '-1.23',
      expected: parameterized_value(-1.23, {}),
    },
    {
      name: 'tricky precision decimal',
      type: 'item',
      input: '123456789012.1',
      expected: parameterized_value(123456789012.1, {}),
    },
    {
      name: 'decimal with three fractional digits',
      type: 'item',
      input: '1.123',
      expected: parameterized_value(1.123, {}),
    },
    {
      name: 'negative decimal with three fractional digits',
      type: 'item',
      input: '-1.123',
      expected: parameterized_value(-1.123, {}),
    },
    {
      name: 'basic parameterised dict',
      type: 'dictionary',
      input: 'abc=123;a=1;b=2, def=456, ghi=789;q=9;r="+w"',
      expected: {
        'abc' => parameterized_value(123, { 'a' => 1, 'b' => 2 }),
        'def' => parameterized_value(456, {}),
        'ghi' => parameterized_value(789, { 'q' => 9, 'r' => '+w' }),
      },
    },
    {
      name: 'single item parameterised dict',
      type: 'dictionary',
      input: 'a=b; q=1.0',
      expected: {
        'a' => parameterized_value(:b, { 'q' => 1.0 }),
      },
    },
    {
      name: 'list item parameterised dictionary',
      type: 'dictionary',
      input: 'a=(1 2); q=1.0',
      expected: {
        'a' => parameterized_value([parameterized_value(1, {}), parameterized_value(2, {})], { 'q' => 1.0 }),
      },
    },
    {
      name: 'missing parameter value parameterised dict',
      type: 'dictionary',
      input: 'a=3;c;d=5',
      expected: {
        'a' => parameterized_value(3, { 'c' => true, 'd' => 5 }),
      },
    },
    {
      name: 'terminal missing parameter value parameterised dict',
      type: 'dictionary',
      input: 'a=3;c=5;d',
      expected: {
        'a' => parameterized_value(3, { 'c' => 5, 'd' => true }),
      },
    },
    {
      name: 'no whitespace parameterised dict',
      type: 'dictionary',
      input: 'a=b;c=1,d=e;f=2',
      expected: {
        'a' => parameterized_value(:b, { 'c' => 1 }),
        'd' => parameterized_value(:e, { 'f' => 2 }),
      },
    },
    {
      name: 'whitespace after ; parameterised dict',
      type: 'dictionary',
      input: 'a=b; q=0.5',
      expected: {
        'a' => parameterized_value(:b, { 'q' => 0.5 }),
      },
    },
    {
      name: 'extra whitespace parameterised dict',
      type: 'dictionary',
      input: 'a=b;  c=1  ,  d=e; f=2; g=3',
      expected: {
        'a' => parameterized_value(:b, { 'c' => 1 }),
        'd' => parameterized_value(:e, { 'f' => 2, 'g' => 3 }),
      },
    },
    {
      name: 'basic string',
      type: 'item',
      input: '"foo bar"',
      expected: parameterized_value('foo bar', {}),
    },
    {
      name: 'empty string',
      type: 'item',
      input: '""',
      expected: parameterized_value('', {}),
    },
    {
      name: 'long string',
      type: 'item',
      input: '"foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo "', # rubocop:disable Layout/LineLength
      expected: parameterized_value('foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo ', {}), # rubocop:disable Layout/LineLength
    },
    {
      name: 'whitespace string',
      type: 'item',
      input: '"   "',
      expected: parameterized_value('   ', {}),
    },
    {
      name: 'string quoting',
      type: 'item',
      input: '"foo \\"bar\\" \\\\ baz"',
      expected: parameterized_value('foo "bar" \\ baz', {}),
    },
    {
      name: 'basic token - item',
      type: 'item',
      input: 'a_b-c.d3:f%00/*',
      expected: parameterized_value(:'a_b-c.d3:f%00/*', {}),
    },
    {
      name: 'token with capitals - item',
      type: 'item',
      input: 'fooBar',
      expected: parameterized_value(:fooBar, {}),
    },
    {
      name: 'token starting with capitals - item',
      type: 'item',
      input: 'FooBar',
      expected: parameterized_value(:FooBar, {}),
    },
    {
      name: 'basic token - list',
      type: 'list',
      input: 'a_b-c3/*',
      expected: [parameterized_value(:'a_b-c3/*', {})],
    },
    {
      name: 'token with capitals - list',
      type: 'list',
      input: 'fooBar',
      expected: [parameterized_value(:fooBar, {})],
    },
    {
      name: 'token starting with capitals - list',
      type: 'list',
      input: 'FooBar',
      expected: [parameterized_value(:FooBar, {})],
    },
    {
      name: 'basic list',
      type: 'list',
      input: '1, 42',
      expected: [parameterized_value(1, {}), parameterized_value(42, {})],
    },
    {
      name: 'empty list',
      type: 'list',
      input: '',
      expected: [],
    },
    {
      name: 'leading SP list',
      type: 'list',
      input: '  42, 43',
      expected: [parameterized_value(42, {}), parameterized_value(43, {})],
    },
    {
      name: 'single item list',
      type: 'list',
      input: '42',
      expected: [parameterized_value(42, {})],
    },
    {
      name: 'no whitespace list',
      type: 'list',
      input: '1,42',
      expected: [parameterized_value(1, {}), parameterized_value(42, {})],
    },
    {
      name: 'extra whitespace list',
      type: 'list',
      input: '1 , 42',
      expected: [parameterized_value(1, {}), parameterized_value(42, {})],
    },
    {
      name: 'tab separated list',
      type: 'list',
      input: "1\t,\t42",
      expected: [parameterized_value(1, {}), parameterized_value(42, {})],
    },
    {
      name: 'basic list of lists',
      type: 'list',
      input: '(1 2), (42 43)',
      expected: [
        parameterized_value([parameterized_value(1, {}), parameterized_value(2, {})], {}),
        parameterized_value([parameterized_value(42, {}), parameterized_value(43, {})], {}),
      ],
    },
    {
      name: 'single item list of lists',
      type: 'list',
      input: '(42)',
      expected: [parameterized_value([parameterized_value(42, {})], {})],
    },
    {
      name: 'empty item list of lists',
      type: 'list',
      input: '()',
      expected: [parameterized_value([], {})],
    },
    {
      name: 'empty middle item list of lists',
      type: 'list',
      input: '(1),(),(42)',
      expected: [
        parameterized_value([parameterized_value(1, {})], {}),
        parameterized_value([], {}),
        parameterized_value([parameterized_value(42, {})], {}),
      ],
    },
    {
      name: 'extra whitespace list of lists',
      type: 'list',
      input: '(  1  42  )',
      expected: [parameterized_value([parameterized_value(1, {}), parameterized_value(42, {})], {})],
    },
    {
      name: 'basic parameterised list',
      type: 'list',
      input: 'abc_123;a=1;b=2; cdef_456, ghi;q=9;r="+w"',
      expected: [
        parameterized_value(:abc_123, { 'a' => 1, 'b' => 2, 'cdef_456' => true }),
        parameterized_value(:ghi, { 'q' => 9, 'r' => '+w' }),
      ],
    },
    {
      name: 'single item parameterised list',
      type: 'list',
      input: 'text/html;q=1.0',
      expected: [parameterized_value(:'text/html', { 'q' => 1.0 })],
    },
    {
      name: 'missing parameter value parameterised list',
      type: 'list',
      input: 'text/html;a;q=1.0',
      expected: [parameterized_value(:'text/html', { 'a' => true, 'q' => 1.0 })],
    },
    {
      name: 'missing terminal parameter value parameterised list',
      type: 'list',
      input: 'text/html;q=1.0;a',
      expected: [parameterized_value(:'text/html', { 'q' => 1.0, 'a' => true })],
    },
    {
      name: 'no whitespace parameterised list',
      type: 'list',
      input: 'text/html,text/plain;q=0.5',
      expected: [
        parameterized_value(:'text/html', {}),
        parameterized_value(:'text/plain', { 'q' => 0.5 }),
      ],
    },
    {
      name: 'whitespace after ; parameterised list',
      type: 'list',
      input: 'text/html, text/plain; q=0.5',
      expected: [
        parameterized_value(:'text/html', {}),
        parameterized_value(:'text/plain', { 'q' => 0.5 }),
      ],
    },
    {
      name: 'extra whitespace parameterised list',
      type: 'list',
      input: 'text/html  ,  text/plain;  q=0.5;  charset=utf-8',
      expected: [
        parameterized_value(:'text/html', {}),
        parameterized_value(:'text/plain', { 'q' => 0.5, 'charset' => :'utf-8' }),
      ],
    },
    {
      name: 'parameterised inner list',
      type: 'list',
      input: '(abc_123);a=1;b=2, cdef_456',
      expected: [
        parameterized_value([parameterized_value(:abc_123, {})], { 'a' => 1, 'b' => 2 }),
        parameterized_value(:cdef_456, {}),
      ],
    },
    {
      name: 'parameterised inner list item',
      type: 'list',
      input: '(abc_123;a=1;b=2;cdef_456)',
      expected: [parameterized_value([parameterized_value(:abc_123, { 'a' => 1, 'b' => 2, 'cdef_456' => true })], {})],
    },
    {
      name: 'parameterised inner list with parameterised item',
      type: 'list',
      input: '(abc_123;a=1;b=2);cdef_456',
      expected: [parameterized_value([parameterized_value(:abc_123, { 'a' => 1, 'b' => 2 })], { 'cdef_456' => true })],
    },
  ]

  valid_tests.each do |test|
    it "parses #{test[:name]} in parse_as_#{test[:type]}" do
      expect(described_class.send(:"parse_as_#{test[:type]}", test[:input])).to eq(test[:expected])
    end
  end

  invalid_tests = [
    {
      name: 'bad end delimiter',
      type: 'item',
      input: ':aGVsbG8=',
    },
    {
      name: 'extra whitespace',
      type: 'item',
      input: ':aGVsb G8=:',
    },
    {
      name: 'extra chars',
      type: 'item',
      input: ':aGVsbG!8=:',
    },
    {
      name: 'suffix chars',
      type: 'item',
      input: ':aGVsbG8=!:',
    },
    {
      name: 'base64url binary',
      type: 'item',
      input: ':_-Ah:',
    },
    {
      name: 'unknown boolean',
      type: 'item',
      input: '?Q',
    },
    {
      name: 'whitespace boolean',
      type: 'item',
      input: '? 1',
    },
    {
      name: 'negative zero boolean',
      type: 'item',
      input: '?-0',
    },
    {
      name: 'T boolean',
      type: 'item',
      input: '?T',
    },
    {
      name: 'F boolean',
      type: 'item',
      input: '?F',
    },
    {
      name: 't boolean',
      type: 'item',
      input: '?t',
    },
    {
      name: 'f boolean',
      type: 'item',
      input: '?f',
    },
    {
      name: 'spelled-out True boolean',
      type: 'item',
      input: '?True',
    },
    {
      name: 'spelled-out False boolean',
      type: 'item',
      input: '?False',
    },
    {
      name: 'whitespace before = dictionary',
      type: 'dictionary',
      input: 'a =1, b=2',
    },
    {
      name: 'whitespace after = dictionary',
      type: 'dictionary',
      input: 'a=1, b= 2',
    },
    {
      name: 'trailing comma dictionary',
      type: 'dictionary',
      input: 'a=1, b=2,',
    },
    {
      name: 'empty item dictionary',
      type: 'dictionary',
      input: 'a=1,,b=2,',
    },
    {
      name: 'numeric key dictionary',
      type: 'dictionary',
      input: 'a=1,1b=2,a=1',
    },
    {
      name: 'uppercase key dictionary',
      type: 'dictionary',
      input: 'a=1,B=2,a=1',
    },
    {
      name: 'bad key dictionary',
      type: 'dictionary',
      input: 'a=1,b!=2,a=1',
    },
    {
      name: 'empty item',
      type: 'item',
      input: '',
    },
    {
      name: 'leading space',
      type: 'item',
      input: ' 	 1',
    },
    {
      name: 'trailing space',
      type: 'item',
      input: '1 	 ',
    },
    {
      name: 'double negative zero',
      type: 'item',
      input: '--0',
    },
    {
      name: 'comma',
      type: 'item',
      input: '2,3',
    },
    {
      name: 'negative non-DIGIT first character',
      type: 'item',
      input: '-a23',
    },
    {
      name: 'sign out of place',
      type: 'item',
      input: '4-2',
    },
    {
      name: 'whitespace after sign',
      type: 'item',
      input: '- 42',
    },
    {
      name: 'too long integer',
      type: 'item',
      input: '1234567890123456',
    },
    {
      name: 'negative too long integer',
      type: 'item',
      input: '-1234567890123456',
    },
    {
      name: 'decimal, whitespace after decimal',
      type: 'item',
      input: '1. 23',
    },
    {
      name: 'decimal, whitespace before decimal',
      type: 'item',
      input: '1 .23',
    },
    {
      name: 'negative decimal, whitespace after sign',
      type: 'item',
      input: '- 1.23',
    },
    {
      name: 'double decimal decimal',
      type: 'item',
      input: '1.5.4',
    },
    {
      name: 'adjacent double decimal decimal',
      type: 'item',
      input: '1..4',
    },
    {
      name: 'decimal with four fractional digits',
      type: 'item',
      input: '1.1234',
    },
    {
      name: 'negative decimal with four fractional digits',
      type: 'item',
      input: '-1.1234',
    },
    {
      name: 'decimal with thirteen integer digits',
      type: 'item',
      input: '1234567890123.0',
    },
    {
      name: 'negative decimal with thirteen integer digits',
      type: 'item',
      input: '-1234567890123.0',
    },
    {
      name: 'whitespace before = parameterised dict',
      type: 'dictionary',
      input: 'a=b;q =0.5',
    },
    {
      name: 'whitespace after = parameterised dict',
      type: 'dictionary',
      input: 'a=b;q= 0.5',
    },
    {
      name: 'whitespace before ; parameterised dict',
      type: 'dictionary',
      input: 'a=b ;q=0.5',
    },
    {
      name: 'trailing comma parameterised list',
      type: 'dictionary',
      input: 'a=b; q=1.0,',
    },
    {
      name: 'empty item parameterised list',
      type: 'dictionary',
      input: 'a=b; q=1.0,,c=d',
    },
    {
      name: 'non-ascii string',
      type: 'item',
      input: '"füü"',
    },
    {
      name: 'tab in string',
      type: 'item',
      input: "\"\t\"",
    },
    {
      name: 'newline in string',
      type: 'item',
      input: "\" \n \"",
    },
    {
      name: 'single quoted string',
      type: 'item',
      input: '\'foo\'',
    },
    {
      name: 'unbalanced string',
      type: 'item',
      input: '"foo',
    },
    {
      name: 'bad string quoting',
      type: 'item',
      input: '"foo \,"',
    },
    {
      name: 'ending string quote',
      type: 'item',
      input: '"foo \"',
    },
    {
      name: 'abruptly ending string quote',
      type: 'item',
      input: '"foo \\',
    },
    {
      name: 'trailing comma list',
      type: 'list',
      input: '1, 42,',
    },
    {
      name: 'empty item list',
      type: 'list',
      input: '1,,42',
    },
    {
      name: 'wrong whitespace list of lists',
      type: 'list',
      input: '(1	 42)',
    },
    {
      name: 'no trailing parenthesis list of lists',
      type: 'list',
      input: '(1 42',
    },
    {
      name: 'no trailing parenthesis middle list of lists',
      type: 'list',
      input: '(1 2, (42 43)',
    },
    {
      name: 'no spaces in inner-list',
      type: 'list',
      input: '(abc"def"?0123*dXZ3*xyz)',
    },
    {
      name: 'no closing parenthesis',
      type: 'list',
      input: '(',
    },
    {
      name: 'whitespace before = parameterised list',
      type: 'list',
      input: 'text/html, text/plain;q =0.5',
    },
    {
      name: 'whitespace after = parameterised list',
      type: 'list',
      input: 'text/html, text/plain;q= 0.5',
    },
    {
      name: 'whitespace before ; parameterised list',
      type: 'list',
      input: 'text/html, text/plain ;q=0.5',
    },
    {
      name: 'trailing comma parameterised list',
      type: 'list',
      input: 'text/html,text/plain;q=0.5,',
    },
    {
      name: 'empty item parameterised list',
      type: 'list',
      input: 'text/html,,text/plain;q=0.5,',
    },
  ]

  invalid_tests.each do |test|
    it "fails to parse #{test[:name]} in parse_as_#{test[:type]}" do
      expect do
        described_class.send(:"parse_as_#{test[:type]}", test[:input])
      end.to raise_error(described_class::ParseError)
    end
  end
end

# rubocop:enable Naming/VariableNumber
