# frozen_string_literal: true

require 'net/http'

module Net
  class HTTP
    module StructuredFieldValues
      # RFC8941 compliant serializer which serializes Ruby objects into HTTP fields.
      #
      # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1}
      class Serializer
        def initialize
          @result = +''
        end

        # @return [String]
        def serialize(obj)
          case obj
          when Array
            serialize_list(obj)
          when Hash
            serialize_dictionary(obj)
          else
            value, params = unpack_parameterized_value(obj)
            serialize_item(value, params)
          end

          result.encode(Encoding::ASCII)
        end

        # Serializes given object.
        #
        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1}
        #
        # @param [Array, Hash, ParameterizedValue, Integer, Float, String, Symbol, Boolean] obj object to be serialized
        # @return [String]
        def self.serialize(obj)
          new.serialize(obj)
        end

        # Serializes input as Inner List.
        #
        # @note Use of this method breaks RFC8941.
        #
        # @param [Array, ParameterizedValue] input object to be serialized
        # @return [String] serialized output
        def serialize_as_inner_list(input)
          arr, params = unpack_parameterized_value(input)
          serialize_inner_list(arr, params)
          result.encode(Encoding::ASCII)
        end

        # Serializes input as Inner List.
        #
        # @note Use of this method breaks RFC8941.
        #
        # @param [Array, ParameterizedValue] input object to be serialized
        # @return [String] serialized output
        def self.serialize_as_inner_list(input)
          new.serialize_as_inner_list(input)
        end

        private

        attr_reader :result

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.1}
        #
        # @param [Array] arr
        def serialize_list(arr)
          return if arr.empty?

          loop do
            value, params = unpack_parameterized_value(arr.shift)
            case value
            when Array
              serialize_inner_list(value, params)
            else
              serialize_item(value, params)
            end

            break if arr.empty?

            result << ', '
          end
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.1.1}
        #
        # @param [Array] arr
        # @param [Hash] params
        def serialize_inner_list(arr, params)
          result << '('

          unless arr.empty?
            loop do
              serialize_item(*unpack_parameterized_value(arr.shift))

              break if arr.empty?

              result << ' '
            end
          end

          result << ')'

          serialize_parameters(params)
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.1.2}
        #
        # @param [Hash] params
        def serialize_parameters(params)
          params.each do |key, value|
            result << ';'

            serialize_key(key)
            next if value == true

            result << '='
            serialize_bare_item(value)
          end
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.1.3}
        #
        # @param [String] key
        def serialize_key(key)
          key = key.encode(Encoding::ASCII)
          raise SerializationError, 'Invalid key' unless key.match?(/\A[a-z*][a-z\d_\-*]*\z/)

          result << key
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.2}
        #
        # @param [Hash] dict
        def serialize_dictionary(dict)
          return if dict.empty?

          loop do
            key, obj = dict.shift
            serialize_key(key)

            value, params = unpack_parameterized_value(obj)
            if value == true
              serialize_parameters(params)
            else
              result << '='
              case value
              when Array
                serialize_inner_list(value, params)
              else
                serialize_item(value, params)
              end
            end

            break if dict.empty?

            result << ', '
          end
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.3}
        #
        # @param [Object] item
        # @param [Hash] params
        def serialize_item(item, params)
          serialize_bare_item(item)
          serialize_parameters(params)
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.3.1}
        def serialize_bare_item(item)
          case item
          when Integer
            serialize_integer(item)
          when Float
            serialize_decimal(item)
          when String
            case item.encoding
            when Encoding::BINARY
              serialize_byte_sequence(item)
            else
              serialize_string(item)
            end
          when Symbol
            serialize_token(item)
          when TrueClass, FalseClass
            serialize_boolean(item)
          else
            raise SerializationError, "Unexpected item: #{item.inspect}"
          end
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.4}
        #
        # @param [Integer] int
        def serialize_integer(int)
          unless (-999_999_999_999_999..999_999_999_999_999).cover?(int)
            raise SerializationError, 'integers must be in the range of -999,999,999,999,999 to 999,999,999,999,999'
          end

          result << int.to_s
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.5}
        #
        # @param [Float] decimal
        def serialize_decimal(decimal)
          decimal = decimal.round(3, half: :even)
          str = decimal.to_s
          i = str.index('.')

          raise SerializationError, 'integer part of decimals must be less than 13 chars' if i.nil? || i > 12

          result << str
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.6}
        #
        # @param [String] str
        def serialize_string(str)
          result << '"'

          s = StringScanner.new(str.encode(Encoding::ASCII))
          loop do
            if (part = s.scan(/[ !#-\[\]-~]+/))
              result << part
            end

            break if s.eos?

            raise SerializationError, 'Invalid string' unless (byte = s.scan(/["\\]/))

            result << '\\'
            result << byte
          end

          result << '"'
        rescue EncodingError
          raise SerializationError, 'Invalid string'
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.7}
        #
        # @param [Symbol] token
        def serialize_token(token)
          str = token.to_s

          raise SerializationError, 'Invalid token' unless str.match?(/\A[a-zA-Z*][!#-'*+\--:A-Z^-z|~]*\z/)

          result << str
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.8}
        #
        # @param [String] bytes
        def serialize_byte_sequence(bytes)
          result << ':'
          result << Base64.strict_encode64(bytes)
          result << ':'
        end

        # @see {https://www.rfc-editor.org/rfc/rfc8941#section-4.1.9}
        #
        # @param [Boolean] bool
        def serialize_boolean(bool)
          result << '?'
          result << (bool ? '1' : '0')
        end

        def unpack_parameterized_value(obj)
          case obj
          when ParameterizedValue
            [obj.value, obj.parameters]
          else
            [obj, {}]
          end
        end

        class SerializationError < StandardError; end
      end
    end
  end
end
