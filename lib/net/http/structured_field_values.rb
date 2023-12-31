# frozen_string_literal: true

require 'net/http'

require 'net/http/structured_field_values/parameterized_value'
require 'net/http/structured_field_values/parser'
require 'net/http/structured_field_values/serializer'
require 'net/http/structured_field_values/version'

module Net
  class HTTP
    # A Ruby implementation of RFC 8941 - Structured Field Values for HTTP.
    #
    # @see https://datatracker.ietf.org/doc/html/rfc8941
    module StructuredFieldValues
    end
  end
end
