# frozen_string_literal: true

require 'base64'
require 'net/http'
require 'strscan'

require 'net/http/structured_field_values/parameterized_value'

# Disable some cops which is not compatible with StringScanner.
# rubocop:disable Lint/MissingCopEnableDirective
# rubocop:disable Performance/StringInclude
# rubocop:disable Style/CaseLikeIf
# rubocop:enable Lint/MissingCopEnableDirective

module Net
  class HTTP
    module StructuredFieldValues
      # RFC8941 compliant parser which parses HTTP fields into Ruby objects.
      #
      # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2}
      class Parser
        TOP_LEVEL_TYPES = %w[list dictionary item].freeze
        private_constant :TOP_LEVEL_TYPES

        # @param [String] input input bytes to be parsed
        def initialize(input)
          @scanner = StringScanner.new(input.encode(Encoding::ASCII))
          remove_leading_spaces
        rescue Encoding::UndefinedConversionError
          raise ParseError, 'Unexpected input'
        end

        # @param [String] type type of the field to be parsed,
        #                      must be one of 'list', 'dictionary' or 'item'
        def parse_as(type)
          raise ArgumentError, "Invalid type: #{type}" unless TOP_LEVEL_TYPES.include?(type)

          send(:"parse_as_#{type}").tap do
            remove_leading_spaces
            raise ParseError, 'Unexpected input' unless scanner.eos?
          end
        end

        TOP_LEVEL_TYPES.each do |type|
          define_singleton_method(:"parse_as_#{type}") do |input|
            new(input).parse_as(type)
          end
        end

        private

        attr_reader :scanner

        def remove_leading_spaces
          scanner.skip(/ +/)
        end

        def remove_leading_whitespaces
          scanner.skip(/[ \t]+/)
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.1}
        # @return [Array<ParameterizedValue>]
        def parse_as_list
          return [] if scanner.eos?

          [].tap do |result|
            loop do
              result << parse_as_item_or_inner_list
              remove_leading_whitespaces
              break if scanner.eos?

              raise ParseError, 'Expected ","' unless scanner.skip(/,/)

              remove_leading_whitespaces
              raise ParseError, 'Expected next item' if scanner.eos?
            end
          end
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.1.1}
        # @return [ParameterizedValue]
        def parse_as_item_or_inner_list
          if scanner.match?(/\(/)
            parse_as_inner_list
          else
            parse_as_item
          end
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.1.2}
        # @return [ParameterizedValue<Array>]
        def parse_as_inner_list
          raise ParseError, 'Expected "("' unless scanner.skip(/\(/)

          ParameterizedValue.new(
            [].tap do |result|
              loop do
                remove_leading_spaces
                break if scanner.skip(/\)/)

                result << parse_as_item
                raise ParseError, 'Expected space or ")"' unless scanner.match?(/[ )]/)
              end
            end,
            parse_as_parameters,
          )
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.2}
        # @return [Hash]
        def parse_as_dictionary
          return {} if scanner.eos?

          {}.tap do |result|
            loop do
              result[parse_as_key] = if scanner.skip(/=/)
                                       parse_as_item_or_inner_list
                                     else
                                       ParameterizedValue.new(true, parse_as_parameters)
                                     end
              remove_leading_whitespaces
              break if scanner.eos?

              raise ParseError, 'Expected ","' unless scanner.skip(/,/)

              remove_leading_whitespaces
              raise ParseError, 'Expected next hash key' if scanner.eos?
            end
          end
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.3}
        # @return [ParameterizedValue<Integer,Float,String,Boolean>]
        def parse_as_item
          ParameterizedValue.new(parse_as_bare_item, parse_as_parameters)
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.3.1}
        # @return [Integer,Float,String,Symbol,Boolean]
        def parse_as_bare_item
          raise ParseError, 'Unexpected input' if scanner.eos?

          if scanner.match?(/[-\d]/)
            parse_as_integer_or_decimal
          elsif scanner.match?(/"/)
            parse_as_string
          elsif scanner.match?(/[a-zA-Z*]/)
            parse_as_token
          elsif scanner.match?(/:/)
            parse_as_byte_sequence
          elsif scanner.match?(/\?/)
            parse_as_boolean
          else
            raise ParseError, 'Unexpected input'
          end
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.3.2}
        # @return [Hash]
        def parse_as_parameters
          {}.tap do |result|
            while scanner.skip(/;/)
              remove_leading_spaces
              result[parse_as_key] = if scanner.skip(/=/)
                                       parse_as_bare_item
                                     else
                                       true
                                     end
            end
          end
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.3.3}
        # @return [String]
        def parse_as_key
          raise ParseError, 'Unexpected input' unless scanner.match?(/[a-z*]/)

          scanner.scan(/[a-z\d_\-.*]+/)
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.4}
        # @return [Integer,Float]
        def parse_as_integer_or_decimal
          sign = scanner.skip(/-/) ? -1 : 1
          raise ParseError, 'Unexpected input' unless scanner.match?(/\d/)

          str = scanner.scan(/\d+/)
          num = if scanner.skip(/\./)
                  raise ParseError, 'Integer part of decimal number is too long' if str.length > 12
                  raise ParseError, 'Unexpected input' unless scanner.match?(/\d/)

                  frac = scanner.scan(/\d+/)
                  raise ParseError, 'Fractional part of decimal number is too long' if frac.length > 3

                  "#{str}.#{frac}".to_f
                else
                  raise ParseError, 'Integer number is too long' if str.length > 15

                  str.to_i
                end

          num * sign
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.5}
        # @return [String]
        def parse_as_string
          raise ParseError, 'Unexpected input' unless scanner.skip(/"/)

          (+'').tap do |result|
            loop do
              if scanner.eos?
                raise ParseError, 'Unexpected input'
              elsif scanner.skip(/"/)
                break
              elsif scanner.skip(/\\/)
                byte = scanner.scan(/["\\]/)
                raise ParseError, 'Unexpected input' unless byte

                result << byte
              elsif scanner.match?(/[ -~]/)
                result << scanner.scan(/[ !#-\[\]-~]+/)
              else
                raise ParseError, 'Expected space or visible ASCII character'
              end
            end
          end
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.6}
        # @return [Symbol]
        def parse_as_token
          raise ParseError, 'Unexpected input' unless scanner.match?(/[a-zA-Z*]/)

          scanner.scan(/[!#-'*+\--:A-Z^-z|~]+/).to_sym
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.7}
        # @return [String]
        def parse_as_byte_sequence
          raise ParseError, 'Unexpected input' unless scanner.skip(/:/)

          str = scanner.scan(%r{[a-zA-Z\d+/=]+})
          raise ParseError, 'Unexpected input' unless scanner.skip(/:/)

          Base64.decode64(str || '')
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.2.8}
        # @return [Boolean]
        def parse_as_boolean
          raise ParseError, 'Unexpected input' unless scanner.skip(/\?/)

          case scanner.get_byte
          when '0'
            false
          when '1'
            true
          else
            raise ParseError, 'Unexpected input'
          end
        end

        class ParseError < StandardError; end
      end
    end
  end
end
